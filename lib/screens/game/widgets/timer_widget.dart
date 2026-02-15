import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/core/theme/app_theme.dart';

/// Chess timer widget displaying time for one player
class ChessTimerWidget extends ConsumerWidget {
  final bool isWhite;
  final bool isActive;
  final bool compact;

  const ChessTimerWidget({
    super.key,
    required this.isWhite,
    required this.isActive,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);

    if (!timerState.hasTimer) {
      return _buildNoTimer(context);
    }

    final time = isWhite ? timerState.whiteTime : timerState.blackTime;
    final timeStr = TimerState.formatDuration(time);
    final isTimedOut =
        isWhite ? timerState.whiteTimedOut : timerState.blackTimedOut;
    final isLowTime = isActive && time.inSeconds <= 10 && time.inSeconds > 0;
    final isCurrentTurn = timerState.isWhiteTurn == isWhite;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(isActive, isLowTime, isTimedOut),
        borderRadius: BorderRadius.circular(8),
        border:
            isCurrentTurn && timerState.isRunning
                ? Border.all(color: AppTheme.primaryLight, width: 2)
                : null,
        boxShadow:
            isActive && timerState.isRunning
                ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLowTime && !compact)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                size: compact ? 14 : 16,
                color: Colors.white,
              ),
            ),
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: compact ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: _getTextColor(isActive, isLowTime, isTimedOut),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTimer(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '--:--',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: compact ? 14 : 18,
          color: isActive ? Colors.white : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isActive, bool isLowTime, bool isTimedOut) {
    if (isTimedOut) {
      return Colors.red.shade900;
    }
    if (isLowTime) {
      return Colors.orange.shade800;
    }
    if (isActive) {
      return AppTheme.primaryColor;
    }
    return AppTheme.cardDark;
  }

  Color _getTextColor(bool isActive, bool isLowTime, bool isTimedOut) {
    if (isTimedOut || isLowTime || isActive) {
      return Colors.white;
    }
    return AppTheme.textSecondary;
  }
}

/// Dual timer widget showing both players' times
class DualTimerWidget extends ConsumerWidget {
  final bool isFlipped;

  const DualTimerWidget({super.key, this.isFlipped = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);

    if (!timerState.hasTimer) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // White timer
          Column(
            children: [
              const Text('White', style: TextStyle(fontSize: 12)),
              ChessTimerWidget(
                isWhite: true,
                isActive: timerState.isWhiteTurn && timerState.isRunning,
              ),
            ],
          ),
          // VS indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'VS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          // Black timer
          Column(
            children: [
              const Text('Black', style: TextStyle(fontSize: 12)),
              ChessTimerWidget(
                isWhite: false,
                isActive: !timerState.isWhiteTurn && timerState.isRunning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Timer control buttons (pause/resume)
class TimerControls extends ConsumerWidget {
  const TimerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    if (!timerState.hasTimer) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timerState.isRunning)
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () => timerNotifier.pause(),
            tooltip: 'Pause timer',
          )
        else if (timerState.isPaused)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => timerNotifier.resume(),
            tooltip: 'Resume timer',
          ),
      ],
    );
  }
}
