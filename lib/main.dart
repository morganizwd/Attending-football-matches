import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:attending_football_matches/app.dart';
import 'package:attending_football_matches/core/theme.dart';
import 'package:attending_football_matches/firebase_options.dart';
import 'package:attending_football_matches/services/auth_service.dart';
import 'package:attending_football_matches/services/location_service.dart';
import 'package:attending_football_matches/services/attendance_service.dart';
import 'package:attending_football_matches/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } else {
    await Firebase.initializeApp();
  }
  runApp(const AttendingFootballMatchesApp());
}

class AttendingFootballMatchesApp extends StatelessWidget {
  const AttendingFootballMatchesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => AttendanceService()),
        ChangeNotifierProvider(create: (_) => NotificationService()..init()),
      ],
      child: MaterialApp(
        title: 'Посещение матчей',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }
}
