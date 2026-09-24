import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/screens/bots/bot_profile_sheet.dart';
import 'package:chess_master/screens/bots/bot_campaign_screen.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/bot_card.dart';

/// Screen allowing players to browse all 20+ bots across 4 tiers
class BotsHubScreen extends ConsumerStatefulWidget {
  const BotsHubScreen({super.key});

  @override
  ConsumerState<BotsHubScreen> createState() => _BotsHubScreenState();
}

class _BotsHubScreenState extends ConsumerState<BotsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startBotMatch(BotProfile bot) async {
    final viewModel = ref.read(gameSessionProvider.notifier);
    await viewModel.startNewGame(
      gameMode: GameMode.bot,
      difficulty: bot.difficultyLevel,
      timeControl: AppConstants.timeControls[0],
      playerColor: PlayerColor.white,
      botType: bot.engineType,
      botProfile: bot,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final botState = ref.watch(botProgressProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLevel0(context),
      appBar: AppBar(
        title: Text(
          'Bot Arena',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${botState.totalBotStars} Stars',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber[800] ?? Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 12-Level Campaign Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BotCampaignScreen(),
                  ),
                );
              },
              gradient: const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.military_tech_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '12-Level Master Campaign',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level ${botState.campaignUnlockedLevel}/12 Unlocked • Earn Badges',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: textSecondary,
            tabs: const [
              Tab(text: 'All (20+)'),
              Tab(text: 'Beginner (400-950)'),
              Tab(text: 'Intermediate (1050-1450)'),
              Tab(text: 'Advanced (1550-2150)'),
              Tab(text: 'Master (2300+)'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBotList(BotProfile.allBots),
                _buildBotList(BotProfile.getByTier(BotTier.beginner)),
                _buildBotList(BotProfile.getByTier(BotTier.intermediate)),
                _buildBotList(BotProfile.getByTier(BotTier.advanced)),
                _buildBotList(BotProfile.getByTier(BotTier.master)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotList(List<BotProfile> bots) {
    final botState = ref.watch(botProgressProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bots.length,
      itemBuilder: (context, index) {
        final bot = bots[index];
        final stats = botState.getStatsFor(bot.id);
        final recordText = stats.totalGames > 0
            ? 'Record: ${stats.wins}W / ${stats.draws}D / ${stats.losses}L'
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BotCard(
            bot: bot,
            stars: stats.bestStars,
            recordText: recordText,
            onInspect: () => BotProfileSheet.show(context, bot),
            onPlay: () => _startBotMatch(bot),
          ),
        );
      },
    );
  }
}
