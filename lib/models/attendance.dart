import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String userId;
  final String matchId;
  final DateTime verifiedAt;
  final double? latitude;
  final double? longitude;

  const Attendance({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.verifiedAt,
    this.latitude,
    this.longitude,
  });

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data()! as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      userId: map['userId'] as String? ?? '',
      matchId: map['matchId'] as String? ?? '',
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'matchId': matchId,
        'verifiedAt': Timestamp.fromDate(verifiedAt),
        'latitude': latitude,
        'longitude': longitude,
      };
}
