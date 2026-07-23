import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/services/review_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final String? unlockedDate;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedDate,
  });

  Achievement copyWith({
    bool? isUnlocked,
    String? unlockedDate,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
    );
  }
}

class AchievementNotifier extends StateNotifier<List<Achievement>> {
  AchievementNotifier() : super(_initialAchievements) {
    _loadAchievements();
  }

  static const List<Achievement> _initialAchievements = [
    Achievement(
      id: 'first_win',
      title: 'First Victory',
      description: 'Win your first match against Stockfish AI.',
      icon: Icons.emoji_events_outlined,
      isUnlocked: false,
    ),
    Achievement(
      id: 'tactics_5',
      title: 'Tactics Scholar',
      description: 'Solve 5 Daily Puzzles successfully.',
      icon: Icons.extension_outlined,
      isUnlocked: false,
    ),
    Achievement(
      id: 'tactics_25',
      title: 'Tactics Master',
      description: 'Solve 25 Daily Puzzles.',
      icon: Icons.psychology_outlined,
      isUnlocked: false,
    ),
    Achievement(
      id: 'streak_3',
      title: 'On a Roll',
      description: 'Maintain a 3-day playing streak.',
      icon: Icons.local_fire_department_outlined,
      isUnlocked: false,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Unstoppable',
      description: 'Maintain a 7-day playing streak.',
      icon: Icons.whatshot_outlined,
      isUnlocked: false,
    ),
    Achievement(
      id: 'ai_level_5',
      title: 'Grandmaster Slayer',
      description: 'Defeat Stockfish AI at Level 5 or higher.',
      icon: Icons.workspace_premium_outlined,
      isUnlocked: false,
    ),
  ];

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = state.map((ach) {
      final isUnlocked = prefs.getBool('ach_${ach.id}') ?? false;
      final date = prefs.getString('ach_date_${ach.id}');
      return ach.copyWith(isUnlocked: isUnlocked, unlockedDate: date);
    }).toList();

    if (mounted) {
      state = updated;
    }
  }

  /// Unlock an achievement by ID and check review trigger.
  Future<void> unlock(String id) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index == -1 || state[index].isUnlocked) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;

    await prefs.setBool('ach_$id', true);
    await prefs.setString('ach_date_$id', today);

    if (!mounted) return;

    final updated = List<Achievement>.from(state);
    updated[index] = updated[index].copyWith(
      isUnlocked: true,
      unlockedDate: today,
    );

    if (mounted) {
      state = updated;
    }

    // Trigger native review prompt on milestone achievement
    ReviewService.requestReviewIfAppropriate();
  }

  /// Check conditions and unlock relevant achievements.
  void checkWins({required int difficultyLevel}) {
    unlock('first_win');
    if (difficultyLevel >= 5) {
      unlock('ai_level_5');
    }
  }

  void checkPuzzlesSolved(int totalSolved) {
    if (totalSolved >= 5) unlock('tactics_5');
    if (totalSolved >= 25) unlock('tactics_25');
  }

  void checkStreak(int streakCount) {
    if (streakCount >= 3) unlock('streak_3');
    if (streakCount >= 7) unlock('streak_7');
  }
}

final achievementProvider =
    StateNotifierProvider<AchievementNotifier, List<Achievement>>((ref) {
  return AchievementNotifier();
});
