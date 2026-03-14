import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconId;
  final int requiredCount;
  final String type; // 'matches', 'stadiums', 'teams', etc.

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconId,
    required this.requiredCount,
    required this.type,
  });

  factory Achievement.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data()! as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconId: map['iconId'] as String? ?? 'trophy',
      requiredCount: map['requiredCount'] as int? ?? 1,
      type: map['type'] as String? ?? 'matches',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'iconId': iconId,
        'requiredCount': requiredCount,
        'type': type,
      };
}
