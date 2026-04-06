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
      case AppLifecycleState.inactive:
        // App going to background or becoming inactive
        // Stop engine immediately to prevent use-after-free
        service.stopAnalysis();
        break;
      case AppLifecycleState.resumed:
        // App coming back to foreground
        // Engine is still running, no action needed
        break;
      case AppLifecycleState.detached:
        // App is being destroyed
        // Dispose will be called separately by providers
        break;
      case AppLifecycleState.hidden:
        // App is hidden but may still be active
        break;
    }
  }
}
