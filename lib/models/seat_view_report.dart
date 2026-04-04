/// Локальный отчёт «вид с места» на матче (фото + оценки), без Firebase.
class SeatViewReport {
  final String id;
  final String matchId;
  final DateTime createdAt;
  final String imageFileName;
  final String? seatNote;
  /// Хороший вид с этого места.
  final bool goodView;
  /// Далеко от поля.
  final bool farFromPitch;

  const SeatViewReport({
    required this.id,
    required this.matchId,
    required this.createdAt,
    required this.imageFileName,
    this.seatNote,
    required this.goodView,
    required this.farFromPitch,
  });

  factory SeatViewReport.fromJson(Map<String, dynamic> json) {
    return SeatViewReport(
      id: json['id'] as String? ?? '',
      matchId: json['matchId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      imageFileName: json['imageFileName'] as String? ?? '',
      seatNote: json['seatNote'] as String?,
      goodView: json['goodView'] as bool? ?? true,
      farFromPitch: json['farFromPitch'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'matchId': matchId,
        'createdAt': createdAt.toIso8601String(),
        'imageFileName': imageFileName,
        'seatNote': seatNote,
        'goodView': goodView,
        'farFromPitch': farFromPitch,
      };
}
