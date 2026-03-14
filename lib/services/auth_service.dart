import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:attending_football_matches/models/user_profile.dart';
import 'package:attending_football_matches/core/constants.dart';

class AuthService extends ChangeNotifier {
  User? _firebaseUser;
  UserProfile? _profile;
  bool _loading = true;

  User? get currentUser => _firebaseUser;
  UserProfile? get profile => _profile;
  bool get isLoading => _loading;
  bool get isAdmin => _profile?.isAdmin ?? false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    _firebaseUser = _auth.currentUser;
    if (_firebaseUser != null) {
      await _loadProfile();
    }
    _loading = false;
    notifyListeners();
    _auth.authStateChanges().listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        await _loadProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile() async {
    if (_firebaseUser == null) return;
    final doc = await _firestore.collection(FirestoreCollections.users).doc(_firebaseUser!.uid).get();
    if (doc.exists) {
      _profile = UserProfile.fromFirestore(doc);
    } else {
      _profile = UserProfile(
        id: _firebaseUser!.uid,
        email: _firebaseUser!.email,
        displayName: _firebaseUser!.displayName,
        photoUrl: _firebaseUser!.photoURL,
        isAdmin: false,
        createdAt: DateTime.now(),
      );
      await _firestore.collection(FirestoreCollections.users).doc(_firebaseUser!.uid).set(_profile!.toFirestore());
    }
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (cred.user != null) {
      await cred.user!.updateDisplayName(displayName);
      _firebaseUser = cred.user;
      await _loadProfile();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _firebaseUser = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    if (_firebaseUser == null) return;
    final ref = _firestore.collection(FirestoreCollections.users).doc(_firebaseUser!.uid);
    final Map<String, dynamic> updates = {};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isNotEmpty) {
      await ref.update(updates);
      await _loadProfile();
    }
  }

  Future<void> setAdmin(String userId, bool isAdmin) async {
    if (!(_profile?.isAdmin ?? false)) return;
    await _firestore.collection(FirestoreCollections.users).doc(userId).update({'isAdmin': isAdmin});
  }
}
