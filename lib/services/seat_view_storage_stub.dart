import 'package:attending_football_matches/models/seat_view_report.dart';

/// Web: локальные файлы недоступны.
class SeatViewStorageService {
  SeatViewStorageService._();

  static bool get isSupported => false;

  static Future<List<SeatViewReport>> listForMatch(String _) async => [];

  static Future<SeatViewReport?> addReport({
    required String matchId,
    required String sourceImagePath,
    String? seatNote,
    required bool goodView,
    required bool farFromPitch,
  }) async =>
      null;

  static Future<void> deleteReport(String reportId) async {}

  static Future<String?> absoluteImagePath(SeatViewReport report) async => null;
}
