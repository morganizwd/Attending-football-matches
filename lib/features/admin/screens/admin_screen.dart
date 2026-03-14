import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/features/admin/screens/stadiums_admin_screen.dart';
import 'package:attending_football_matches/features/admin/screens/matches_admin_screen.dart';

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
          Card(
            child: ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Стадионы'),
              subtitle: const Text('Добавить и редактировать стадионы'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StadiumsAdminScreen())),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_soccer),
              title: const Text('Матчи'),
              subtitle: const Text('Добавить и редактировать матчи'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchesAdminScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
