import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/core/services/diagnostics_service.dart';
import 'package:chess_master/core/services/notification_service.dart';
import 'package:chess_master/screens/main_screen.dart';
import 'package:chess_master/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Diagnostics Service (Local-only, privacy-preserving error log)
  try {
    await LocalDiagnosticsService.instance.initialize();
  } catch (e) {
    debugPrint('Diagnostics initialization failed: $e');
  }

  // Initialize Local Notification Service (On-device scheduled daily puzzle & streak reminders)
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
  }

  // Initialize Audio Service
  try {
    await AudioService.instance.initialize();
  } catch (e) {
    debugPrint('Audio initialization failed: $e');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Configure system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: ChessMasterApp()));
}

class ChessMasterApp extends StatelessWidget {
  const ChessMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessMaster Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppOnboardingGateway(),
    );
  }
}

class AppOnboardingGateway extends StatelessWidget {
  const AppOnboardingGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboardingStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final hasCompleted = snapshot.data ?? false;
        if (!hasCompleted) {
          return const OnboardingScreen();
        }
        return const MainScreen();
      },
    );
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_completed_onboarding') ?? false;
    } catch (_) {
      return false;
    }
  }
}
