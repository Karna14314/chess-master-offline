import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/models/campaign_model.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/screens/bots/bot_campaign_screen.dart';
import 'package:chess_master/screens/bots/bot_profile_sheet.dart';
import 'package:chess_master/screens/bots/bots_hub_screen.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/game_setup/new_game_setup_screen.dart';
import 'package:chess_master/screens/puzzles/daily_puzzle_screen.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/learn/learn_screen.dart';
import 'package:chess_master/screens/main_screen.dart';
import 'package:chess_master/widgets/shared/app_badge.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/bot_avatar.dart';
import 'package:chess_master/widgets/shared/bot_card.dart';
import 'package:chess_master/widgets/shared/mini_board.dart';
import 'package:chess_master/widgets/shared/app_section_header.dart';

/// Redesigned Play Home Screen Hub
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // a. Header: smaller app name, streak chip, stars chip (tap -> Profile)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeader(context, textPrimary, textSecondary),
                  ),
                ),

                // Main Play Hub Content
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // b. Hero Card: "Play Bot" or "Resume Game"
                      _buildHeroCard(context),
                      const SizedBox(height: AppTheme.space12),

                      // c. Row of two compact buttons: Pass & Play | Analyze Game
                      _buildCompactButtonsRow(context),
                      const SizedBox(height: AppTheme.space16),

                      // d. Daily Puzzle card ABOVE the fold
                      _buildDailyPuzzleCard(context),
                      const SizedBox(height: AppTheme.space16),

                      // e. "Review last game" shortcut (shown only if a game exists)
                      _buildReviewLastGameShortcut(context),

                      // f. Master Campaign card (compact) with fixed sequential stepper
                      _buildCampaignCard(context),
                      const SizedBox(height: AppTheme.space16),

                      // g. Bot Arena horizontal carousel across rating range with "See all"
                      _buildBotArenaSection(context),
                      const SizedBox(height: AppTheme.space24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header with app name, streak chip, stars chip (tap -> Profile tab)
  Widget _buildHeader(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
  ) {
    final streakState = ref.watch(streakProvider);
    final botState = ref.watch(botProgressProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // App Title
        Text(
          'ChessMaster',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        // Chips (tap -> Profile tab)
        Row(
          children: [
            // Streak Pill
            GestureDetector(
              onTap: () {
                ref.read(mainTabProvider.notifier).state = 3; // Profile Tab
              },
              child: AppBadge.streak(streakDays: streakState.streakCount),
            ),
            const SizedBox(width: 8),

            // Stars Pill
            GestureDetector(
              onTap: () {
                ref.read(mainTabProvider.notifier).state = 3; // Profile Tab
              },
              child: AppBadge.stars(stars: botState.totalBotStars),
            ),
          ],
        ),
      ],
    );
  }

  /// Hero card: "Play Bot" with last-used opponent or "Resume game"
  Widget _buildHeroCard(BuildContext context) {
    final activeSession = ref.watch(gameSessionProvider);
    final repository = ref.read(gameSessionRepositoryProvider);

    // Check for unfinished game in repository or activeSession
    return FutureBuilder<List<GameSession>>(
      future: repository.getUnfinishedGames(limit: 1),
      builder: (context, snapshot) {
        final unfinishedList = snapshot.data ?? [];
        final unfinishedGame = (activeSession != null && !activeSession.isCompleted)
            ? activeSession
            : (unfinishedList.isNotEmpty ? unfinishedList.first : null);

        if (unfinishedGame != null) {
          // Unfinished game -> "Resume Game" hero card
          return _buildResumeHeroCard(context, unfinishedGame);
        }

        // Default -> "Play Bot" hero card with last-used opponent (default Rusty 400)
        final bot = BotProfile.allBots.first;

        return _buildPlayBotHeroCard(context, bot);
      },
    );
  }

  Widget _buildResumeHeroCard(BuildContext context, GameSession game) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final opponentName = game.gameMode == GameMode.bot
        ? (game.botProfile?.name ?? 'Bot (${game.difficulty.elo})')
        : 'Friend';

    return PremiumCard(
      onTap: () {
        ref.read(gameSessionProvider.notifier).resumeSession(game);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      },
      gradient: LinearGradient(
        colors: [
          AppTheme.primaryColor.withValues(alpha: 0.25),
          AppTheme.surfaceLevel1(context),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.5),
      child: Row(
        children: [
          MiniBoard(
            fen: game.startingFen,
            size: 64,
            borderRadius: AppTheme.radiusMd,
            showBorder: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    'GAME IN PROGRESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'vs $opponentName',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Move ${(game.moveHistory.length / 2).ceil()} • ${game.timeControl.name}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(gameSessionProvider.notifier).resumeSession(game);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GameScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              elevation: 0,
            ),
            child: Text(
              'RESUME',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayBotHeroCard(BuildContext context, BotProfile bot) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);

    return PremiumCard(
      onTap: () {
        ref.read(gameSessionProvider.notifier).startNewGame(
              playerColor: PlayerColor.white,
              difficulty: AppConstants.difficultyLevels.firstWhere(
                (d) => d.elo == bot.elo,
                orElse: () => AppConstants.difficultyLevels[0],
              ),
              timeControl: AppConstants.timeControls[0],
              gameMode: GameMode.bot,
              botProfile: bot,
            );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      },
      gradient: LinearGradient(
        colors: [
          AppTheme.primaryColor.withValues(alpha: 0.2),
          AppTheme.surfaceLevel1(context),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.4),
      child: Column(
        children: [
          Row(
            children: [
              BotAvatar(bot: bot, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Play Bot',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BotsHubScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Choose opponent →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bot.name} (${bot.elo})',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      bot.bio,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(gameSessionProvider.notifier).startNewGame(
                      playerColor: PlayerColor.white,
                      difficulty: AppConstants.difficultyLevels.firstWhere(
                        (d) => d.elo == bot.elo,
                        orElse: () => AppConstants.difficultyLevels[0],
                      ),
                      timeControl: AppConstants.timeControls[0],
                      gameMode: GameMode.bot,
                      botProfile: bot,
                    );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                elevation: 0,
              ),
              child: Text(
                'PLAY VS ${bot.name.toUpperCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Row of two compact buttons: Pass & Play | Analyze Game
  Widget _buildCompactButtonsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewGameSetupScreen(
                    initialMode: GameMode.localMultiplayer,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pass & Play',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      Text(
                        'Same device',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryFor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            onTap: () {
              // Opens Learn -> Review
              ref.read(mainTabProvider.notifier).state = 2; // Learn Tab
              ref.read(learnSegmentProvider.notifier).setSegment(2); // Review segment
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyze Game',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      Text(
                        'Stockfish eval',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryFor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Daily Puzzle Card ABOVE the fold
  Widget _buildDailyPuzzleCard(BuildContext context) {
    final streakState = ref.watch(streakProvider);
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final isDailySolved = streakState.isDailyPuzzleSolvedToday;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Puzzle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    Text(
                      todayFormatted,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge.streak(streakDays: streakState.streakCount),
            ],
          ),
          const SizedBox(height: 12),
          if (isDailySolved)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.emeraldGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Solved Today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.emeraldGreen,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DailyPuzzleScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLevel2(context),
                    foregroundColor: AppTheme.textPrimaryFor(context),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Review puzzle',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DailyPuzzleScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'SOLVE TODAY\'S PUZZLE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Review last game" shortcut (shown only if at least one game exists)
  Widget _buildReviewLastGameShortcut(BuildContext context) {
    final repository = ref.read(gameSessionRepositoryProvider);

    return FutureBuilder<List<GameSession>>(
      future: repository.getCompletedRealGames(limit: 1),
      builder: (context, snapshot) {
        final games = snapshot.data ?? [];
        if (games.isEmpty) return const SizedBox.shrink();

        final lastGame = games.first;
        final opponentName = lastGame.gameMode == GameMode.bot
            ? (lastGame.botProfile?.name ?? 'Bot (${lastGame.difficulty.elo})')
            : 'Friend';
        final moveCount = (lastGame.moveHistory.length / 2).ceil();

        return Column(
          children: [
            AppCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalysisScreen(
                      moves: lastGame.moveHistory,
                      startingFen: lastGame.startingFen,
                      gameId: lastGame.id,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  MiniBoard(
                    fen: lastGame.startingFen,
                    size: 48,
                    borderRadius: AppTheme.radiusSm,
                    showBorder: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Last Game',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          'vs $opponentName',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryFor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Move $moveCount • ${DateFormat('MMM d').format(lastGame.lastMoveTime)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnalysisScreen(
                            moves: lastGame.moveHistory,
                            startingFen: lastGame.startingFen,
                            gameId: lastGame.id,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.royalBlue,
                      textStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Review →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space16),
          ],
        );
      },
    );
  }

  /// Master Campaign Card with fixed level stepper (BUG FIX: 1, 2, 3, 4)
  Widget _buildCampaignCard(BuildContext context) {
    final botState = ref.watch(botProgressProvider);
    final currentLevelNum = botState.campaignUnlockedLevel;
    final currentLevel = CampaignLevel.allLevels[currentLevelNum.clamp(1, 12) - 1];
    final currentBot = BotProfile.allBots.firstWhere(
      (b) => b.id == currentLevel.botId,
      orElse: () => BotProfile.allBots.first,
    );

    // FIX: Sequential 4 levels starting from currentLevelNum (clamped so 4 steps fit 1..12)
    final startLevel = currentLevelNum.clamp(1, 9);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Master Campaign',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BotCampaignScreen(),
                    ),
                  );
                },
                child: Text(
                  'View map →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              BotAvatar(bot: currentBot, size: 48, showElo: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${currentLevel.levelNumber}: ${currentLevel.title}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    Text(
                      'vs ${currentBot.name} (${currentBot.elo})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  BotProfileSheet.show(
                    context,
                    currentBot,
                    campaignLevel: currentLevel.levelNumber,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sequential 4-Step Level Progression Stepper
          Row(
            children: List.generate(4, (i) {
              final stepLevel = startLevel + i;
              final isCurrent = stepLevel == currentLevelNum;
              final stars = botState.campaignStars[stepLevel] ?? 0;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? AppTheme.accentColor
                            : (stars > 0
                                ? AppTheme.emeraldGreen.withValues(alpha: 0.2)
                                : AppTheme.surfaceLevel2(context)),
                        border: Border.all(
                          color: isCurrent
                              ? AppTheme.accentColor
                              : (stars > 0
                                  ? AppTheme.emeraldGreen
                                  : AppTheme.borderStroke(context)),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$stepLevel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? Colors.black87
                              : AppTheme.textPrimaryFor(context),
                        ),
                      ),
                    ),
                    if (i < 3)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: stars > 0
                              ? AppTheme.emeraldGreen
                              : AppTheme.borderStroke(context),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Bot Arena horizontal carousel across rating range
  Widget _buildBotArenaSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Bot Arena',
          subtitle: 'Practice against distinct AI personalities',
          leadingIcon: Icons.smart_toy_rounded,
          actionLabel: 'See all',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BotsHubScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: BotProfile.allBots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final bot = BotProfile.allBots[index];
              return SizedBox(
                width: 165,
                child: BotCard(
                  bot: bot,
                  isFeatured: true,
                  onInspect: () {
                    BotProfileSheet.show(context, bot);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
