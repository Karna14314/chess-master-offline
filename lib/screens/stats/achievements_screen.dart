import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/providers/journey_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/widgets/shared/achievement_card.dart';

/// Dedicated achievements page, opened from the Statistics summary card.
/// Grouped by category (Chess.com-style) with live progress on locked items.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  /// Current progress text for an achievement, e.g. "3/5".
  /// Returns null when no numeric progress applies.
  String? _progressFor(
    String id, {
    required int totalGames,
    required int bestElo,
    required int maxWinStreak,
    required int distinctBotsBeaten,
    required int strongestBotElo,
    required int campaignStars,
    required int campaignUnlockedLevel,
    required int puzzlesSolved,
    required int puzzleStreak,
    required int peakPuzzle,
    required int journeySolved,
    required int gamesAnalysed,
    required int lessonsCompleted,
    required int openingsPlayed,
    required int streakDays,
  }) {
    switch (id) {
      case 'bot_collector_5':
        return '$distinctBotsBeaten/5 bots';
      case 'bot_master_10':
        return '$distinctBotsBeaten/10 bots';
      case 'giant_slayer':
        return strongestBotElo >= 1700 ? null : 'best $strongestBotElo/1700';
      case 'grandmaster_slayer':
        return strongestBotElo >= 2300 ? null : 'best $strongestBotElo/2300';
      case 'campaign_trail':
        return campaignUnlockedLevel >= 2 ? null : 'level $campaignUnlockedLevel/1';
      case 'campaign_half':
        return '$campaignStars/18 stars';
      case 'campaign_champion':
        return '$campaignStars/36 stars';
      case 'win_streak_3':
        return '$maxWinStreak/3 wins';
      case 'win_streak_5':
        return '$maxWinStreak/5 wins';
      case 'puzzle_scholar':
        return '$puzzlesSolved/50';
      case 'puzzle_ace':
        return '$puzzlesSolved/200';
      case 'puzzle_veteran':
        return '$puzzlesSolved/500';
      case 'hot_streak':
        return '$puzzleStreak/5 in a row';      case 'tactics_expert':
        return peakPuzzle >= 1600 ? null : '$peakPuzzle/1600';
      case 'puzzle_elite':
        return peakPuzzle >= 2000 ? null : '$peakPuzzle/2000';
      case 'journey_100':
        return '$journeySolved/100';
      case 'journey_1000':
        return '$journeySolved/1000';
      case 'analyst_10':
        return '$gamesAnalysed/10';
      case 'lesson_scholar':
        return '$lessonsCompleted/25';
      case 'opening_explorer':
        return '$openingsPlayed/5';
      case 'regular_50':
        return '$totalGames/50 games';
      case 'veteran_200':
        return '$totalGames/200 games';
      case 'streak_3':
        return '$streakDays/3 days';
      case 'streak_7':
        return '$streakDays/7 days';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementProvider);
    final stats = ref.watch(statisticsProvider);
    final botState = ref.watch(botProgressProvider);
    final journey = ref.watch(journeyProvider);
    final streak = ref.watch(streakProvider);

    final distinctBotsBeaten =
        botState.botStats.values.where((s) => s.wins > 0).length;
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    String? progressOf(Achievement ach) => _progressFor(
      ach.id,
      totalGames: stats.totalGames,
      bestElo: stats.bestElo,
      maxWinStreak: stats.maxWinStreak,
      distinctBotsBeaten: distinctBotsBeaten,
      strongestBotElo: stats.strongestBotEloBeaten,
      campaignStars: botState.totalCampaignStars,
      campaignUnlockedLevel: botState.campaignUnlockedLevel,
      puzzlesSolved: stats.puzzlesSolved,
      puzzleStreak: stats.maxPuzzleStreak,
      peakPuzzle: stats.highestPuzzleRating,
      journeySolved: journey.solvedCount,
      gamesAnalysed: stats.gamesAnalysed,
      lessonsCompleted: LessonService.instance.completedChaptersCount,
      openingsPlayed: stats.openingsPlayed.keys.length,
      streakDays: streak.streakCount,
    );

    final categories = AchievementCategory.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount / ${achievements.length} Unlocked',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              achievements.isEmpty
                                  ? 0
                                  : unlockedCount / achievements.length,
                          backgroundColor: AppTheme.borderColorFor(
                            context,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final category in categories) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Row(
                children: [
                  Icon(category.icon, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    category.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                  ),
                ],
              ),
            ),
            ...achievements
                .where((a) => a.category == category)
                .map((ach) {
              final progress = ach.isUnlocked ? null : progressOf(ach);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AchievementCard(
                  achievement: ach,
                  progressText: progress,
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
