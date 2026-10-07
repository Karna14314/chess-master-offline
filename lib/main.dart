import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/core/services/diagnostics_service.dart';
import 'package:chess_master/core/services/notification_service.dart';
import 'package:chess_master/core/services/opening_service.dart';
import 'package:chess_master/core/services/stockfish_lifecycle_observer.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/screens/main_screen.dart';
import 'package:chess_master/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StockfishLifecycleObserver.ensureRegistered();

  // Set preferred orientations (portrait only)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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

  // Defer non-critical startup tasks until after the initial frame is drawn
  // to guarantee immediate window focus and eliminate cold-start ANRs.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.microtask(() async {
      // Local Diagnostics Service
      try {
        await LocalDiagnosticsService.instance.initialize();
      } catch (e) {
        debugPrint('Diagnostics initialization failed: $e');
      }

      // Local Notification Service
      try {
        await NotificationService.instance.initialize();
      } catch (e) {
        debugPrint('Notification initialization failed: $e');
      }

      // Audio Service
      try {
        await AudioService.instance.initialize();
      } catch (e) {
        debugPrint('Audio initialization failed: $e');
      }

      // Opening Playbook & Lesson Services (loads Lichess assets)
      try {
        await OpeningService.instance.initialize();
      } catch (e) {
        debugPrint('OpeningService initialization failed: $e');
      }

      try {
        await LessonService.instance.initialize();
      } catch (e) {
        debugPrint('LessonService initialization failed: $e');
      }
    });
  });
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
