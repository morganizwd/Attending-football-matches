import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/features/admin/screens/stadiums_admin_screen.dart';
import 'package:attending_football_matches/features/admin/screens/matches_admin_screen.dart';
import 'package:attending_football_matches/features/admin/screens/achievements_admin_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthService>().isAdmin) {
      return const Scaffold(body: Center(child: Text('Доступ запрещён')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Администрирование')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Панель управления контентом',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Стадионы'),
              subtitle: const Text('Добавить и редактировать стадионы'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StadiumsAdminScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_soccer),
              title: const Text('Матчи'),
              subtitle: const Text('Предстоящие и прошедшие матчи'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchesAdminScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Достижения'),
              subtitle: const Text('Конструктор бейджей и условий'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsAdminScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
