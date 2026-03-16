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
  Map<String, int> _byStadium = {};
  Map<String, int> _byTeam = {};
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

    // Подсчёты по стадионам и командам
    final Map<String, int> byStadium = {};
    final Map<String, int> byTeam = {};
    for (final a in list) {
      final matchDoc = await firestore.collection(FirestoreCollections.matches).doc(a.matchId).get();
      if (!matchDoc.exists) continue;
      final matchData = matchDoc.data() as Map<String, dynamic>? ?? {};
      final stadiumId = matchData['stadiumId'] as String? ?? '';
      if (stadiumId.isNotEmpty) {
        byStadium[stadiumId] = (byStadium[stadiumId] ?? 0) + 1;
      }
      final homeTeam = matchData['homeTeam'] as String? ?? '';
      final awayTeam = matchData['awayTeam'] as String? ?? '';
      if (homeTeam.isNotEmpty) {
        byTeam[homeTeam] = (byTeam[homeTeam] ?? 0) + 1;
      }
      if (awayTeam.isNotEmpty) {
        byTeam[awayTeam] = (byTeam[awayTeam] ?? 0) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _attendanceCount = list.length;
        _achievements = achievements;
        _byStadium = byStadium;
        _byTeam = byTeam;
        _loading = false;
      });
    }
  }

  bool _unlocked(Achievement a) {
    switch (a.type) {
      case 'matches_total':
        return _attendanceCount >= a.requiredCount;
      case 'matches_same_stadium':
        if (a.stadiumId == null || a.stadiumId!.isEmpty) return false;
        final count = _byStadium[a.stadiumId!] ?? 0;
        return count >= a.requiredCount;
      case 'matches_same_team':
        if (a.teamName == null || a.teamName!.isEmpty) return false;
        final key = a.teamName!;
        final count = _byTeam[key] ?? 0;
        return count >= a.requiredCount;
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Достижения'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Мои бейджи'),
              Tab(text: 'Лидеры'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyAchievements(context),
            const _LeaderBoard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyAchievements(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, size: 46, color: colorScheme.onPrimary),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Посещено матчей',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimary.withOpacity(0.95),
                            ),
                      ),
                      Text(
                        '$_attendanceCount',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                      ),
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
                  'Достижения пока не добавлены. Добавьте их в админ-панели.',
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
                margin: const EdgeInsets.only(bottom: 10),
                color: unlocked ? null : colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: _buildIcon(context, a, unlocked),
                  title: Text(a.title),
                  subtitle: Text(a.description),
                  trailing: unlocked
                      ? Icon(Icons.check_circle, color: colorScheme.tertiary)
                      : Text('${a.requiredCount} матчей'),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context, Achievement a, bool unlocked) {
    if (a.iconUrl != null && a.iconUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(a.iconUrl!),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      );
    }
    return CircleAvatar(
      backgroundColor: unlocked ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Icon(
        _iconFor(a.iconId),
        color: unlocked ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant,
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

class _LeaderBoard extends StatelessWidget {
  const _LeaderBoard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .orderBy('attendanceCount', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Пока нет данных для таблицы лидеров.\nПосещайте матчи, чтобы попасть в рейтинг!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>? ?? {};
            final name = (data['displayName'] as String?)?.trim();
            final email = (data['email'] as String?)?.trim();
            final photoUrl = (data['photoUrl'] as String?)?.trim();
            final count = (data['attendanceCount'] as int?) ?? 0;
            final String title = (name != null && name.isNotEmpty)
                ? name
                : (email != null && email.isNotEmpty)
                    ? email
                    : 'Пользователь';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: _rankBgColor(colorScheme, index),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _rankTextColor(colorScheme, index),
                              ),
                        )
                      : null,
                ),
                title: Text(title),
                subtitle: Text('Посещено матчей: $count'),
                trailing: Text(
                  '#${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _rankNumberColor(colorScheme, index),
                      ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _rankBgColor(ColorScheme scheme, int index) {
    if (index == 0) return const Color(0xFFFFD166);
    if (index == 1) return const Color(0xFFC9D3E3);
    if (index == 2) return const Color(0xFFE6B089);
    return scheme.primaryContainer;
  }

  Color _rankTextColor(ColorScheme scheme, int index) {
    if (index <= 2) return const Color(0xFF1A1A1A);
    return scheme.onPrimaryContainer;
  }

  Color _rankNumberColor(ColorScheme scheme, int index) {
    if (index == 0) return const Color(0xFFD68700);
    if (index == 1) return const Color(0xFF5A667A);
    if (index == 2) return const Color(0xFF9A5C34);
    return scheme.primary;
  }
}
