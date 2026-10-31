import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/core/services/diagnostics_service.dart';
import 'package:chess_master/core/services/notification_service.dart';
import 'package:chess_master/core/services/daily_puzzle_notification_service.dart';
import 'package:chess_master/screens/puzzles/daily_puzzle_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:chess_master/core/services/opening_service.dart';
import 'package:chess_master/core/services/stockfish_lifecycle_observer.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/screens/main_screen.dart';
import 'package:chess_master/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register Inter font license
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });

  // Bound image cache to prevent OutOfMemoryErrors during extended sessions
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024; // 30 MB
  PaintingBinding.instance.imageCache.maximumSize = 100;

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

      // Local Notification Services
      try {
        await NotificationService.instance.initialize();
        await DailyPuzzleNotificationService.instance.initialize(
          onNotificationTap: (NotificationResponse response) {
            if (response.payload == 'daily_puzzle') {
              appNavigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => const DailyPuzzleScreen(),
                ),
              );
            }
          },
        );

        final plugin = FlutterLocalNotificationsPlugin();
        final launchDetails = await plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true &&
            launchDetails?.notificationResponse?.payload == 'daily_puzzle') {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => const DailyPuzzleScreen(),
            ),
          );
        }
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

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ChessMasterApp extends ConsumerWidget {
  const ChessMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'ChessMaster Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
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
