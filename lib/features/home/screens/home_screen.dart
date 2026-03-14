import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/features/matches/screens/matches_screen.dart';
import 'package:attending_football_matches/features/history/screens/history_screen.dart';
import 'package:attending_football_matches/features/profile/screens/profile_screen.dart';
import 'package:attending_football_matches/features/admin/screens/admin_screen.dart';
import 'package:attending_football_matches/features/achievements/screens/achievements_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;
    final tabs = <Widget>[
      const MatchesScreen(),
      const HistoryScreen(),
      const AchievementsScreen(),
      const ProfileScreen(),
      if (isAdmin) const AdminScreen(),
    ];
    final labels = <String>[
      'Матчи',
      'История',
      'Достижения',
      'Профиль',
      if (isAdmin) 'Админ',
    ];
    final icons = <IconData>[
      Icons.sports_soccer,
      Icons.history,
      Icons.emoji_events,
      Icons.person,
      if (isAdmin) Icons.admin_panel_settings,
    ];
    final currentTabs = tabs;
    final currentLabels = labels;
    final currentIcons = icons;

    return Scaffold(
      body: IndexedStack(
        index: _index.clamp(0, currentTabs.length - 1),
        children: currentTabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(
          currentTabs.length,
          (i) => NavigationDestination(
            icon: Icon(currentIcons[i]),
            label: currentLabels[i],
          ),
        ),
      ),
    );
  }
}
