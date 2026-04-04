import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attending_football_matches/core/constants.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/match_source.dart';
import 'package:attending_football_matches/services/football_api/football_api_config.dart';

/// Клиент [API-Football](https://www.api-football.com/) (v3, endpoint api-sports.io).
class ApiFootballClient {
  ApiFootballClient(this._config);

  final FootballApiConfig _config;

  static const _base = 'https://v3.football.api-sports.io';

  /// Матчи в диапазоне дат по выбранным лигам.
  Future<List<MatchModel>> fetchFixtures({DateTime? from, DateTime? to}) async {
    final key = _config.apiFootballKey;
    if (key.isEmpty) return [];

    final now = DateTime.now();
    final fromDate = from ?? now.subtract(const Duration(days: 14));
    final toDate = to ?? now.add(const Duration(days: 60));
    final fromStr = _formatDate(fromDate);
    final toStr = _formatDate(toDate);
    final leagueIds = _config.apiFootballLeagueIds;
    final out = <MatchModel>[];
    final seen = <String>{};

    for (final leagueId in leagueIds) {
      final seasons = _seasonCandidatesForLeague(leagueId, now);
      leagueLoop:
      for (final season in seasons) {
        final dateRanges = _fixtureDateRangesForSeason(season, fromStr, toStr);
        for (final range in dateRanges) {
          final uri = Uri.parse('$_base/fixtures').replace(queryParameters: {
            'league': '$leagueId',
            'season': '$season',
            'from': range.$1,
            'to': range.$2,
          });
          final res = await http.get(
            uri,
            headers: {'x-apisports-key': key},
          );
          if (res.statusCode != 200) {
            debugPrint(
              'ApiFootballClient: fixtures league=$leagueId season=$season '
              'status=${res.statusCode} body=${res.body.length > 200 ? "${res.body.substring(0, 200)}..." : res.body}',
            );
            continue;
          }

          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (_hasBlockingErrors(body)) {
            debugPrint('ApiFootballClient: league=$leagueId season=$season errors=${body['errors']}');
            continue leagueLoop;
          }

          final response = body['response'] as List<dynamic>? ?? [];
          for (final item in response) {
            final map = item as Map<String, dynamic>;
            final m = _matchFromFixtureJson(map);
            if (m != null && seen.add(m.id)) {
              out.add(m);
            }
          }
          if (response.isNotEmpty) {
            break leagueLoop;
          }
        }
      }
    }
    out.sort((a, b) => a.startTime.compareTo(b.startTime));
    return out;
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Сезон европейских лиг: июль–июнь.
  static int _seasonYearFor(DateTime ref) {
    if (ref.month >= 7) return ref.year;
    return ref.year - 1;
  }

  /// Кандидаты сезона: сначала «текущий» по календарю, затем запасные (в т.ч. лимит бесплатного тарифа 2022–2024).
  static List<int> _seasonCandidatesForLeague(int leagueId, DateTime ref) {
    final european = _seasonYearFor(ref);
    final set = <int>{
      european,
      european - 1,
      apiFootballFreeTierMaxSeasonYear,
      apiFootballFreeTierMaxSeasonYear - 1,
      apiFootballFreeTierMinSeasonYear,
      if (leagueId == apiFootballRussianPremierLeagueId) ...{
        ref.year,
        ref.year - 1,
      },
    };
    return set.where((s) => s >= 2000).toList()..sort((a, b) => b.compareTo(a));
  }

  /// Бесплатный тариф не отдаёт «текущий» сезон; `errors` не пустой — пробуем следующий год сезона.
  static bool _hasBlockingErrors(Map<String, dynamic> body) {
    final errs = body['errors'];
    if (errs == null) return false;
    if (errs is Map && errs.isEmpty) return false;
    if (errs is List && errs.isEmpty) return false;
    final s = errs.toString();
    return s.isNotEmpty && s != 'null';
  }

  /// Сначала окно из UI; если в нём нет матчей (часто даты в «будущем» при старом сезоне) — типичное окно август–июнь.
  static List<(String, String)> _fixtureDateRangesForSeason(
    int season,
    String userFrom,
    String userTo,
  ) {
    final ranges = <(String, String)>[(userFrom, userTo)];
    final typicalFrom = DateTime(season, 8, 1);
    final typicalTo = DateTime(season + 1, 6, 30);
    ranges.add((_formatDate(typicalFrom), _formatDate(typicalTo)));
    return ranges;
  }

  MatchModel? _matchFromFixtureJson(Map<String, dynamic> root) {
    try {
      final fixture = root['fixture'] as Map<String, dynamic>? ?? {};
      final teams = root['teams'] as Map<String, dynamic>? ?? {};
      final league = root['league'] as Map<String, dynamic>? ?? {};
      final id = fixture['id'];
      if (id == null) return null;
      final idStr = 'af_$id';

      final dateStr = fixture['date'] as String? ?? '';
      final start = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();

      final statusMap = fixture['status'] as Map<String, dynamic>? ?? {};
      final short = statusMap['short'] as String?;

      final venue = fixture['venue'] as Map<String, dynamic>? ?? {};
      final venueName = venue['name'] as String?;
      final venueCity = venue['city'] as String?;

      final home = teams['home'] as Map<String, dynamic>? ?? {};
      final away = teams['away'] as Map<String, dynamic>? ?? {};

      final homeName = home['name'] as String? ?? '?';
      final awayName = away['name'] as String? ?? '?';
      final homeLogo = home['logo'] as String?;
      final awayLogo = away['logo'] as String?;

      final leagueName = league['name'] as String?;
      final leagueId = league['id'];
      final leagueIdInt = leagueId is int ? leagueId : int.tryParse('$leagueId');

      final finished = _isFinishedStatus(short);

      return MatchModel(
        id: idStr,
        source: MatchSource.apiFootball,
        homeTeam: homeName,
        awayTeam: awayName,
        homeTeamLogo: homeLogo,
        awayTeamLogo: awayLogo,
        stadiumId: '',
        stadium: null,
        startTime: start,
        league: leagueName,
        apiFootballLeagueId: leagueIdInt,
        apiStatusShort: short,
        venueName: venueName,
        venueCity: venueCity,
        isActive: !finished,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isFinishedStatus(String? short) {
    if (short == null || short.isEmpty) return false;
    const done = {'FT', 'AET', 'PEN', 'AWD', 'WO', 'CANC', 'PST', 'ABD'};
    return done.contains(short);
  }
}
