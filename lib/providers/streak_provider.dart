import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier();
});

class StreakState {
  final int streakCount;
  final bool isPuzzleSolvedToday;
  final String lastActivityDate;

  const StreakState({
    this.streakCount = 0,
    this.isPuzzleSolvedToday = false,
    this.lastActivityDate = '',
  });

  StreakState copyWith({
    int? streakCount,
    bool? isPuzzleSolvedToday,
    String? lastActivityDate,
  }) {
    return StreakState(
      streakCount: streakCount ?? this.streakCount,
      isPuzzleSolvedToday: isPuzzleSolvedToday ?? this.isPuzzleSolvedToday,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
    );
  }
}

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(const StreakState()) {
    loadStreak();
  }

  String _todayDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String _yesterdayDateString() {
    return DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
  }

  Future<void> loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final todayStr = _todayDateString();
      final yesterdayStr = _yesterdayDateString();
      final lastDate = prefs.getString('streak_last_activity_date') ?? '';
      int streak = prefs.getInt('streak_current_count') ?? 0;
      final lastPuzzleDate = prefs.getString('streak_last_puzzle_date') ?? '';

      // If last activity was before yesterday, streak broke -> reset to 0
      if (lastDate.isNotEmpty && lastDate != todayStr && lastDate != yesterdayStr) {
        streak = 0;
        await prefs.setInt('streak_current_count', 0);
      }

      final isSolvedToday = (lastPuzzleDate == todayStr);

      state = StreakState(
        streakCount: streak,
        isPuzzleSolvedToday: isSolvedToday,
        lastActivityDate: lastDate,
      );
    } catch (_) {}
  }

  Future<void> recordActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _todayDateString();
      final yesterdayStr = _yesterdayDateString();
      final lastDate = prefs.getString('streak_last_activity_date') ?? '';
      int currentStreak = prefs.getInt('streak_current_count') ?? 0;

      if (lastDate == todayStr) {
        // Already recorded activity today
        return;
      } else if (lastDate == yesterdayStr) {
        // Continuous streak! Increment.
        currentStreak += 1;
      } else {
        // Streak started today
        currentStreak = 1;
      }

      await prefs.setString('streak_last_activity_date', todayStr);
      await prefs.setInt('streak_current_count', currentStreak);

      if (!mounted) return;
      state = state.copyWith(
        streakCount: currentStreak,
        lastActivityDate: todayStr,
      );
    } catch (_) {}
  }

  Future<void> markPuzzleSolvedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _todayDateString();
      await prefs.setString('streak_last_puzzle_date', todayStr);

      await recordActivity();

      if (!mounted) return;
      state = state.copyWith(isPuzzleSolvedToday: true);
    } catch (_) {}
  }
}
