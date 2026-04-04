import 'package:attending_football_matches/models/match_model.dart';

/// Web: локальный файл недоступен — кэш только в памяти [AttendanceService].
class ApiMatchesCacheStore {
  ApiMatchesCacheStore._();

  static const Duration diskTtl = Duration(hours: 24);

  static Future<List<MatchModel>?> readFresh({
    required String cacheKey,
    required Duration maxAge,
  }) async =>
      null;

  static Future<void> write({
    required String cacheKey,
    required List<MatchModel> matches,
  }) async {}
}
