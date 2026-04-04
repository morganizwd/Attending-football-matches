import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:attending_football_matches/core/constants.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/stadium.dart';

/// Геокодирование арены по названию и городу (для матчей из API без координат).
class VenueGeocodeService {
  VenueGeocodeService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _firestoreCacheAllowed = true;
  static final Map<String, VenueResolutionResult> _memoryCache = {};
  static final Map<String, Future<VenueResolutionResult>> _inFlightByMatch = {};

  static Future<VenueResolutionResult> resolveForMatch(MatchModel match) async {
    final inFlight = _inFlightByMatch[match.id];
    if (inFlight != null) return await inFlight;

    final future = _resolveForMatchInternal(match);
    _inFlightByMatch[match.id] = future;
    try {
      return await future;
    } finally {
      _inFlightByMatch.remove(match.id);
    }
  }

  static Future<VenueResolutionResult> _resolveForMatchInternal(MatchModel match) async {
    if (match.effectiveStadium != null) {
      return VenueResolutionResult(
        stadium: match.effectiveStadium,
        status: VenueResolveStatus.resolved,
      );
    }

    final known = _resolveFromKnownStadiums(match);
    if (known != null) return known;

    final candidates = <_VenueCandidate>[];
    final venueName = match.venueName?.trim() ?? '';
    final venueCity = match.venueCity?.trim();
    if (venueName.isNotEmpty) {
      candidates.add(_VenueCandidate(
        key: 'venue:${venueName.toLowerCase()}|${(venueCity ?? '').toLowerCase()}',
        query: (venueCity != null && venueCity.isNotEmpty) ? '$venueName, $venueCity' : venueName,
        displayName: venueName,
        city: venueCity,
      ));
    }

    // Fallback: если venue пустой/сомнительный, пробуем найти арену по командам и лиге.
    final league = match.league?.trim() ?? '';
    final fallbackQuery = [
      match.homeTeam.trim(),
      if (league.isNotEmpty) league,
      'stadium',
      if (venueCity != null && venueCity.isNotEmpty) venueCity,
    ].where((e) => e.isNotEmpty).join(' ');
    if (fallbackQuery.isNotEmpty) {
      candidates.add(_VenueCandidate(
        key: 'fallback:${match.homeTeam.toLowerCase()}|${league.toLowerCase()}|${(venueCity ?? '').toLowerCase()}',
        query: fallbackQuery,
        displayName: venueName.isNotEmpty ? venueName : '${match.homeTeam} Stadium',
        city: venueCity,
      ));
    }

    if (candidates.isEmpty) {
      return const VenueResolutionResult(status: VenueResolveStatus.stadiumNotFound);
    }

    for (final candidate in candidates) {
      final mem = _memoryCache[candidate.key];
      if (mem != null) return mem;
      final cached = await _readCache(candidate.key);
      if (cached != null) {
        _memoryCache[candidate.key] = cached;
        return cached;
      }
    }

    String? bestImage;
    VenueResolveStatus bestStatus = VenueResolveStatus.geocodeFailed;
    for (final candidate in candidates) {
      final resolved = await _resolveCandidate(candidate);
      _memoryCache[candidate.key] = resolved;
      await _writeCache(candidate.key, resolved);
      if (resolved.status == VenueResolveStatus.resolved && resolved.stadium != null) {
        return resolved;
      }
      if ((bestImage == null || bestImage.isEmpty) &&
          resolved.imageUrl != null &&
          resolved.imageUrl!.isNotEmpty) {
        bestImage = resolved.imageUrl;
      }
      if (resolved.status == VenueResolveStatus.resolvedNoCoords) {
        bestStatus = VenueResolveStatus.resolvedNoCoords;
      }
    }

    if (bestImage != null && bestImage.isNotEmpty) {
      return VenueResolutionResult(
        status: VenueResolveStatus.resolvedNoCoords,
        imageUrl: bestImage,
      );
    }
    return venueName.isEmpty
        ? const VenueResolutionResult(status: VenueResolveStatus.stadiumNotFound)
        : VenueResolutionResult(status: bestStatus);
  }

  static Future<VenueResolutionResult?> _readCache(String key) async {
    if (!_firestoreCacheAllowed) return null;
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore.collection(FirestoreCollections.venueCache).doc(_cacheDocId(key)).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _firestoreCacheAllowed = false;
        return null;
      }
      rethrow;
    }
    if (!doc.exists) return null;
    final map = doc.data() ?? <String, dynamic>{};
    final updatedAt = (map['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt == null) return null;

    final status = _statusFromString(map['status'] as String?);
    final maxAge = status == VenueResolveStatus.resolved ? const Duration(days: 30) : const Duration(days: 1);
    if (DateTime.now().difference(updatedAt) > maxAge) return null;

    if (status != VenueResolveStatus.resolved) {
      return VenueResolutionResult(
        status: status,
        imageUrl: map['imageUrl'] as String?,
      );
    }

    final lat = (map['latitude'] as num?)?.toDouble();
    final lng = (map['longitude'] as num?)?.toDouble();
    final name = map['name'] as String? ?? '';
    if (lat == null || lng == null || name.isEmpty) return null;
    return VenueResolutionResult(
      status: VenueResolveStatus.resolved,
      stadium: Stadium.synthetic(
        id: 'geo_cache_${_cacheDocId(key)}',
        name: name,
        city: map['city'] as String?,
        latitude: lat,
        longitude: lng,
        imageUrl: map['imageUrl'] as String?,
      ),
      imageUrl: map['imageUrl'] as String?,
    );
  }

  static Future<void> _writeCache(String key, VenueResolutionResult result) async {
    if (!_firestoreCacheAllowed) return;
    final stadium = result.stadium;
    try {
      await _firestore.collection(FirestoreCollections.venueCache).doc(_cacheDocId(key)).set({
        'key': key,
        'status': _statusToString(result.status),
        'name': stadium?.name,
        'city': stadium?.city,
        'latitude': stadium?.latitude,
        'longitude': stadium?.longitude,
        'imageUrl': result.imageUrl ?? stadium?.imageUrl,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _firestoreCacheAllowed = false;
        return;
      }
      rethrow;
    }
  }

  static Future<VenueResolutionResult> _resolveCandidate(_VenueCandidate candidate) async {
    try {
      final imageUrl = await _resolveStadiumImageUrl(candidate.displayName, candidate.city);
      final geo = await _resolveCoordinates(
        candidate.query,
        expectedStadiumName: candidate.displayName,
        city: candidate.city,
      );
      if (geo == null) {
        return VenueResolutionResult(
          status: (imageUrl != null && imageUrl.isNotEmpty)
              ? VenueResolveStatus.resolvedNoCoords
              : VenueResolveStatus.geocodeFailed,
          imageUrl: imageUrl,
        );
      }
      return VenueResolutionResult(
        status: VenueResolveStatus.resolved,
        stadium: Stadium.synthetic(
          id: 'geo_${_cacheDocId(candidate.key)}',
          name: candidate.displayName,
          city: candidate.city,
          latitude: geo.$1,
          longitude: geo.$2,
          imageUrl: imageUrl,
        ),
        imageUrl: imageUrl,
      );
    } catch (_) {
      return const VenueResolutionResult(status: VenueResolveStatus.geocodeFailed);
    }
  }

  static Future<(double, double)?> _resolveCoordinates(
    String query, {
    required String expectedStadiumName,
    String? city,
  }) async {
    final overpass = await _resolveCoordinatesViaOverpass(
      expectedStadiumName: expectedStadiumName,
      city: city,
    );
    if (overpass != null) return overpass;

    final nominatim = await _resolveCoordinatesViaNominatim(query);
    if (nominatim != null) return nominatim;

    // Fallback to platform geocoder when web geocoding fails.
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return null;
      return (locations.first.latitude, locations.first.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<(double, double)?> _resolveCoordinatesViaNominatim(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '1',
    });
    try {
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'attending-football-matches/1.0 (venue lookup)',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse((first['lat'] as String?) ?? '');
      final lon = double.tryParse((first['lon'] as String?) ?? '');
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (_) {
      return null;
    }
  }

  static Future<(double, double)?> _resolveCoordinatesViaOverpass({
    required String expectedStadiumName,
    String? city,
  }) async {
    final normalizedExpected = _normalizeName(expectedStadiumName);
    if (normalizedExpected.isEmpty) return null;

    final escaped = _regexEscape(normalizedExpected).replaceAll(' ', '.*');
    final cityPart = (city != null && city.trim().isNotEmpty) ? city.trim() : '';
    final areaClause = cityPart.isNotEmpty
        ? 'area["name"="$cityPart"]->.searchArea;'
        : '';
    final scope = cityPart.isNotEmpty ? '(area.searchArea)' : '';
    final query = '''
[out:json][timeout:20];
$areaClause
(
  node["leisure"="stadium"]["name"~"$escaped",i]$scope;
  way["leisure"="stadium"]["name"~"$escaped",i]$scope;
  relation["leisure"="stadium"]["name"~"$escaped",i]$scope;
);
out center 10;
''';

    try {
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: const {
          'Content-Type': 'text/plain; charset=utf-8',
          'Accept': 'application/json',
        },
        body: query,
      );
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = body['elements'] as List<dynamic>? ?? const [];
      if (elements.isEmpty) return null;

      double bestScore = -1.0;
      (double, double)? bestCoords;
      for (final e in elements) {
        final m = e as Map<String, dynamic>;
        final tags = m['tags'] as Map<String, dynamic>? ?? const {};
        final name = (tags['name'] as String?) ?? '';
        final score = _stadiumConfidenceScore(
          expectedName: expectedStadiumName,
          actualName: name,
          expectedCity: city,
          actualCity: (tags['addr:city'] as String?) ??
              (tags['is_in:city'] as String?) ??
              (tags['addr:town'] as String?),
        );
        final lat = (m['lat'] as num?)?.toDouble() ?? (m['center'] as Map<String, dynamic>?)?['lat']?.toDouble();
        final lon = (m['lon'] as num?)?.toDouble() ?? (m['center'] as Map<String, dynamic>?)?['lon']?.toDouble();
        if (lat == null || lon == null) continue;
        if (score > bestScore) {
          bestScore = score;
          bestCoords = (lat, lon);
        }
      }

      if (bestCoords == null) return null;
      // Жёсткий порог: сохраняем только достаточно уверенные совпадения.
      if (bestScore < 0.62) return null;
      return bestCoords;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolveStadiumImageUrl(String stadiumName, String? city) async {
    final unsplash = await _resolveStadiumImageUrlViaUnsplash(stadiumName, city);
    if (unsplash != null && unsplash.isNotEmpty) return unsplash;

    return _resolveStadiumImageUrlViaWikipedia(stadiumName, city);
  }

  static Future<String?> _resolveStadiumImageUrlViaUnsplash(String stadiumName, String? city) async {
    final key = dotenv.isInitialized ? (dotenv.env['UNSPLASH_ACCESS_KEY']?.trim() ?? '') : '';
    if (key.isEmpty) return null;

    final query = [stadiumName, if (city != null && city.isNotEmpty) city, 'stadium exterior']
        .where((e) => e.isNotEmpty)
        .join(' ');
    final uri = Uri.https('api.unsplash.com', '/search/photos', {
      'query': query,
      'per_page': '1',
      'orientation': 'landscape',
      'content_filter': 'high',
    });
    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Client-ID $key',
          'Accept-Version': 'v1',
        },
      );
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? const [];
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final urls = first['urls'] as Map<String, dynamic>? ?? const {};
      return (urls['regular'] as String?) ?? (urls['small'] as String?) ?? (urls['thumb'] as String?);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolveStadiumImageUrlViaWikipedia(String stadiumName, String? city) async {
    final query = [stadiumName, if (city != null && city.isNotEmpty) city, 'stadium']
        .where((e) => e.isNotEmpty)
        .join(' ');
    try {
      // Step 1: reliable search to get the best title.
      final searchUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'list': 'search',
        'srsearch': query,
        'srlimit': '1',
      });
      final searchRes = await http.get(searchUri);
      if (searchRes.statusCode != 200) return null;
      final searchBody = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final search = ((searchBody['query'] as Map<String, dynamic>?)?['search'] as List<dynamic>?) ?? const [];
      if (search.isEmpty) return null;
      final title = (search.first as Map<String, dynamic>)['title'] as String?;
      if (title == null || title.isEmpty) return null;

      // Step 2: fetch page images by resolved title.
      final imageUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'prop': 'pageimages',
        'piprop': 'original|thumbnail',
        'pithumbsize': '1200',
        'titles': title,
      });
      final imageRes = await http.get(imageUri);
      if (imageRes.statusCode != 200) return null;
      final imageBody = jsonDecode(imageRes.body) as Map<String, dynamic>;
      final pages = (imageBody['query'] as Map<String, dynamic>?)?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;
      final first = pages.values.first as Map<String, dynamic>;
      final original = first['original'] as Map<String, dynamic>?;
      final thumb = first['thumbnail'] as Map<String, dynamic>?;
      return (original?['source'] as String?) ?? (thumb?['source'] as String?);
    } catch (_) {
      return null;
    }
  }

  static VenueResolveStatus _statusFromString(String? value) {
    switch (value) {
      case 'resolved':
        return VenueResolveStatus.resolved;
      case 'resolved_no_coords':
        return VenueResolveStatus.resolvedNoCoords;
      case 'stadium_not_found':
        return VenueResolveStatus.stadiumNotFound;
      case 'geocode_failed':
        return VenueResolveStatus.geocodeFailed;
      default:
        return VenueResolveStatus.unknown;
    }
  }

  static String _statusToString(VenueResolveStatus status) {
    switch (status) {
      case VenueResolveStatus.resolved:
        return 'resolved';
      case VenueResolveStatus.resolvedNoCoords:
        return 'resolved_no_coords';
      case VenueResolveStatus.stadiumNotFound:
        return 'stadium_not_found';
      case VenueResolveStatus.geocodeFailed:
        return 'geocode_failed';
      case VenueResolveStatus.unknown:
        return 'unknown';
    }
  }

  static String _cacheDocId(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) return 'venue';
    if (normalized.length <= 120) return normalized;
    return normalized.substring(0, 120);
  }

  static VenueResolutionResult? _resolveFromKnownStadiums(MatchModel match) {
    final league = _normalizeName(match.league ?? '');
    final home = _normalizeName(match.homeTeam);
    if (home.isEmpty) return null;
    final byTeamLeague = _knownStadiumByTeamLeague['$home|$league'] ?? _knownStadiumByTeamLeague['$home|'];
    if (byTeamLeague == null) return null;
    return VenueResolutionResult(
      status: VenueResolveStatus.resolved,
      stadium: Stadium.synthetic(
        id: 'known_${home.hashCode}',
        name: byTeamLeague.name,
        city: byTeamLeague.city,
        latitude: byTeamLeague.lat,
        longitude: byTeamLeague.lng,
      ),
    );
  }

  static double _stadiumConfidenceScore({
    required String expectedName,
    required String actualName,
    String? expectedCity,
    String? actualCity,
  }) {
    final exp = _tokenize(_normalizeName(expectedName));
    final act = _tokenize(_normalizeName(actualName));
    if (exp.isEmpty || act.isEmpty) return 0;
    final inter = exp.intersection(act).length.toDouble();
    final union = exp.union(act).length.toDouble();
    var score = union == 0 ? 0.0 : inter / union; // Jaccard
    final eCity = _normalizeName(expectedCity ?? '');
    final aCity = _normalizeName(actualCity ?? '');
    if (eCity.isNotEmpty && aCity.isNotEmpty && (aCity.contains(eCity) || eCity.contains(aCity))) {
      score += 0.15;
    }
    if (_normalizeName(actualName).contains(_normalizeName(expectedName))) {
      score += 0.1;
    }
    if (score > 1.0) return 1.0;
    return score;
  }

  static Set<String> _tokenize(String value) {
    return value.split(' ').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static String _normalizeName(String value) {
    var s = value.toLowerCase();
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    s = s.replaceAll(RegExp(r'[^a-z0-9а-яё\s-]'), ' ');
    s = s.replaceAll(RegExp(r'\b(fc|cf|sc|ac|afc|cfc|futebol|club|de|the)\b'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String _regexEscape(String input) {
    return input.replaceAllMapped(RegExp(r'([\\.^$|?*+(){}\[\]-])'), (m) => '\\${m[0]}');
  }

  static const Map<String, _KnownStadium> _knownStadiumByTeamLeague = {
    // Premier League / England (league empty fallback as well)
    'arsenal|': _KnownStadium('Emirates Stadium', 'London', 51.5549, -0.1084),
    'chelsea|': _KnownStadium('Stamford Bridge', 'London', 51.4817, -0.1910),
    'liverpool|': _KnownStadium('Anfield', 'Liverpool', 53.4308, -2.9608),
    'manchester city|': _KnownStadium('Etihad Stadium', 'Manchester', 53.4831, -2.2004),
    'manchester united|': _KnownStadium('Old Trafford', 'Manchester', 53.4631, -2.2913),
    'tottenham hotspur|': _KnownStadium('Tottenham Hotspur Stadium', 'London', 51.6043, -0.0665),
    // LaLiga
    'real madrid|': _KnownStadium('Santiago Bernabeu Stadium', 'Madrid', 40.4531, -3.6883),
    'barcelona|': _KnownStadium('Estadi Olimpic Lluis Companys', 'Barcelona', 41.3643, 2.1527),
    'atletico madrid|': _KnownStadium('Metropolitano Stadium', 'Madrid', 40.4362, -3.5995),
    // Serie A
    'inter|': _KnownStadium('San Siro', 'Milan', 45.4781, 9.1240),
    'ac milan|': _KnownStadium('San Siro', 'Milan', 45.4781, 9.1240),
    'juventus|': _KnownStadium('Allianz Stadium', 'Turin', 45.1096, 7.6413),
    // Bundesliga
    'bayern munich|': _KnownStadium('Allianz Arena', 'Munich', 48.2188, 11.6247),
    'borussia dortmund|': _KnownStadium('Signal Iduna Park', 'Dortmund', 51.4926, 7.4519),
  };
}

class VenueResolutionResult {
  final Stadium? stadium;
  final VenueResolveStatus status;
  final String? imageUrl;

  const VenueResolutionResult({
    this.stadium,
    required this.status,
    this.imageUrl,
  });
}

class _VenueCandidate {
  final String key;
  final String query;
  final String displayName;
  final String? city;

  const _VenueCandidate({
    required this.key,
    required this.query,
    required this.displayName,
    this.city,
  });
}

class _KnownStadium {
  final String name;
  final String city;
  final double lat;
  final double lng;

  const _KnownStadium(this.name, this.city, this.lat, this.lng);
}
