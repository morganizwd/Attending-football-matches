import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:attending_football_matches/core/constants.dart';
import 'package:attending_football_matches/models/attendance.dart';
import 'package:attending_football_matches/models/intent.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/match_source.dart';
import 'package:attending_football_matches/models/stadium.dart';
import 'package:attending_football_matches/services/location_service.dart';
import 'package:attending_football_matches/services/football_api/api_football_client.dart';
import 'package:attending_football_matches/services/football_api/football_api_config.dart';
import 'package:attending_football_matches/services/football_api/football_data_org_client.dart';
import 'package:attending_football_matches/services/api_matches_cache_store.dart';
import 'package:attending_football_matches/services/venue_geocode_service.dart';

enum MatchSort {
  startTimeAsc,
  startTimeDesc,
}

class AttendanceService extends ChangeNotifier {
  AttendanceService({FootballApiConfig? footballApiConfig})
      : _footballConfig = footballApiConfig ?? FootballApiConfig.fromEnvironment();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FootballApiConfig _footballConfig;
  final Map<String, Future<List<MatchModel>>> _externalInFlight = {};
  final Map<String, List<MatchModel>> _externalCache = {};
  final Map<String, DateTime> _externalCacheAt = {};
  static const Duration _externalCacheTtl = Duration(minutes: 5);

  /// Срок жизни записи на диске ([ApiMatchesCacheStore.diskTtl]).
  static Duration get _diskCacheMaxAge => ApiMatchesCacheStore.diskTtl;
  static const int _maxVenueResolvePerPage = 6;

  /// Настройки внешних API (ключи, лиги) — для UI.
  FootballApiConfig get footballApiConfig => _footballConfig;

  /// Ключ дедупликации: одна и та же игра из разных источников не дублируется.
  static bool _isRussiaLeague(MatchModel m) {
    if (m.apiFootballLeagueId == apiFootballRussianPremierLeagueId) return true;
    if (m.footballDataCompetitionCode == 'RFPL') return true;
    final l = m.league?.toLowerCase() ?? '';
    if (l == 'rfpl') return true;
    if (l.contains('российск') || l.contains('рпл')) return true;
    return false;
  }

  static String _dedupeKey(MatchModel m) {
    final t = m.startTime.millisecondsSinceEpoch ~/ 60000;
    return '${m.homeTeam.toLowerCase()}|${m.awayTeam.toLowerCase()}|$t';
  }

  /// Ключ кэша (память + диск). Только календарные даты — иначе при каждом запуске
  /// меняется `DateTime.now()` в UI и ключ не совпадает с сохранённым.
  static String _externalCacheKey(DateTime? from, DateTime? to, int hardLimit, bool onlyRussia) {
    String dayKey(DateTime? d) {
      if (d == null) return '-';
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    return '${dayKey(from)}|${dayKey(to)}|$hardLimit|r$onlyRussia';
  }

  Future<List<MatchModel>> _fetchExternalMatches({
    DateTime? from,
    DateTime? to,
    int hardLimit = 300,
    bool onlyRussia = false,
  }) async {
    final cacheKey = _externalCacheKey(from, to, hardLimit, onlyRussia);
    final now = DateTime.now();
    final cached = _externalCache[cacheKey];
    final cachedAt = _externalCacheAt[cacheKey];
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) <= _externalCacheTtl) {
      return List<MatchModel>.from(cached);
    }

    final fromDisk = await ApiMatchesCacheStore.readFresh(
      cacheKey: cacheKey,
      maxAge: _diskCacheMaxAge,
    );
    if (fromDisk != null && fromDisk.isNotEmpty) {
      debugPrint('AttendanceService: кэш матчей API с диска ($cacheKey, ${fromDisk.length} шт.)');
      _externalCache[cacheKey] = fromDisk;
      _externalCacheAt[cacheKey] = DateTime.now();
      return List<MatchModel>.from(fromDisk);
    }

    final inFlight = _externalInFlight[cacheKey];
    if (inFlight != null) {
      return await inFlight;
    }

    final future = _fetchExternalMatchesNetwork(from: from, to: to, hardLimit: hardLimit, onlyRussia: onlyRussia);
    _externalInFlight[cacheKey] = future;
    try {
      final merged = await future;
      _externalCache[cacheKey] = merged;
      _externalCacheAt[cacheKey] = DateTime.now();
      await ApiMatchesCacheStore.write(cacheKey: cacheKey, matches: merged);
      return merged;
    } catch (e, st) {
      debugPrint('AttendanceService: external fetch failed $e\n$st');
      if (_externalCache[cacheKey] != null) {
        return List<MatchModel>.from(_externalCache[cacheKey]!);
      }
      rethrow;
    } finally {
      _externalInFlight.remove(cacheKey);
    }
  }

  Future<List<MatchModel>> _fetchExternalMatchesNetwork({
    DateTime? from,
    DateTime? to,
    int hardLimit = 300,
    bool onlyRussia = false,
  }) async {
    final merged = <MatchModel>[];
    final seen = <String>{};

    void addList(List<MatchModel> list) {
      for (final m in list) {
        if (seen.add(_dedupeKey(m))) {
          merged.add(m);
        }
      }
    }

    if (_footballConfig.apiFootballKey.isNotEmpty) {
      try {
        final apiConfig = onlyRussia
            ? _footballConfig.withApiFootballLeagueIds([apiFootballRussianPremierLeagueId])
            : _footballConfig;
        final list = await ApiFootballClient(apiConfig).fetchFixtures(from: from, to: to);
        addList(list);
      } catch (e, st) {
        debugPrint('ApiFootballClient: $e\n$st');
      }
    }

    // football-data.org не отдаёт CORS для localhost с портом в браузере — только не-web.
    if (_footballConfig.footballDataToken.isNotEmpty && !kIsWeb) {
      try {
        var list = await FootballDataOrgClient(_footballConfig).fetchMatches(from: from, to: to);
        if (onlyRussia) {
          list = list.where(_isRussiaLeague).toList();
        }
        addList(list);
      } catch (e, st) {
        debugPrint('FootballDataOrgClient: $e\n$st');
      }
    } else if (_footballConfig.footballDataToken.isNotEmpty && kIsWeb) {
      debugPrint(
        'FootballDataOrgClient: на Flutter Web запросы к football-data.org блокируются CORS. '
        'Используйте Windows/Android или только API-Football.',
      );
    }

    merged.sort((a, b) => a.startTime.compareTo(b.startTime));
    if (merged.length > hardLimit) {
      merged.removeRange(hardLimit, merged.length);
    }
    return merged;
  }

  Future<List<MatchModel>> getUpcomingMatches() async {
    final all = await getMatches();
    final now = DateTime.now();
    return all.where((m) {
      if (!m.isActive) return false;
      final end = m.startTime.add(const Duration(minutes: minutesAfterMatchStart));
      final ongoing = !now.isBefore(m.startTime) && !now.isAfter(end);
      return m.startTime.isAfter(now) || ongoing;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<List<MatchModel>> getMatches({
    String? query,
    String? league,
    MatchSource? source,
    MatchSort sort = MatchSort.startTimeAsc,
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
    bool onlyRussia = false,
  }) async {
    final validPage = page < 1 ? 1 : page;
    final validPageSize = pageSize < 1 ? 20 : pageSize;

    Query<Map<String, dynamic>> q = _firestore
        .collection(FirestoreCollections.matches)
        .where('isActive', isEqualTo: true)
        .orderBy('startTime');
    final snap = await q.get();
    final result = <MatchModel>[];
    for (final doc in snap.docs) {
      final stadiumId = doc.get('stadiumId') as String? ?? '';
      Stadium? stadium;
      if (stadiumId.isNotEmpty) {
        final stadiumDoc = await _firestore.collection(FirestoreCollections.stadiums).doc(stadiumId).get();
        if (stadiumDoc.exists) stadium = Stadium.fromFirestore(stadiumDoc);
      }
      result.add(MatchModel.fromFirestore(doc, stadium: stadium));
    }

    List<MatchModel> external = [];
    try {
      final pool = validPage * validPageSize * 2;
      external = await _fetchExternalMatches(
        from: from,
        to: to,
        hardLimit: onlyRussia ? pool.clamp(300, 4000) : pool,
        onlyRussia: onlyRussia,
      );
    } catch (e, st) {
      debugPrint('External matches: $e\n$st');
    }

    // Сначала локальные матчи, затем API — дубликаты по командам+времени отбрасываем.
    final seen = <String>{};
    final merged = <MatchModel>[];
    for (final m in result) {
      if (seen.add(_dedupeKey(m))) merged.add(m);
    }
    for (final m in external) {
      if (seen.add(_dedupeKey(m))) merged.add(m);
    }
    merged.sort((a, b) => a.startTime.compareTo(b.startTime));

    var filtered = List<MatchModel>.from(merged);
    if (query != null && query.isNotEmpty) {
      final lower = query.toLowerCase();
      filtered = filtered
          .where((m) =>
              m.homeTeam.toLowerCase().contains(lower) ||
              m.awayTeam.toLowerCase().contains(lower) ||
              (m.league?.toLowerCase().contains(lower) ?? false))
          .toList();
    }
    if (league != null && league.isNotEmpty) {
      filtered = filtered.where((m) => m.league == league).toList();
    }
    if (source != null) {
      filtered = filtered.where((m) => m.source == source).toList();
    }
    if (onlyRussia) {
      filtered = filtered.where(_isRussiaLeague).toList();
    }
    filtered.sort((a, b) => sort == MatchSort.startTimeAsc
        ? a.startTime.compareTo(b.startTime)
        : b.startTime.compareTo(a.startTime));

    final start = (validPage - 1) * validPageSize;
    if (start >= filtered.length) return [];
    final end = (start + validPageSize).clamp(0, filtered.length).toInt();
    final pageSlice = filtered.sublist(start, end);
    return _enrichVenueForPage(pageSlice, maxResolve: _maxVenueResolvePerPage);
  }

  Future<List<MatchModel>> _enrichVenueForPage(List<MatchModel> page, {int maxResolve = 6}) async {
    var resolveBudget = maxResolve;
    final futures = <Future<MatchModel>>[];
    for (final match in page) {
      if (match.source == MatchSource.firestore || match.effectiveStadium != null) {
        futures.add(Future.value(match.copyWith(venueResolveStatus: VenueResolveStatus.resolved)));
        continue;
      }
      if (resolveBudget <= 0) {
        futures.add(Future.value(match.copyWith(venueResolveStatus: VenueResolveStatus.unknown)));
        continue;
      }
      resolveBudget--;
      futures.add(_resolveOneVenueForPage(match));
    }
    return Future.wait(futures);
  }

  Future<MatchModel> _resolveOneVenueForPage(MatchModel match) async {
    try {
      final resolved = await VenueGeocodeService.resolveForMatch(match);
      if (resolved.stadium != null) {
        return match.copyWith(
          stadium: resolved.stadium,
          venueLat: resolved.stadium!.latitude,
          venueLng: resolved.stadium!.longitude,
          venueImageUrl: resolved.imageUrl,
          venueResolveStatus: VenueResolveStatus.resolved,
        );
      }
      return match.copyWith(
        venueImageUrl: resolved.imageUrl,
        venueResolveStatus: resolved.status,
      );
    } catch (_) {
      return match.copyWith(venueResolveStatus: VenueResolveStatus.geocodeFailed);
    }
  }

  /// Фоновое обогащение одного матча (для lazy-догрузки в UI).
  Future<MatchModel> enrichVenueForMatch(MatchModel match) async {
    if (match.source == MatchSource.firestore || match.effectiveStadium != null) {
      return match.copyWith(venueResolveStatus: VenueResolveStatus.resolved);
    }
    try {
      final resolved = await VenueGeocodeService.resolveForMatch(match);
      if (resolved.stadium != null) {
        return match.copyWith(
          stadium: resolved.stadium,
          venueLat: resolved.stadium!.latitude,
          venueLng: resolved.stadium!.longitude,
          venueImageUrl: resolved.imageUrl,
          venueResolveStatus: VenueResolveStatus.resolved,
        );
      }
      return match.copyWith(
        venueImageUrl: resolved.imageUrl,
        venueResolveStatus: resolved.status,
      );
    } catch (_) {
      return match.copyWith(venueResolveStatus: VenueResolveStatus.geocodeFailed);
    }
  }

  Future<void> addIntent(String userId, String matchId, {bool reminderEnabled = true}) async {
    final existing = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .get();
    if (existing.docs.isNotEmpty) return;
    await _firestore.collection(FirestoreCollections.intents).add({
      'userId': userId,
      'matchId': matchId,
      'createdAt': Timestamp.now(),
      'reminderEnabled': reminderEnabled,
    });
    notifyListeners();
  }

  Future<void> removeIntent(String userId, String matchId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    notifyListeners();
  }

  Future<bool> hasIntent(String userId, String matchId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<List<MatchIntent>> getMyIntents(String userId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MatchIntent.fromFirestore(d)).toList();
  }

  Future<bool> hasAttendance(String userId, String matchId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.attendances)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> recordAttendance(
    String userId,
    MatchModel match,
    double? lat,
    double? lon,
  ) async {
    final matchId = match.id;
    final existing = await _firestore
        .collection(FirestoreCollections.attendances)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .get();
    if (existing.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    final attendanceRef = _firestore.collection(FirestoreCollections.attendances).doc();
    final data = <String, dynamic>{
      'userId': userId,
      'matchId': matchId,
      'verifiedAt': Timestamp.now(),
      'latitude': lat,
      'longitude': lon,
    };
    if (match.source != MatchSource.firestore) {
      data['matchHomeTeamSnapshot'] = match.homeTeam;
      data['matchAwayTeamSnapshot'] = match.awayTeam;
      if (match.league != null && match.league!.isNotEmpty) {
        data['matchLeagueSnapshot'] = match.league;
      }
    }
    batch.set(attendanceRef, data);
    final userRef = _firestore.collection(FirestoreCollections.users).doc(userId);
    batch.update(userRef, {
      'attendanceCount': FieldValue.increment(1),
    });
    await batch.commit();
    notifyListeners();
  }

  Future<List<Attendance>> getMyAttendances(String userId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.attendances)
        .where('userId', isEqualTo: userId)
        .orderBy('verifiedAt', descending: true)
        .get();
    return snap.docs.map((d) => Attendance.fromFirestore(d)).toList();
  }

  /// Проверяет, попадает ли текущее время в допустимое окно для матча.
  bool isWithinTimeWindow(DateTime matchStart) {
    final now = DateTime.now();
    final start = matchStart.subtract(Duration(minutes: minutesBeforeMatchStart));
    final end = matchStart.add(Duration(minutes: minutesAfterMatchStart));
    return !now.isBefore(start) && !now.isAfter(end);
  }

  /// Проверка геолокации и фиксация посещения. Вызывать в день матча.
  Future<bool> checkAndRecordAttendance(
    String userId,
    MatchModel match,
    LocationService locationService,
  ) async {
    final stadium = match.effectiveStadium;
    if (stadium == null) return false;
    if (!isWithinTimeWindow(match.startTime)) return false;
    final ok = await locationService.isUserNearStadium(stadium.latitude, stadium.longitude);
    if (!ok) return false;
    final pos = locationService.lastPosition;
    await recordAttendance(userId, match, pos?.latitude, pos?.longitude);
    return true;
  }
}
