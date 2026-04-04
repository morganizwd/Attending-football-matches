import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация внешних футбольных API.
///
/// Приоритет значений:
/// 1. Файлы окружения (см. [loadDotEnv] в `lib/core/env_loader.dart`): `.env`, затем `.env.example`
/// 2. `--dart-define=KEY=value` при сборке/запуске
///
/// Примеры:
/// ```bash
/// flutter run --dart-define=API_FOOTBALL_KEY=ваш_ключ
/// ```
/// Или ключи в `.env` в корне проекта (файл нужно добавить в `pubspec.yaml` → `assets`, см. README).
class FootballApiConfig {
  FootballApiConfig({
    required this.apiFootballKey,
    required this.apiFootballLeagueIds,
    required this.footballDataToken,
  });

  /// Ключ API-Football (api-sports.io / RapidAPI header `x-apisports-key`).
  final String apiFootballKey;

  /// ID лиг API-Football через запятую (например 39 = Premier League).
  final List<int> apiFootballLeagueIds;

  /// Токен football-data.org (заголовок `X-Auth-Token`).
  final String footballDataToken;

  /// Есть ли хотя бы один ключ для загрузки реальных матчей из сети.
  bool get hasAnyApiKey => apiFootballKey.isNotEmpty || footballDataToken.isNotEmpty;

  FootballApiConfig withApiFootballLeagueIds(List<int> ids) {
    return FootballApiConfig(
      apiFootballKey: apiFootballKey,
      apiFootballLeagueIds: ids,
      footballDataToken: footballDataToken,
    );
  }

  factory FootballApiConfig.fromEnvironment() {
    final leagueRaw = _preferDotenvThenDefine(
      'API_FOOTBALL_LEAGUE_IDS',
      const String.fromEnvironment('API_FOOTBALL_LEAGUE_IDS', defaultValue: ''),
    );
    final leagues = _parseIntList(leagueRaw.isEmpty ? '39' : leagueRaw);
    return FootballApiConfig(
      apiFootballKey: _preferDotenvThenDefine(
        'API_FOOTBALL_KEY',
        const String.fromEnvironment('API_FOOTBALL_KEY', defaultValue: ''),
      ),
      apiFootballLeagueIds: leagues.isEmpty ? [39] : leagues,
      footballDataToken: _preferDotenvThenDefine(
        'FOOTBALL_DATA_TOKEN',
        const String.fromEnvironment('FOOTBALL_DATA_TOKEN', defaultValue: ''),
      ),
    );
  }

  /// Непустое значение из dotenv (если уже загружен), иначе из `--dart-define`.
  static String _preferDotenvThenDefine(String key, String fromDefine) {
    if (dotenv.isInitialized) {
      final v = dotenv.env[key]?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return fromDefine;
  }

  static List<int> _parseIntList(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
  }
}
