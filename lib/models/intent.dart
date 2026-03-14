import 'package:cloud_firestore/cloud_firestore.dart';

class MatchIntent {
  final String id;
  final String userId;
  final String matchId;
  final DateTime createdAt;
  final bool reminderEnabled;

  const MatchIntent({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.createdAt,
    this.reminderEnabled = true,
  });

  factory MatchIntent.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data()! as Map<String, dynamic>;
    return MatchIntent(
      id: doc.id,
      userId: map['userId'] as String? ?? '',
      matchId: map['matchId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderEnabled: map['reminderEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'matchId': matchId,
        'createdAt': Timestamp.fromDate(createdAt),
        'reminderEnabled': reminderEnabled,
      };
}
