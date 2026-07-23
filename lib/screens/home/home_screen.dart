import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/game_setup/new_game_setup_screen.dart';
import 'package:chess_master/screens/history/game_history_screen.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/screens/puzzles/daily_puzzle_screen.dart';
import 'package:chess_master/screens/analysis/analysis_menu_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Home screen - main dynamic dashboard for the Chess App
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-initialize engine & streak data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockfishServiceProvider).initialize();
      ref.read(streakProvider.notifier).loadStreak();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.borderColor : AppTheme.borderLight;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, textPrimary, textSecondary),
                    const SizedBox(height: 20),
                    _buildDailyStreakAndPuzzleHero(context),
                    const SizedBox(height: 24),
                    _buildQuickPlayHero(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Game Modes Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildSectionTitle(context, 'Game Modes', textPrimary),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  _buildGameModeCard(
                    context,
                    title: 'Play Bot',
                    subtitle: 'Challenge AI',
                    icon: Icons.smart_toy_outlined,
                    color: AppTheme.primaryColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => _showBotGameSetup(context),
                  ),
                  _buildGameModeCard(
                    context,
                    title: 'Daily Puzzle',
                    subtitle: 'Tactics Challenge',
                    icon: Icons.extension_outlined,
                    color: Colors.amber,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyPuzzleScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGameModeCard(
                    context,
                    title: 'Play Friend',
                    subtitle: 'Pass & Play',
                    icon: Icons.people_outline,
                    color: AppTheme.secondaryColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => _showLocalMultiplayerSetup(context),
                  ),
                  _buildGameModeCard(
                    context,
                    title: 'Analyze Game',
                    subtitle: 'PGN & Board Analysis',
                    icon: Icons.analytics_outlined,
                    color: Colors.purple,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalysisMenuScreen(),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Continue Playing Carousel
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildContinueSection(context, cardColor, borderColor, textPrimary, textSecondary),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Bottom padding
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color textPrimary, Color textSecondary) {
    final streakState = ref.watch(streakProvider);
    final streakCount = streakState.streakCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chess Master',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
        // Streak Badge Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '$streakCount Day${streakCount == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyStreakAndPuzzleHero(BuildContext context) {
    final streakState = ref.watch(streakProvider);
    final isSolved = streakState.isPuzzleSolvedToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSolved
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFFE65100), const Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isSolved ? Colors.green : Colors.orange).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSolved ? 'DAILY PUZZLE COMPLETED ✅' : 'TODAY\'S DAILY PUZZLE 🧩',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (streakState.streakCount > 0)
                Text(
                  '🔥 ${streakState.streakCount} Day Streak',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isSolved
                ? 'Great job! You\'ve solved today\'s puzzle.'
                : 'Keep your streak alive!',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSolved
                ? 'Come back tomorrow for a new tactic challenge.'
                : 'Solve today\'s tactic challenge to maintain your streak.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyPuzzleScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isSolved ? Colors.green.shade900 : Colors.orange.shade900,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: Icon(
                isSolved ? Icons.replay_rounded : Icons.play_arrow_rounded,
                size: 20,
              ),
              label: Text(
                isSolved ? 'Review Today\'s Puzzle' : 'Solve Daily Puzzle Now',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPlayHero(BuildContext context) {
    return GestureDetector(
      onTap: () => _startQuickGame(3),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF0D0D0D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.15,
                child: Icon(
                  Icons.videogame_asset,
                  size: 130,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'RECOMMENDED',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLight,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quick Play vs AI',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jump into an instant match against Stockfish',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color textPrimary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueSection(
    BuildContext context,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return FutureBuilder<List<GameSession>>(
      future: GameSessionRepository(DatabaseService.instance).getUnfinishedGames(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final activeSessions = snapshot.data ?? [];
        if (activeSessions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(context, 'Continue Playing', textPrimary),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameHistoryScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: activeSessions.length,
                itemBuilder: (context, index) {
                  final session = activeSessions[index];
                  return _buildContinueGameCard(
                    context,
                    session,
                    cardColor,
                    borderColor,
                    textPrimary,
                    textSecondary,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContinueGameCard(
    BuildContext context,
    GameSession session,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isBot = session.gameMode == GameMode.bot;
    final title = isBot ? 'vs AI Match' : 'Pass & Play';
    final moveCount = session.moveHistory.length;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _resumeGameSession(context, session),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBot ? Icons.smart_toy_outlined : Icons.people_outline,
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
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$moveCount moves',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _resumeGameSession(context, session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Resume',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startQuickGame(int difficultyLevel) async {
    final viewModel = ref.read(gameSessionProvider.notifier);
    viewModel.startNewGame(
      gameMode: GameMode.bot,
      difficulty: AppConstants.difficultyLevels[difficultyLevel - 1],
      timeControl: AppConstants.timeControls[0], // Untimed
      playerColor: PlayerColor.white,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  void _resumeGameSession(BuildContext context, GameSession session) async {
    final viewModel = ref.read(gameSessionProvider.notifier);
    await viewModel.loadSession(session.id);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  void _showBotGameSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewGameSetupScreen(initialMode: GameMode.bot),
      ),
    );
  }

  void _showLocalMultiplayerSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewGameSetupScreen(initialMode: GameMode.localMultiplayer),
      ),
    );
  }
}
