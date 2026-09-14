import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/providers/journey_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/screens/stats/widgets/rating_graph.dart';
import 'package:chess_master/screens/stats/achievements_screen.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/app_badge.dart';

/// Statistics dashboard screen
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile & Stats',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Achievements',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AchievementsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed:
                () => ref.read(statisticsProvider.notifier).loadStatistics(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Archetype Header
            _buildProfileHeader(context, stats),
            const SizedBox(height: 16),

            // Player ELO card
            _buildEloCard(context, stats),
            const SizedBox(height: 16),

            // Rating history graph
            RatingGraph(
              eloHistory: stats.eloHistory,
              currentElo: stats.currentGameElo,
              initialElo: stats.initialGameElo,
            ),
            const SizedBox(height: 24),

            // Overall stats cards
            _buildOverviewSection(context, stats),
            const SizedBox(height: 24),

            // Record (W/L/D, by color, streaks, best win)
            _buildRecordSection(context, stats),
            const SizedBox(height: 24),

            // Bots: beaten, strongest, campaign
            _buildBotsSection(context, stats),
            const SizedBox(height: 24),

            // Puzzles section
            _buildJourneySection(context),
            const SizedBox(height: 24),
            _buildPuzzlesSection(context, stats),
            const SizedBox(height: 24),

            // Performance by ELO
            _buildPerformanceByElo(context, stats),
            const SizedBox(height: 24),

            // Training: analysis, lessons, openings
            _buildTrainingSection(context, stats),
            const SizedBox(height: 24),

            // Game details
            _buildGameDetails(context, stats),
            const SizedBox(height: 24),

            // Achievements section
            _buildAchievementsSection(context),
            const SizedBox(height: 24),

            // Top openings
            if (stats.openingsPlayed.isNotEmpty)
              _buildTopOpenings(context, stats),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, StatisticsModel stats) {
    final (archetypeTitle, archetypeDesc, archetypeIcon, archeColor) =
        _getPlayerArchetype(stats);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.emeraldGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player Profile',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppBadge.elo(elo: stats.currentGameElo),
                    AppBadge.status(
                      label: '🧩 ${stats.currentPuzzleRating}',
                      color: Colors.purple,
                    ),
                    AppBadge(
                      label: archetypeTitle,
                      leading: Icon(archetypeIcon, size: 14, color: archeColor),
                      color: archeColor,
                      backgroundColor: archeColor.withValues(alpha: 0.15),
                      textColor: archeColor,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  archetypeDesc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String, IconData, Color) _getPlayerArchetype(StatisticsModel stats) {
    if (stats.highestPuzzleRating >= 1600 || stats.puzzlesSolved >= 50) {
      return (
        'Tactical Mastermind',
        'Sharp tactical calculation & puzzle solving',
        Icons.psychology_rounded,
        AppTheme.amberGold,
      );
    } else if (stats.gamesAnalysed >= 5) {
      return (
        'Analytical Scholar',
        'Studies positions deeply with engine analysis',
        Icons.biotech_rounded,
        AppTheme.royalBlue,
      );
    } else if (stats.winRate >= 60 && stats.totalGames >= 5) {
      return (
        'Dominant Conqueror',
        'High victory rate with aggressive play',
        Icons.bolt_rounded,
        AppTheme.crimsonRed,
      );
    } else if (stats.consecutiveWins >= 3) {
      return (
        'Streak Striker',
        'Builds momentum with consecutive victories',
        Icons.local_fire_department_rounded,
        AppTheme.amberGold,
      );
    } else {
      return (
        'Aspiring Grandmaster',
        'Developing solid offline chess mastery',
        Icons.military_tech_rounded,
        AppTheme.emeraldGreen,
      );
    }
  }

  Widget _buildOverviewSection(BuildContext context, StatisticsModel stats) {
    // Distinct bot ELOs beaten at least once.
    final botsBeaten =
        stats.gamesByElo.values.where((e) => e.wins > 0).length;
    final strongestBot =
        stats.strongestBotEloBeaten > 0
            ? '${stats.strongestBotEloBeaten}'
            : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.sports_esports,
                iconColor: AppTheme.primaryColor,
                title: 'Games Played',
                value: stats.totalGames.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                iconColor: Colors.amber,
                title: 'Win Rate',
                value: '${stats.winRate.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.smart_toy_outlined,
                iconColor: Colors.orange,
                title: 'Bots Beaten',
                value: botsBeaten.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.military_tech_outlined,
                iconColor: Colors.deepOrange,
                title: 'Strongest Bot',
                value:
                    stats.strongestBotEloBeaten > 0
                        ? '$strongestBot ELO'
                        : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.extension,
                iconColor: Colors.purple,
                title: 'Puzzles Solved',
                value: '${stats.puzzlesSolved}/${stats.puzzlesAttempted}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                iconColor: Colors.cyan,
                title: 'Peak Puzzle',
                value: stats.highestPuzzleRating.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.analytics_outlined,
                iconColor: Colors.teal,
                title: 'Games Analysed',
                value: stats.gamesAnalysed.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_outlined,
                iconColor: Colors.redAccent,
                title: 'Win Streak',
                value: '${stats.consecutiveWins}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEloCard(BuildContext context, StatisticsModel stats) {
    return Row(
      children: [
        Expanded(child: _buildSingleGameEloCard(context, stats)),
        const SizedBox(width: 12),
        Expanded(child: _buildSinglePuzzleEloCard(context, stats)),
      ],
    );
  }

  Widget _buildSingleGameEloCard(BuildContext context, StatisticsModel stats) {
    final elo = stats.currentGameElo;
    final trend = stats.eloTrend;

    final eloColor = StatisticsModel.getRatingColor(elo);
    final tierName = StatisticsModel.getRatingTier(elo);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: eloColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sports_esports_rounded, color: eloColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: eloColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: eloColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  tierName,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: eloColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$elo',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: eloColor,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'Game ELO',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryFor(context),
                ),
              ),
              if (trend != 0) ...[
                const SizedBox(width: 4),
                Icon(
                  trend > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: trend > 0 ? Colors.green : Colors.red,
                ),
                Text(
                  '${trend > 0 ? "+" : ""}$trend',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: trend > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stats.totalGames > 0 ? 'Best: ${stats.bestElo}' : 'No matches yet',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textHintFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePuzzleEloCard(BuildContext context, StatisticsModel stats) {
    final elo = stats.currentPuzzleRating;

    Color puzzleColor;
    String tierName;
    if (elo >= 2200) {
      puzzleColor = const Color(0xFFE91E63);
      tierName = 'Grand Tactician';
    } else if (elo >= 1800) {
      puzzleColor = const Color(0xFF7B1FA2);
      tierName = 'Master';
    } else if (elo >= 1500) {
      puzzleColor = const Color(0xFFFFB300);
      tierName = 'Expert';
    } else if (elo >= 1200) {
      puzzleColor = const Color(0xFF1E88E5);
      tierName = 'Intermediate';
    } else if (elo >= 900) {
      puzzleColor = const Color(0xFF00BFA5);
      tierName = 'Apprentice';
    } else {
      puzzleColor = const Color(0xFF8D6E63);
      tierName = 'Novice';
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: puzzleColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.extension_rounded, color: puzzleColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: puzzleColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: puzzleColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  tierName,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: puzzleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$elo',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: puzzleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Puzzle Rating',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stats.puzzlesAttempted > 0
                ? 'Peak: ${stats.highestPuzzleRating} • ${stats.puzzlesSolved} solved'
                : 'Puzzles: 0 attempted',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textHintFor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Chess.com-style record card: W/L/D, by-color wins, longest streak,
  /// best win. Replaces the old pie chart with actionable detail.
  Widget _buildRecordSection(BuildContext context, StatisticsModel stats) {
    if (stats.totalGames == 0) {
      return _buildEmptyState('No games played yet');
    }

    final bestWin =
        stats.strongestBotEloBeaten > 0
            ? '${_botName(stats.strongestBotEloBeaten)} (${stats.strongestBotEloBeaten})'
            : '—';

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Wins / Draws / Losses',
            value: '${stats.wins} / ${stats.draws} / ${stats.losses}',
          ),
          _DetailRow(
            label: 'Win rate',
            value: '${stats.winRate.toStringAsFixed(1)}%',
          ),
          _DetailRow(
            label: 'Wins as White',
            value: stats.winsAsWhite.toString(),
          ),
          _DetailRow(label: 'Wins as Black', value: stats.winsAsBlack.toString()),
          _DetailRow(
            label: 'Longest win streak',
            value: stats.maxWinStreak.toString(),
          ),
          _DetailRow(label: 'Best win', value: bestWin),
        ],
      ),
    );
  }

  /// Closest bot name for an ELO (powers "best win" labels).
  String _botName(int elo) {
    try {
      return BotProfile.getClosestToElo(elo).name;
    } catch (_) {
      return 'Bot';
    }
  }

  /// Bots card: unlocked/beaten counts, max rating played + defeated,
  /// campaign progress. Bot identity comes from BotProgress + stats.
  Widget _buildBotsSection(BuildContext context, StatisticsModel stats) {
    final botState = ref.watch(botProgressProvider);
    final faced = botState.botStats.length;
    final beaten =
        botState.botStats.values.where((s) => s.wins > 0).length;
    int maxPlayed = 0;
    for (final entry in stats.gamesByElo.entries) {
      if (entry.value.total > 0 && entry.key > maxPlayed) {
        maxPlayed = entry.key;
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smart_toy_outlined,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'Bots',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Faced', value: '$faced'),
              _StatItem(label: 'Defeated', value: '$beaten'),
              _StatItem(
                label: 'Unlocked',
                value: '${botState.campaignUnlockedLevel}/12',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Max rating played',
            value: maxPlayed > 0 ? '$maxPlayed' : '—',
          ),
          _DetailRow(
            label: 'Max rating defeated',
            value:
                stats.strongestBotEloBeaten > 0
                    ? '${_botName(stats.strongestBotEloBeaten)} (${stats.strongestBotEloBeaten})'
                    : '—',
          ),
          _DetailRow(
            label: 'Campaign stars',
            value: '${botState.totalCampaignStars}/36',
          ),
        ],
      ),
    );
  }

  /// Training card: analysis volume, lesson completion, opening breadth.
  Widget _buildTrainingSection(BuildContext context, StatisticsModel stats) {
    final lessonsDone = LessonService.instance.completedChaptersCount;
    final lessonsTotal = LessonService.instance.totalChaptersCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Training',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Analysed',
                value: '${stats.gamesAnalysed}',
              ),
              _StatItem(
                label: 'Lessons',
                value: lessonsTotal > 0 ? '$lessonsDone/$lessonsTotal' : '$lessonsDone',
              ),
              _StatItem(
                label: 'Openings',
                value: '${stats.openingsPlayed.keys.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneySection(BuildContext context) {
    final journey = ref.watch(journeyProvider);
    final streak = ref.watch(streakProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Puzzle Journey',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${journey.completionPercent.toStringAsFixed(1)}% Done',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Level', value: '${journey.currentLevel}'),
              _StatItem(label: 'Solved', value: '${journey.solvedCount}'),
              _StatItem(label: 'Remaining', value: '${journey.remainingCount}'),
              _StatItem(label: 'Streak', value: '${streak.streakCount}d'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: journey.completionPercent / 100,
              backgroundColor: AppTheme.borderColorFor(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzlesSection(BuildContext context, StatisticsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.extension, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Puzzles',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Attempted',
                value: stats.puzzlesAttempted.toString(),
              ),
              _StatItem(label: 'Solved', value: stats.puzzlesSolved.toString()),
              _StatItem(
                label: 'Solve Rate',
                value: '${stats.puzzleSolveRate.toStringAsFixed(1)}%',
              ),
              _StatItem(
                label: 'Rating',
                value: stats.currentPuzzleRating.toString(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Peak Rating',
                value: stats.highestPuzzleRating.toString(),
              ),
              _StatItem(
                label: 'Best Streak',
                value: stats.maxPuzzleStreak.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceByElo(BuildContext context, StatisticsModel stats) {
    if (stats.gamesByElo.isEmpty) {
      return _buildEmptyState('No games played yet');
    }

    final sortedElos = stats.gamesByElo.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance by Difficulty',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sortedElos.map((elo) {
            final eloStats = stats.gamesByElo[elo]!;
            final difficultyLevel = AppConstants.difficultyLevels.firstWhere(
              (d) => d.elo == elo,
              orElse: () => AppConstants.difficultyLevels.first,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${difficultyLevel.name} ($elo ELO)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${eloStats.winRate.toStringAsFixed(0)}% win rate',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getWinRateColor(eloStats.winRate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: eloStats.wins,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius:
                                eloStats.losses == 0 && eloStats.draws == 0
                                    ? BorderRadius.circular(4)
                                    : const BorderRadius.horizontal(
                                      left: Radius.circular(4),
                                    ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: eloStats.draws,
                        child: Container(height: 8, color: Colors.grey),
                      ),
                      Expanded(
                        flex: eloStats.losses,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius:
                                eloStats.wins == 0 && eloStats.draws == 0
                                    ? BorderRadius.circular(4)
                                    : const BorderRadius.horizontal(
                                      right: Radius.circular(4),
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${eloStats.wins}W / ${eloStats.draws}D / ${eloStats.losses}L (${eloStats.total} games)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGameDetails(BuildContext context, StatisticsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Total Moves Played',
            value: stats.totalMoves.toString(),
          ),
          _DetailRow(
            label: 'Average Game Length',
            value: '${stats.averageGameLength.toStringAsFixed(1)} moves',
          ),
          _DetailRow(
            label: 'Total Playing Time',
            value: _formatDuration(
              Duration(seconds: stats.totalGameTimeSeconds),
            ),
          ),
          _DetailRow(
            label: 'Average Game Time',
            value: '${stats.averageGameTimeMinutes.toStringAsFixed(1)} min',
          ),
          _DetailRow(label: 'Hints Used', value: stats.hintsUsed.toString()),
        ],
      ),
    );
  }

  Widget _buildTopOpenings(BuildContext context, StatisticsModel stats) {
    final sortedOpenings =
        stats.openingsPlayed.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topOpenings = sortedOpenings.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most Played Openings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...topOpenings.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value} games',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: AppTheme.textHintFor(context),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: AppTheme.textHintFor(context)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getWinRateColor(double winRate) {
    if (winRate >= 60) return Colors.green;
    if (winRate >= 40) return Colors.amber;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Achievements subsection: summary card that opens the full page.
  Widget _buildAchievementsSection(BuildContext context) {
    final achievements = ref.watch(achievementProvider);
    final theme = Theme.of(context);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements & Trophies',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AchievementsScreen(),
                ),
              ),
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space10),
                decoration: BoxDecoration(
                  color: AppTheme.amberGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppTheme.amberGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlockedCount / ${achievements.length} Unlocked',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View all trophies and how to earn them',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryFor(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.space14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
