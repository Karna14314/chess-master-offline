import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// State for the chess timer
class TimerState {
  final Duration whiteTime;
  final Duration blackTime;
  final bool isWhiteTurn;
  final bool isRunning;
  final bool isPaused;
  final TimeControl timeControl;
  final bool whiteTimedOut;
  final bool blackTimedOut;
  final bool lowTimeWarningShown;

  const TimerState({
    required this.whiteTime,
    required this.blackTime,
    this.isWhiteTurn = true,
    this.isRunning = false,
    this.isPaused = false,
    required this.timeControl,
    this.whiteTimedOut = false,
    this.blackTimedOut = false,
    this.lowTimeWarningShown = false,
  });

  TimerState copyWith({
    Duration? whiteTime,
    Duration? blackTime,
    bool? isWhiteTurn,
    bool? isRunning,
    bool? isPaused,
    TimeControl? timeControl,
    bool? whiteTimedOut,
    bool? blackTimedOut,
    bool? lowTimeWarningShown,
  }) {
    return TimerState(
      whiteTime: whiteTime ?? this.whiteTime,
      blackTime: blackTime ?? this.blackTime,
      isWhiteTurn: isWhiteTurn ?? this.isWhiteTurn,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      timeControl: timeControl ?? this.timeControl,
      whiteTimedOut: whiteTimedOut ?? this.whiteTimedOut,
      blackTimedOut: blackTimedOut ?? this.blackTimedOut,
      lowTimeWarningShown: lowTimeWarningShown ?? this.lowTimeWarningShown,
    );
  }

  /// Check if timer has a time control enabled
  bool get hasTimer => timeControl.hasTimer;

  /// Get current player's time
  Duration get currentPlayerTime => isWhiteTurn ? whiteTime : blackTime;

  /// Check if any player timed out
  bool get isTimedOut => whiteTimedOut || blackTimedOut;

  /// Check if current player is in low time (< 10 seconds)
  bool get isLowTime =>
      currentPlayerTime.inSeconds <= 10 && currentPlayerTime.inSeconds > 0;

  /// Format time for display
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return "0:00";

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final tenths = (duration.inMilliseconds % 1000) ~/ 100;

    if (minutes > 0) {
      return "$minutes:${seconds.toString().padLeft(2, '0')}";
    } else if (seconds <= 10) {
      return "$seconds.$tenths";
    } else {
      return "0:${seconds.toString().padLeft(2, '0')}";
    }
  }

  String get whiteTimeFormatted => formatDuration(whiteTime);
  String get blackTimeFormatted => formatDuration(blackTime);
}

/// Timer notifier for managing chess clock
class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _timer;
  final void Function(bool isWhite)? onTimeout;
  final void Function()? onLowTime;

  TimerNotifier({
    required TimeControl timeControl,
    this.onTimeout,
    this.onLowTime,
  }) : super(
         TimerState(
           whiteTime: timeControl.initialDuration,
           blackTime: timeControl.initialDuration,
           timeControl: timeControl,
         ),
       );

  /// Initialize timer with time control
  void initialize(TimeControl timeControl) {
    _timer?.cancel();
    state = TimerState(
      whiteTime: timeControl.initialDuration,
      blackTime: timeControl.initialDuration,
      timeControl: timeControl,
    );
  }

  /// Start the timer
  void start() {
    if (!state.hasTimer || state.isTimedOut) return;

    _timer?.cancel();
    state = state.copyWith(isRunning: true, isPaused: false);

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _tick();
    });
  }

  /// Pause the timer
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, isPaused: true);
  }

  /// Resume the timer
  void resume() {
    if (!state.hasTimer || state.isTimedOut) return;
    start();
  }

  /// Stop the timer completely
  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, isPaused: false);
  }

  /// Switch turn (called after a move)
  void switchTurn() {
    if (!state.hasTimer) return;

    // Add increment to the player who just moved
    final increment = state.timeControl.incrementDuration;
    Duration newWhiteTime = state.whiteTime;
    Duration newBlackTime = state.blackTime;

    if (state.isWhiteTurn) {
      // White just moved, add increment
      newWhiteTime = state.whiteTime + increment;
    } else {
      // Black just moved, add increment
      newBlackTime = state.blackTime + increment;
    }

    state = state.copyWith(
      isWhiteTurn: !state.isWhiteTurn,
      whiteTime: newWhiteTime,
      blackTime: newBlackTime,
      lowTimeWarningShown: false, // Reset for new turn
    );
  }

  /// Set which player's turn it is
  void setTurn(bool isWhiteTurn) {
    state = state.copyWith(isWhiteTurn: isWhiteTurn);
  }

  /// Tick the timer
  void _tick() {
    if (!state.isRunning || state.isTimedOut) return;

    const tickDuration = Duration(milliseconds: 100);
    Duration newWhiteTime = state.whiteTime;
    Duration newBlackTime = state.blackTime;

    if (state.isWhiteTurn) {
      newWhiteTime = state.whiteTime - tickDuration;
      if (newWhiteTime.isNegative) {
        newWhiteTime = Duration.zero;
      }
    } else {
      newBlackTime = state.blackTime - tickDuration;
      if (newBlackTime.isNegative) {
        newBlackTime = Duration.zero;
      }
    }

    // Check for timeout
    bool whiteTimedOut = newWhiteTime <= Duration.zero;
    bool blackTimedOut = newBlackTime <= Duration.zero;

    state = state.copyWith(
      whiteTime: newWhiteTime,
      blackTime: newBlackTime,
      whiteTimedOut: whiteTimedOut,
      blackTimedOut: blackTimedOut,
    );

    // Handle timeout
    if (whiteTimedOut || blackTimedOut) {
      stop();
      onTimeout?.call(whiteTimedOut);
    }

    // Low time warning
    if (state.isLowTime && !state.lowTimeWarningShown) {
      state = state.copyWith(lowTimeWarningShown: true);
      onLowTime?.call();
    }
  }

  /// Update times directly (for loading saved games)
  void setTimes({Duration? whiteTime, Duration? blackTime}) {
    state = state.copyWith(
      whiteTime: whiteTime ?? state.whiteTime,
      blackTime: blackTime ?? state.blackTime,
    );
  }

  /// Reset timer
  void reset() {
    _timer?.cancel();
    state = TimerState(
      whiteTime: state.timeControl.initialDuration,
      blackTime: state.timeControl.initialDuration,
      timeControl: state.timeControl,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider for the chess timer
final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  // Default to no timer, will be initialized when game starts
  return TimerNotifier(timeControl: AppConstants.timeControls[0]);
});

/// Provider family for creating timer with specific time control
final timerProviderFamily =
    StateNotifierProvider.family<TimerNotifier, TimerState, TimeControl>((
      ref,
      timeControl,
    ) {
      return TimerNotifier(timeControl: timeControl);
    });
