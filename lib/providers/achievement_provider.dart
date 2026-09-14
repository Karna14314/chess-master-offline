import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/services/review_service.dart';

/// Achievement categories, mirroring Chess.com's grouped awards.
enum AchievementCategory {
  bots,
  puzzles,
  study,
  dedication;

  String get title {
    switch (this) {
      case AchievementCategory.bots:
        return 'Bots & Battles';
      case AchievementCategory.puzzles:
        return 'Puzzles & Tactics';
      case AchievementCategory.study:
        return 'Study & Analysis';
      case AchievementCategory.dedication:
        return 'Dedication';
    }
  }

  IconData get icon {
    switch (this) {
      case AchievementCategory.bots:
        return Icons.smart_toy_outlined;
      case AchievementCategory.puzzles:
        return Icons.extension_outlined;
      case AchievementCategory.study:
        return Icons.school_outlined;
      case AchievementCategory.dedication:
        return Icons.local_fire_department_outlined;
    }
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final bool isUnlocked;
  final String? unlockedDate;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.isUnlocked,
    this.unlockedDate,
  });

  Achievement copyWith({bool? isUnlocked, String? unlockedDate}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      category: category,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
    );
  }
}

class AchievementNotifier extends StateNotifier<List<Achievement>> {
  AchievementNotifier() : super(_initialAchievements) {
    _loadAchievements();
  }

  // Accessed by the StateNotifier's `mounted` getter, which throws after
  // dispose in debug builds; track our own flag instead.
  bool _isDisposed = false;

  // Serializes concurrent unlocks: each unlock reads + writes shared state
  // after an await, so overlapping calls (e.g. a win unlocking three
  // achievements at once) would otherwise clobber each other in memory.
  Future<void> _pending = Future.value();

  static const List<Achievement> _initialAchievements = [
    // ── Bots & Battles ──────────────────────────────────────────────
    Achievement(
      id: 'first_blood',
      title: 'First Blood',
      description: 'Win your first game against any bot.',
      icon: Icons.emoji_events_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'bot_collector_5',
      title: 'Bot Collector',
      description: 'Defeat 5 different bots.',
      icon: Icons.group_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'bot_master_10',
      title: 'Bot Master',
      description: 'Defeat 10 different bots.',
      icon: Icons.groups_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'giant_slayer',
      title: 'Giant Slayer',
      description: 'Defeat a bot rated 1700 or higher.',
      icon: Icons.fitness_center_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'grandmaster_slayer',
      title: 'Grandmaster Slayer',
      description: 'Defeat a bot rated 2300 or higher.',
      icon: Icons.workspace_premium_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'campaign_trail',
      title: 'Campaign Trail',
      description: 'Clear Level 1 of the Master Campaign.',
      icon: Icons.flag_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'campaign_half',
      title: 'Halfway Hero',
      description: 'Earn 18 campaign stars.',
      icon: Icons.star_half_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'campaign_champion',
      title: 'Campaign Champion',
      description: 'Earn all 36 campaign stars.',
      icon: Icons.military_tech_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'win_streak_3',
      title: 'Winning Ways',
      description: 'Win 3 games in a row.',
      icon: Icons.trending_up_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    Achievement(
      id: 'win_streak_5',
      title: 'Unstoppable Force',
      description: 'Win 5 games in a row.',
      icon: Icons.bolt_outlined,
      category: AchievementCategory.bots,
      isUnlocked: false,
    ),
    // ── Puzzles & Tactics ───────────────────────────────────────────
    Achievement(
      id: 'puzzle_newbie',
      title: 'Puzzle Newbie',
      description: 'Solve your first puzzle.',
      icon: Icons.extension_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'puzzle_scholar',
      title: 'Puzzle Scholar',
      description: 'Solve 50 puzzles.',
      icon: Icons.psychology_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'puzzle_ace',
      title: 'Puzzle Ace',
      description: 'Solve 200 puzzles.',
      icon: Icons.auto_awesome_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'puzzle_veteran',
      title: 'Puzzle Veteran',
      description: 'Solve 500 puzzles.',
      icon: Icons.shield_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'hot_streak',
      title: 'Hot Streak',
      description: 'Solve 5 puzzles in a row.',
      icon: Icons.local_fire_department_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'tactics_expert',
      title: 'Tactics Expert',
      description: 'Reach a 1600 puzzle rating.',
      icon: Icons.show_chart_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'puzzle_elite',
      title: 'Puzzle Elite',
      description: 'Reach a 2000 puzzle rating.',
      icon: Icons.diamond_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'journey_100',
      title: 'Puzzle Explorer',
      description: 'Solve 100 Journey levels.',
      icon: Icons.explore_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    Achievement(
      id: 'journey_1000',
      title: 'Journey Grandmaster',
      description: 'Complete all 1000 Journey levels.',
      icon: Icons.stars_outlined,
      category: AchievementCategory.puzzles,
      isUnlocked: false,
    ),
    // ── Study & Analysis ────────────────────────────────────────────
    Achievement(
      id: 'first_analysis',
      title: 'Game Reviewer',
      description: 'Analyse your first game.',
      icon: Icons.analytics_outlined,
      category: AchievementCategory.study,
      isUnlocked: false,
    ),
    Achievement(
      id: 'analyst_10',
      title: 'Deep Analyst',
      description: 'Analyse 10 games.',
      icon: Icons.biotech_outlined,
      category: AchievementCategory.study,
      isUnlocked: false,
    ),
    Achievement(
      id: 'lesson_starter',
      title: 'Lesson Starter',
      description: 'Complete your first lesson.',
      icon: Icons.menu_book_outlined,
      category: AchievementCategory.study,
      isUnlocked: false,
    ),
    Achievement(
      id: 'lesson_scholar',
      title: 'Lesson Scholar',
      description: 'Complete 25 lessons.',
      icon: Icons.school_outlined,
      category: AchievementCategory.study,
      isUnlocked: false,
    ),
    Achievement(
      id: 'opening_explorer',
      title: 'Opening Explorer',
      description: 'Play 5 different openings.',
      icon: Icons.map_outlined,
      category: AchievementCategory.study,
      isUnlocked: false,
    ),
    // ── Dedication ──────────────────────────────────────────────────
    Achievement(
      id: 'regular_50',
      title: 'Regular',
      description: 'Play 50 games.',
      icon: Icons.sports_esports_outlined,
      category: AchievementCategory.dedication,
      isUnlocked: false,
    ),
    Achievement(
      id: 'veteran_200',
      title: 'Veteran',
      description: 'Play 200 games.',
      icon: Icons.history_outlined,
      category: AchievementCategory.dedication,
      isUnlocked: false,
    ),
    Achievement(
      id: 'streak_3',
      title: 'On a Roll',
      description: 'Maintain a 3-day playing streak.',
      icon: Icons.whatshot_outlined,
      category: AchievementCategory.dedication,
      isUnlocked: false,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Unstoppable',
      description: 'Maintain a 7-day playing streak.',
      icon: Icons.local_fire_department,
      category: AchievementCategory.dedication,
      isUnlocked: false,
    ),
  ];

  /// One-time migration from the legacy 9-achievement set.
  static const Map<String, String> _legacyMigration = {
    'first_win': 'first_blood',
    'ai_level_5': 'giant_slayer',
    'tactics_5': 'puzzle_newbie',
    'tactics_25': 'puzzle_scholar',
  };

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;

    // Migrate legacy unlocks before reading.
    for (final entry in _legacyMigration.entries) {
      if ((prefs.getBool('ach_${entry.key}') ?? false) &&
          !(prefs.getBool('ach_${entry.value}') ?? false)) {
        await prefs.setBool('ach_${entry.value}', true);
        final legacyDate = prefs.getString('ach_date_${entry.key}');
        if (legacyDate != null) {
          await prefs.setString('ach_date_${entry.value}', legacyDate);
        }
      }
    }

    final updated =
        state.map((ach) {
          final isUnlocked = prefs.getBool('ach_${ach.id}') ?? false;
          final date = prefs.getString('ach_date_${ach.id}');
          return ach.copyWith(isUnlocked: isUnlocked, unlockedDate: date);
        }).toList();

    if (!_isDisposed) {
      state = updated;
    }
  }

  /// Unlock an achievement by ID and check review trigger.
  /// Safe to call without awaiting; concurrent calls are serialized.
  Future<void> unlock(String id) {
    _pending = _pending.then((_) => _unlockNow(id));
    return _pending;
  }

  Future<void> _unlockNow(String id) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index == -1 || state[index].isUnlocked) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;

    await prefs.setBool('ach_$id', true);
    await prefs.setString('ach_date_$id', today);

    if (_isDisposed) return;

    final updated = List<Achievement>.from(state);
    updated[index] = updated[index].copyWith(
      isUnlocked: true,
      unlockedDate: today,
    );

    if (!_isDisposed) {
      state = updated;
    }

    // Trigger native review prompt on milestone achievement
    ReviewService.requestReviewIfAppropriate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Game + rating milestones. Call after recording a game result.
  void checkGameProgress({
    required int totalGames,
    required int bestElo,
    required int maxWinStreak,
  }) {
    if (totalGames >= 1) unlock('first_blood');
    if (totalGames >= 50) unlock('regular_50');
    if (totalGames >= 200) unlock('veteran_200');
    if (maxWinStreak >= 3) unlock('win_streak_3');
    if (maxWinStreak >= 5) unlock('win_streak_5');
    if (bestElo >= 1700) unlock('giant_slayer');
  }

  /// Bot + campaign milestones. Call after recording a bot/campaign match.
  void checkBotProgress({
    required int distinctBotsBeaten,
    required int strongestBotElo,
    required int campaignStars,
    required int campaignUnlockedLevel,
  }) {
    if (distinctBotsBeaten >= 1) unlock('first_blood');
    if (distinctBotsBeaten >= 5) unlock('bot_collector_5');
    if (distinctBotsBeaten >= 10) unlock('bot_master_10');
    if (strongestBotElo >= 1700) unlock('giant_slayer');
    if (strongestBotElo >= 2300) unlock('grandmaster_slayer');
    if (campaignUnlockedLevel >= 2) unlock('campaign_trail');
    if (campaignStars >= 18) unlock('campaign_half');
    if (campaignStars >= 36) unlock('campaign_champion');
  }

  /// Puzzle milestones. Call after recording a puzzle attempt.
  void checkPuzzleProgress({
    required int totalSolved,
    required int currentStreak,
    required int peakRating,
    required int journeySolved,
  }) {
    if (totalSolved >= 1) unlock('puzzle_newbie');
    if (totalSolved >= 50) unlock('puzzle_scholar');
    if (totalSolved >= 200) unlock('puzzle_ace');
    if (totalSolved >= 500) unlock('puzzle_veteran');
    if (currentStreak >= 5) unlock('hot_streak');
    if (peakRating >= 1600) unlock('tactics_expert');
    if (peakRating >= 2000) unlock('puzzle_elite');
    if (journeySolved >= 100) unlock('journey_100');
    if (journeySolved >= 1000) unlock('journey_1000');
  }

  /// Analysis + study milestones.
  void checkStudyProgress({
    required int gamesAnalysed,
    required int lessonsCompleted,
    required int openingsPlayed,
  }) {
    if (gamesAnalysed >= 1) unlock('first_analysis');
    if (gamesAnalysed >= 10) unlock('analyst_10');
    if (lessonsCompleted >= 1) unlock('lesson_starter');
    if (lessonsCompleted >= 25) unlock('lesson_scholar');
    if (openingsPlayed >= 5) unlock('opening_explorer');
  }

  void checkStreak(int streakCount) {
    if (streakCount >= 3) unlock('streak_3');
    if (streakCount >= 7) unlock('streak_7');
  }

  /// Legacy entry point used by the game session viewmodel.
  void checkWins({required int difficultyLevel}) {
    unlock('first_blood');
    if (difficultyLevel >= 5) {
      unlock('giant_slayer');
    }
  }
}

final achievementProvider =
    StateNotifierProvider<AchievementNotifier, List<Achievement>>((ref) {
      return AchievementNotifier();
    });
