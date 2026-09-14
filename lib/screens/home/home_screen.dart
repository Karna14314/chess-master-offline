import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/providers/journey_provider.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/bots/bots_hub_screen.dart';
import 'package:chess_master/screens/bots/bot_profile_sheet.dart';
import 'package:chess_master/screens/bots/bot_campaign_screen.dart';
import 'package:chess_master/screens/puzzles/daily_puzzle_screen.dart';
import 'package:chess_master/screens/analysis/analysis_menu_screen.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';
import 'package:chess_master/screens/history/game_history_screen.dart';
import 'package:chess_master/models/campaign_model.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/app_badge.dart';
import 'package:chess_master/widgets/shared/app_section_header.dart';
import 'package:chess_master/widgets/shared/bot_avatar.dart';
import 'package:chess_master/widgets/shared/bot_card.dart';
import 'package:chess_master/widgets/shared/mini_board.dart';

/// Redesigned Play Home Screen centered on user intent:
/// 1. Header (Greeting, Streak, Stars, Settings)
/// 2. Active Match Resume (Large preview with MiniBoard)
/// 3. Primary Play Action (Fast-start Play Bot <= 2 taps + Pass & Play)
/// 4. Featured Bots (Curated opponents with 1-tap PLAY)
/// 5. Campaign Preview (Vertical progression preview)
/// 6. Recent Games (Visual game thumbnails)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockfishServiceProvider).initialize();
      ref.read(streakProvider.notifier).loadStreak();
      ref.read(journeyProvider.notifier).loadJourneyState();
      ref.read(botProgressProvider.notifier).loadProgress();
    });
  }

  void _startBotMatch(BotProfile bot) {
    final viewModel = ref.read(gameSessionProvider.notifier);
    viewModel.startNewGame(
      gameMode: GameMode.bot,
      botType: bot.engineType,
      difficulty: bot.difficultyLevel,
      timeControl: AppConstants.timeControls[0], // Untimed
      playerColor: PlayerColor.white,
      botProfile: bot,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  void _startLocalGame(TimeControl timeControl) {
    final viewModel = ref.read(gameSessionProvider.notifier);
    viewModel.startNewGame(
      gameMode: GameMode.localMultiplayer,
      difficulty: AppConstants.difficultyLevels[4],
      timeControl: timeControl,
      playerColor: PlayerColor.white,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  void _showFastBotSelector(BuildContext context) {
    final bots = [
      BotProfile.getById('bot_pete'), // 500
      BotProfile.getById('bot_clara'), // 750
      BotProfile.getById('bot_viktor'), // 1300
      BotProfile.getById('bot_sophia'), // 2050
      BotProfile.getById('bot_leon'), // 2500
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceLevel1(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (sheetContext) {
        final textPrimary = AppTheme.textPrimaryFor(sheetContext);
        final textSecondary = AppTheme.textSecondaryFor(sheetContext);

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose Opponent',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BotsHubScreen()),
                          );
                        },
                        child: Text(
                          'All 20+ Bots',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: bots.length,
                    itemBuilder: (context, index) {
                      final bot = bots[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BotCard(
                          bot: bot,
                          onPlay: () {
                            Navigator.pop(sheetContext);
                            _startBotMatch(bot);
                          },
                          onInspect: () {
                            Navigator.pop(sheetContext);
                            BotProfileSheet.show(context, bot);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final gameSession = ref.watch(gameSessionProvider);
    final hasActiveGame =
        gameSession != null &&
        !gameSession.isCompleted &&
        gameSession.moveHistory.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
            // 1. Header (Greeting, Streak, Stars, Settings)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _buildHeader(context, textPrimary, textSecondary),
              ),
            ),

            // 2. Active Match Resume (if game in progress)
            if (hasActiveGame) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _buildActiveMatchCard(context, gameSession),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // 3. Primary Play Actions (Play Bot & Pass and Play)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildPlaySection(context),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 4. Featured Bots ("Bot Arena")
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildFeaturedBotsSection(context),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 5. Campaign Vertical Progression Preview
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildCampaignPreview(context),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 6. Quick Play & Analysis
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildQuickToolsSection(context),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 7. Recent Games
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildRecentGamesSection(context),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildHeader(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
  ) {
    final streakState = ref.watch(streakProvider);
    final botState = ref.watch(botProgressProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isActivityToday = streakState.lastActivityDate == todayStr;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ChessMaster',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Offline Tournament & Engine',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Streak Pill
            AppBadge.streak(
              streakDays: streakState.streakCount,
              isActiveToday: isActivityToday,
            ),
            const SizedBox(width: 8),

            // Crown / Stars Pill
            AppBadge.stars(stars: botState.totalBotStars),
            const SizedBox(width: 4),

            // Settings button
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: textPrimary,
                size: 22,
              ),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveMatchCard(BuildContext context, GameSession session) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final isBot = session.gameMode == GameMode.bot;
    final opponentName = isBot
        ? (session.botProfile?.name ?? 'Bot')
        : 'Friend';
    final moveCount = (session.moveHistory.length / 2).ceil();

    return PremiumCard(
      onTap: () {
        ref.read(gameSessionProvider.notifier).resumeSession(session);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12, vertical: AppTheme.space10),
      borderRadius: AppTheme.radiusLg,
      borderColor: AppTheme.amberGold.withValues(alpha: 0.5),
      child: Row(
        children: [
          // Mini Board Position Preview
          MiniBoard(
            fen: session.startingFen,
            size: 60,
            isFlipped: session.isFlipped,
            borderRadius: AppTheme.radiusSm,
          ),
          const SizedBox(width: AppTheme.space12),

          // Active Match Meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.emeraldGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'MATCH IN PROGRESS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emeraldGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'vs $opponentName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Move $moveCount • ${session.timeControl.displayString}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space8),

          // Resume CTA
          ElevatedButton(
            onPressed: () {
              ref.read(gameSessionProvider.notifier).resumeSession(session);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GameScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amberGold,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 16),
                const SizedBox(width: 2),
                Text(
                  'RESUME',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaySection(BuildContext context) {
    return Column(
      children: [
        // Large Primary PLAY BOT action
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: () => _showFastBotSelector(context),
            icon: const Icon(Icons.smart_toy_rounded, size: 26),
            label: Text(
              'PLAY BOT',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              elevation: 2,
              shadowColor: AppTheme.emeraldGreen.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space12),

        // Secondary Pass & Play and Timer options
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _startLocalGame(AppConstants.timeControls[0]),
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: Text(
                  'Pass & Play',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.borderStroke(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BotsHubScreen()),
                  );
                },
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: Text(
                  'All Opponents',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.borderStroke(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedBotsSection(BuildContext context) {
    final featuredBots = [
      BotProfile.getById('bot_aaron'),  // 850 Mid-800 Attacking
      BotProfile.getById('bot_timmy'),  // 950 Tactical Tricks
      BotProfile.getById('bot_maya'),   // 1050 Solid Fundamentals
      BotProfile.getById('bot_viktor'), // 1150 Gambiteer
      BotProfile.getById('bot_elena'),  // 1250 Positional Strategist
      BotProfile.getById('bot_felix'),  // 1350 Native Calculation
      BotProfile.getById('bot_marcus'), // 1550 The Wall Fortress
      BotProfile.getById('bot_sophia'), // 1700 Club Champion
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Bot Arena',
          subtitle: 'Featured opponents from 850 to 1700 ELO',
          leadingIcon: Icons.smart_toy_rounded,
          actionLabel: 'View All',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BotsHubScreen()),
            );
          },
        ),
        const SizedBox(height: AppTheme.space12),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: featuredBots.length,
            itemBuilder: (context, index) {
              final bot = featuredBots[index];
              return BotCard(
                bot: bot,
                isFeatured: true,
                onPlay: () => _startBotMatch(bot),
                onInspect: () => BotProfileSheet.show(context, bot),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignPreview(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final botState = ref.watch(botProgressProvider);
    final currentLevelNum = botState.campaignUnlockedLevel;
    final currentLevel = CampaignLevel.allLevels[currentLevelNum.clamp(1, 12) - 1];
    final currentBot = currentLevel.bot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Master Campaign',
          subtitle: '12-Level Ladder • Level $currentLevelNum of 12',
          leadingIcon: Icons.military_tech_rounded,
          actionLabel: 'View Map',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BotCampaignScreen()),
            );
          },
        ),
        const SizedBox(height: AppTheme.space12),
        PremiumCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BotCampaignScreen()),
            );
          },
          padding: const EdgeInsets.all(AppTheme.space16),
          borderRadius: AppTheme.radiusLg,
          child: Column(
            children: [
              Row(
                children: [
                  BotAvatar(
                    bot: currentBot,
                    size: 52,
                    showElo: false,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT CHALLENGE: LEVEL $currentLevelNum',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.amberGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentLevel.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'vs ${currentBot.name} (${currentBot.elo} ELO)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: textSecondary,
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
                      backgroundColor: AppTheme.amberGold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'CONTINUE',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space16),

              // Level Step Progression Nodes (Preview 4 steps)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (i) {
                  final stepLevel = (currentLevelNum - 1 + i).clamp(1, 12);
                  final isUnlocked = botState.isCampaignLevelUnlocked(stepLevel);
                  final isCurrent = stepLevel == currentLevelNum;
                  final stars = botState.campaignStars[stepLevel] ?? 0;

                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? AppTheme.amberGold
                                : (stars > 0
                                    ? AppTheme.emeraldGreen.withValues(alpha: 0.2)
                                    : AppTheme.surfaceLevel2(context)),
                            border: Border.all(
                              color: isCurrent
                                  ? AppTheme.amberGold
                                  : (stars > 0 ? AppTheme.emeraldGreen : AppTheme.borderStroke(context)),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: stars > 0 && !isCurrent
                                ? const Icon(Icons.check_rounded, size: 16, color: AppTheme.emeraldGreen)
                                : Text(
                                    '$stepLevel',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? Colors.black87
                                          : (isUnlocked ? textPrimary : textSecondary),
                                    ),
                                  ),
                          ),
                        ),
                        if (i < 3)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: stars > 0
                                  ? AppTheme.emeraldGreen.withValues(alpha: 0.6)
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
        ),
      ],
    );
  }

  Widget _buildQuickToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Quick Play',
          subtitle: 'Daily challenges & engine review',
          leadingIcon: Icons.flash_on_rounded,
        ),
        const SizedBox(height: AppTheme.space12),
        Row(
          children: [
            Expanded(
              child: PremiumCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DailyPuzzleScreen()),
                  );
                },
                padding: const EdgeInsets.all(AppTheme.space14),
                borderRadius: AppTheme.radiusMd,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.amberGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.extension_rounded, color: AppTheme.amberGold, size: 20),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Puzzle',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryFor(context),
                            ),
                          ),
                          Text(
                            'Daily tactical drill',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: PremiumCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnalysisMenuScreen()),
                  );
                },
                padding: const EdgeInsets.all(AppTheme.space14),
                borderRadius: AppTheme.radiusMd,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.insights_rounded, color: AppTheme.royalBlue, size: 20),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analyze Game',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryFor(context),
                            ),
                          ),
                          Text(
                            'Stockfish evaluation',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentGamesSection(BuildContext context) {
    return FutureBuilder<List<GameSession>>(
      future: ref.read(gameSessionRepositoryProvider).getRealGamesHistory(limit: 5),
      builder: (context, snapshot) {
        final games = snapshot.data ?? [];
        if (games.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: 'Recent Games',
              subtitle: 'Review or resume previous sessions',
              leadingIcon: Icons.history_rounded,
              actionLabel: 'History',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: AppTheme.space12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRecentGameTile(context, game),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentGameTile(BuildContext context, GameSession game) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final opponentName = game.gameMode == GameMode.bot
        ? (game.botProfile?.name ?? 'Bot (${game.difficulty.elo})')
        : 'Friend';
    final isCompleted = game.isCompleted;
    final moveCount = (game.moveHistory.length / 2).ceil();

    final resultText = !isCompleted
        ? 'In Progress'
        : (game.result == GameResult.whiteWins
            ? (game.playerColor == PlayerColor.white ? 'Victory' : 'Defeat')
            : (game.result == GameResult.blackWins
                ? (game.playerColor == PlayerColor.black ? 'Victory' : 'Defeat')
                : 'Draw'));

    final resultColor = !isCompleted
        ? AppTheme.amberGold
        : (resultText == 'Victory'
            ? AppTheme.emeraldGreen
            : (resultText == 'Defeat' ? AppTheme.crimsonRed : AppTheme.royalBlue));

    return PremiumCard(
      onTap: () {
        if (!isCompleted) {
          // Resume game
          ref.read(gameSessionProvider.notifier).resumeSession(game);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GameScreen()),
          );
        } else {
          // Review game
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysisScreen(
                moves: game.moveHistory,
                startingFen: game.startingFen,
                gameId: game.id,
              ),
            ),
          );
        }
      },
      padding: const EdgeInsets.all(AppTheme.space12),
      borderRadius: AppTheme.radiusMd,
      child: Row(
        children: [
          MiniBoard(
            fen: game.startingFen,
            size: 52,
            borderRadius: AppTheme.radiusSm,
            showBorder: false,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'vs $opponentName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        resultText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Move $moveCount • ${DateFormat('MMM d').format(game.lastMoveTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              if (!isCompleted) {
                ref.read(gameSessionProvider.notifier).resumeSession(game);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalysisScreen(
                      moves: game.moveHistory,
                      startingFen: game.startingFen,
                      gameId: game.id,
                    ),
                  ),
                );
              }
            },
            child: Text(
              !isCompleted ? 'Resume' : 'Review',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: !isCompleted ? AppTheme.amberGold : AppTheme.emeraldGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
