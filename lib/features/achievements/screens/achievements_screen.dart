import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/attendance_service.dart';
import 'package:attending_football_matches/models/achievement.dart';
import 'package:attending_football_matches/core/constants.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int _attendanceCount = 0;
  List<Achievement> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    final attendance = context.read<AttendanceService>();
    final list = await attendance.getMyAttendances(uid);
    final firestore = FirebaseFirestore.instance;
    final snap = await firestore.collection(FirestoreCollections.achievements).get();
    final achievements = snap.docs.map((d) => Achievement.fromFirestore(d)).toList();
    if (mounted) {
      setState(() {
        _attendanceCount = list.length;
        _achievements = achievements;
        _loading = false;
      });
    }
  }

  bool _unlocked(Achievement a) {
    switch (a.type) {
      case 'matches':
        return _attendanceCount >= a.requiredCount;
      default:
        return _attendanceCount >= a.requiredCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Достижения')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Посещено матчей', style: Theme.of(context).textTheme.titleMedium),
                        Text('$_attendanceCount', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Бейджи', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_achievements.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Достижения пока не добавлены. Добавьте их в Firestore (коллекция achievements).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._achievements.map((a) {
                final unlocked = _unlocked(a);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: unlocked ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unlocked ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Icon(
                        _iconFor(a.iconId),
                        color: unlocked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(a.title),
                    subtitle: Text(a.description),
                    trailing: unlocked ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : Text('${a.requiredCount} матчей'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String iconId) {
    switch (iconId) {
      case 'trophy':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'stadium':
        return Icons.stadium;
      default:
        return Icons.emoji_events;
    }
  }
}
