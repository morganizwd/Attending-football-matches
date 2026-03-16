import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/attendance_service.dart';
import 'package:attending_football_matches/models/match_model.dart';
import 'package:attending_football_matches/models/attendance.dart';
import 'package:attending_football_matches/models/stadium.dart';
import 'package:attending_football_matches/core/constants.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Attendance> _attendances = [];
  final Map<String, MatchModel> _matchCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    final attendance = context.read<AttendanceService>();
    final list = await attendance.getMyAttendances(uid);
    final firestore = FirebaseFirestore.instance;
    for (final a in list) {
      if (!_matchCache.containsKey(a.matchId)) {
        final matchDoc = await firestore.collection(FirestoreCollections.matches).doc(a.matchId).get();
        if (matchDoc.exists) {
          final stadiumId = matchDoc.get('stadiumId') as String? ?? '';
          Stadium? stadium;
          if (stadiumId.isNotEmpty) {
            final stadiumDoc = await firestore.collection(FirestoreCollections.stadiums).doc(stadiumId).get();
            if (stadiumDoc.exists) stadium = Stadium.fromFirestore(stadiumDoc);
          }
          _matchCache[a.matchId] = MatchModel.fromFirestore(matchDoc, stadium: stadium);
        }
      }
    }
    if (mounted) {
      setState(() {
        _attendances = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('История посещений')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('История посещений')),
      body: _attendances.isEmpty
          ? Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'Пока нет посещённых матчей',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Отметьте намерение и придите на стадион в день матча',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _attendances.length,
              itemBuilder: (context, i) {
                final a = _attendances[i];
                final m = _matchCache[a.matchId];
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.sports_soccer, color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(m?.title ?? 'Матч #${a.matchId}'),
                    subtitle: Text('Подтверждено: ${dateFormat.format(a.verifiedAt)}'),
                    trailing: Icon(Icons.check_circle, color: colorScheme.tertiary),
                  ),
                );
              },
            ),
    );
  }
}
