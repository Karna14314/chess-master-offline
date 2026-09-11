import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((
  ref,
) {
  return StreakNotifier();
});

class StreakState {
  final int streakCount;
  final bool isPuzzleSolvedToday;
  final bool isDailyPuzzleSolvedToday;
  final String lastActivityDate;

  const StreakState({
    this.streakCount = 0,
    this.isPuzzleSolvedToday = false,
    this.isDailyPuzzleSolvedToday = false,
    this.lastActivityDate = '',
  });

  StreakState copyWith({
    int? streakCount,
    bool? isPuzzleSolvedToday,
    bool? isDailyPuzzleSolvedToday,
    String? lastActivityDate,
  }) {
    return StreakState(
      streakCount: streakCount ?? this.streakCount,
      isPuzzleSolvedToday: isPuzzleSolvedToday ?? this.isPuzzleSolvedToday,
      isDailyPuzzleSolvedToday:
          isDailyPuzzleSolvedToday ?? this.isDailyPuzzleSolvedToday,
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
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));
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
      if (lastDate.isNotEmpty &&
          lastDate != todayStr &&
          lastDate != yesterdayStr) {
        streak = 0;
        await prefs.setInt('streak_current_count', 0);
      } else if (lastDate == todayStr || lastDate == yesterdayStr) {
        if (streak == 0) {
          streak = 1;
          await prefs.setInt('streak_current_count', 1);
        }
      }

      final isSolvedToday = (lastPuzzleDate == todayStr);
      final lastDailyPuzzleDate =
          prefs.getString('daily_puzzle_last_solved_date') ?? '';
      final isDailySolvedToday = (lastDailyPuzzleDate == todayStr);

      state = StreakState(
        streakCount: streak,
        isPuzzleSolvedToday: isSolvedToday,
        isDailyPuzzleSolvedToday: isDailySolvedToday,
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

      // Fix: Check if this is a new day and reset puzzle solved status
      final lastActivityDate = state.lastActivityDate;
      final isDateChanged = lastActivityDate != todayStr;

      if (lastDate == todayStr) {
        if (currentStreak == 0) {
          currentStreak = 1;
          await prefs.setInt('streak_current_count', 1);
        }
        if (!mounted) return;
        state = state.copyWith(
          streakCount: currentStreak,
          lastActivityDate: todayStr,
          // Reset puzzle solved status if date rolled over from yesterday
          isPuzzleSolvedToday:
              isDateChanged ? false : state.isPuzzleSolvedToday,
        );
        return;
      } else if (lastDate == yesterdayStr) {
        // Continuous streak! The user was active yesterday, so increment.
        currentStreak = (currentStreak == 0 ? 1 : currentStreak) + 1;
      } else {
        // Fix: Multi-day absence — the user missed at least one full day.
        // Reset streak to 1 for the new day rather than preserving a stale count.
        // This prevents a streak from persisting across gaps longer than 24 hours.
        currentStreak = 1;
      }

      await prefs.setString('streak_last_activity_date', todayStr);
      await prefs.setInt('streak_current_count', currentStreak);

      if (!mounted) return;
      state = state.copyWith(
        streakCount: currentStreak,
        lastActivityDate: todayStr,
        // On a new day, reset the puzzle solved flag since it's a new day
        isPuzzleSolvedToday: false,
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

  Future<void> markDailyPuzzleSolvedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _todayDateString();
      await prefs.setString('daily_puzzle_last_solved_date', todayStr);
      await prefs.setString('streak_last_puzzle_date', todayStr);

      await recordActivity();

      if (!mounted) return;
      state = state.copyWith(
        isPuzzleSolvedToday: true,
        isDailyPuzzleSolvedToday: true,
      );
    } catch (_) {}
  }
}
