import 'package:flutter/widgets.dart';
import 'stockfish_service.dart';

/// Observes app lifecycle to safely pause/resume Stockfish engine
/// Prevents crashes when app goes to background during engine search
class StockfishLifecycleObserver with WidgetsBindingObserver {
  static StockfishLifecycleObserver? _instance;

  /// Ensures the observer is registered with WidgetsBinding.
  /// Safe to call multiple times - only registers once.
  static void ensureRegistered() {
    if (_instance == null) {
      _instance = StockfishLifecycleObserver();
      WidgetsBinding.instance.addObserver(_instance!);
    }
  }

  /// Unregisters the observer. Call this on app shutdown if needed.
  static void ensureUnregistered() {
    if (_instance != null) {
      WidgetsBinding.instance.removeObserver(_instance!);
      _instance = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = StockfishService.instance;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App going to background or hidden
        // Stop engine search immediately to prevent native crashes / battery drain
        debugPrint(
          '[LIFECYCLE_BREADCRUMB] App state changed to $state -> Stopping active engine search',
        );
        service.stopAnalysis();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed:
        debugPrint('[LIFECYCLE_BREADCRUMB] App state resumed');
        break;
      case AppLifecycleState.detached:
        debugPrint(
          '[LIFECYCLE_BREADCRUMB] App state detached -> Stopping active engine search',
        );
        service.stopAnalysis();
        break;
    }
  }
}
