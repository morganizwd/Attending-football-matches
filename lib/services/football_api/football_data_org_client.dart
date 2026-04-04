import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/match_source.dart';
import 'package:attending_football_matches/services/football_api/football_api_config.dart';

/// Клиент [football-data.org](https://www.football-data.org/) v4.
class FootballDataOrgClient {
  FootballDataOrgClient(this._config);

  final FootballApiConfig _config;

  static const _base = 'https://api.football-data.org/v4';

  /// Матчи в диапазоне дат (без привязки к одной лиге).
  Future<List<MatchModel>> fetchMatches({DateTime? from, DateTime? to}) async {
    final token = _config.footballDataToken;
    if (token.isEmpty) return [];

    final now = DateTime.now();
    final fromDate = from ?? now.subtract(const Duration(days: 14));
    final toDate = to ?? now.add(const Duration(days: 60));
    final out = <MatchModel>[];
    final seenIds = <String>{};

    // football-data.org ограничивает период запроса 10 днями.
    DateTime cursor = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final endDate = DateTime(toDate.year, toDate.month, toDate.day);

    while (!cursor.isAfter(endDate)) {
      final chunkEnd = cursor.add(const Duration(days: 9));
      final currentEnd = chunkEnd.isAfter(endDate) ? endDate : chunkEnd;

      final uri = Uri.parse('$_base/matches').replace(queryParameters: {
        'dateFrom': _formatDate(cursor),
        'dateTo': _formatDate(currentEnd),
        'limit': '200',
      });

      final res = await http.get(
        uri,
        headers: {'X-Auth-Token': token},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final matches = body['matches'] as List<dynamic>? ?? [];
        for (final m in matches) {
          final map = m as Map<String, dynamic>;
          final model = _matchFromJson(map);
          if (model != null && seenIds.add(model.id)) out.add(model);
        }
      }

      cursor = currentEnd.add(const Duration(days: 1));
    }
    out.sort((a, b) => a.startTime.compareTo(b.startTime));
    return out;
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  MatchModel? _matchFromJson(Map<String, dynamic> map) {
    try {
      final id = map['id'];
      if (id == null) return null;
      final idStr = 'fde_$id';

      final utcDate = map['utcDate'] as String? ?? '';
      final start = DateTime.tryParse(utcDate)?.toLocal() ?? DateTime.now();

      final status = map['status'] as String? ?? '';

      final homeTeam = map['homeTeam'] as Map<String, dynamic>? ?? {};
      final awayTeam = map['awayTeam'] as Map<String, dynamic>? ?? {};
      final competition = map['competition'] as Map<String, dynamic>? ?? {};

      final homeName = homeTeam['name'] as String? ?? '?';
      final awayName = awayTeam['name'] as String? ?? '?';
      final homeCrest = homeTeam['crest'] as String?;
      final awayCrest = awayTeam['crest'] as String?;

      final leagueName = competition['name'] as String?;
      final competitionCode = competition['code'] as String?;

      final finished = status == 'FINISHED' || status == 'AWARDED' || status == 'CANCELLED';

      return MatchModel(
        id: idStr,
        source: MatchSource.footballDataOrg,
        homeTeam: homeName,
        awayTeam: awayName,
        homeTeamLogo: homeCrest,
        awayTeamLogo: awayCrest,
        stadiumId: '',
        stadium: null,
        startTime: start,
        league: leagueName,
        footballDataCompetitionCode: competitionCode,
        apiStatusShort: status,
        venueName: null,
        venueCity: null,
        isActive: !finished,
      );
    } catch (_) {
      return null;
    }
  }
}
