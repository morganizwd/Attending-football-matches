import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:attending_football_matches/core/constants.dart';
import 'package:attending_football_matches/models/attendance.dart';
import 'package:attending_football_matches/models/intent.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/stadium.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/location_service.dart';

class AttendanceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<MatchModel>> getUpcomingMatches() async {
    final now = DateTime.now();
    final snap = await _firestore
        .collection(FirestoreCollections.matches)
        .where('isActive', isEqualTo: true)
        .where('startTime', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('startTime')
        .limit(100)
        .get();
    final list = <MatchModel>[];
    for (final doc in snap.docs) {
      final stadiumId = doc.get('stadiumId') as String?;
      Stadium? stadium;
      if ((stadiumId ?? '').isNotEmpty) {
        final stadiumDoc = await _firestore.collection(FirestoreCollections.stadiums).doc(stadiumId).get();
        if (stadiumDoc.exists) stadium = Stadium.fromFirestore(stadiumDoc);
      }
      list.add(MatchModel.fromFirestore(doc, stadium: stadium));
    }
    return list;
  }

  Future<List<MatchModel>> getMatches({String? query, String? league}) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection(FirestoreCollections.matches)
        .where('isActive', isEqualTo: true)
        .orderBy('startTime');
    final snap = await q.get();
    final result = <MatchModel>[];
    for (final doc in snap.docs) {
      final stadiumId = doc.get('stadiumId') as String? ?? '';
      Stadium? stadium;
      if ((stadiumId ?? '').isNotEmpty) {
        final stadiumDoc = await _firestore.collection(FirestoreCollections.stadiums).doc(stadiumId).get();
        if (stadiumDoc.exists) stadium = Stadium.fromFirestore(stadiumDoc);
      }
      result.add(MatchModel.fromFirestore(doc, stadium: stadium));
    }
    var filtered = result.where((m) => m.startTime.isAfter(DateTime.now())).toList();
    if (query != null && query.isNotEmpty) {
      final lower = query.toLowerCase();
      filtered = filtered.where((m) =>
          m.homeTeam.toLowerCase().contains(lower) ||
          m.awayTeam.toLowerCase().contains(lower) ||
          (m.league?.toLowerCase().contains(lower) ?? false)).toList();
    }
    if (league != null && league.isNotEmpty) {
      filtered = filtered.where((m) => m.league == league).toList();
    }
    return filtered;
  }

  Future<void> addIntent(String userId, String matchId, {bool reminderEnabled = true}) async {
    final existing = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .get();
    if (existing.docs.isNotEmpty) return;
    await _firestore.collection(FirestoreCollections.intents).add({
      'userId': userId,
      'matchId': matchId,
      'createdAt': Timestamp.now(),
      'reminderEnabled': reminderEnabled,
    });
    notifyListeners();
  }

  Future<void> removeIntent(String userId, String matchId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    notifyListeners();
  }

  Future<bool> hasIntent(String userId, String matchId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<List<MatchIntent>> getMyIntents(String userId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.intents)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MatchIntent.fromFirestore(d)).toList();
  }

  Future<bool> hasAttendance(String userId, String matchId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.attendances)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> recordAttendance(String userId, String matchId, double? lat, double? lon) async {
    final existing = await _firestore
        .collection(FirestoreCollections.attendances)
        .where('userId', isEqualTo: userId)
        .where('matchId', isEqualTo: matchId)
        .get();
    if (existing.docs.isNotEmpty) return;
    await _firestore.collection(FirestoreCollections.attendances).add({
      'userId': userId,
      'matchId': matchId,
      'verifiedAt': Timestamp.now(),
      'latitude': lat,
      'longitude': lon,
    });
    notifyListeners();
  }

  Future<List<Attendance>> getMyAttendances(String userId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.attendances)
        .where('userId', isEqualTo: userId)
        .orderBy('verifiedAt', descending: true)
        .get();
    return snap.docs.map((d) => Attendance.fromFirestore(d)).toList();
  }

  /// Проверяет, попадает ли текущее время в допустимое окно для матча.
  bool isWithinTimeWindow(DateTime matchStart) {
    final now = DateTime.now();
    final start = matchStart.subtract(Duration(minutes: minutesBeforeMatchStart));
    final end = matchStart.add(Duration(minutes: minutesAfterMatchStart));
    return !now.isBefore(start) && !now.isAfter(end);
  }

  /// Проверка геолокации и фиксация посещения. Вызывать в день матча.
  Future<bool> checkAndRecordAttendance(
    String userId,
    MatchModel match,
    LocationService locationService,
  ) async {
    if (match.stadium == null) return false;
    if (!isWithinTimeWindow(match.startTime)) return false;
    final ok = await locationService.isUserNearStadium(match.stadium!.latitude, match.stadium!.longitude);
    if (!ok) return false;
    final pos = locationService.lastPosition;
    await recordAttendance(userId, match.id, pos?.latitude, pos?.longitude);
    return true;
  }
}
