import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String userId;
  final String matchId;
  final DateTime verifiedAt;
  final double? latitude;
  final double? longitude;

  /// Снимок матча для внешних API (в Firestore нет документа matches/{id}).
  final String? matchHomeTeamSnapshot;
  final String? matchAwayTeamSnapshot;
  final String? matchLeagueSnapshot;

  const Attendance({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.verifiedAt,
    this.latitude,
    this.longitude,
    this.matchHomeTeamSnapshot,
    this.matchAwayTeamSnapshot,
    this.matchLeagueSnapshot,
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
      matchHomeTeamSnapshot: map['matchHomeTeamSnapshot'] as String?,
      matchAwayTeamSnapshot: map['matchAwayTeamSnapshot'] as String?,
      matchLeagueSnapshot: map['matchLeagueSnapshot'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'matchId': matchId,
        'verifiedAt': Timestamp.fromDate(verifiedAt),
        'latitude': latitude,
        'longitude': longitude,
        if (matchHomeTeamSnapshot != null) 'matchHomeTeamSnapshot': matchHomeTeamSnapshot,
        if (matchAwayTeamSnapshot != null) 'matchAwayTeamSnapshot': matchAwayTeamSnapshot,
        if (matchLeagueSnapshot != null) 'matchLeagueSnapshot': matchLeagueSnapshot,
      };

  /// Заголовок для истории, если нет загруженного MatchModel.
  String? get titleSnapshot {
    final h = matchHomeTeamSnapshot;
    final a = matchAwayTeamSnapshot;
    if (h != null && h.isNotEmpty && a != null && a.isNotEmpty) {
      return '$h — $a';
    }
    return null;
  }
}
