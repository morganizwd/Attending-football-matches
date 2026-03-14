import 'package:flutter/material.dart';
import 'package:attending_football_matches/features/auth/screens/login_screen.dart';
import 'package:attending_football_matches/features/home/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/services/auth_service.dart';

/// Корневой экран: авторизация или главный shell.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.currentUser == null) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
