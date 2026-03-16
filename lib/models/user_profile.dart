import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAdmin;
  final DateTime? createdAt;
  final int attendanceCount;

  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAdmin = false,
    this.createdAt,
    this.attendanceCount = 0,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    Timestamp? ts = map['createdAt'] as Timestamp?;
    return UserProfile(
      id: doc.id,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isAdmin: map['isAdmin'] as bool? ?? false,
      createdAt: ts?.toDate(),
      attendanceCount: (map['attendanceCount'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'isAdmin': isAdmin,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'attendanceCount': attendanceCount,
      };
}
