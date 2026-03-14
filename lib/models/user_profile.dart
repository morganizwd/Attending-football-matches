import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAdmin;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAdmin = false,
    this.createdAt,
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
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'isAdmin': isAdmin,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      };
}
