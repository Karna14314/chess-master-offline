import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/game_setup/new_game_setup_screen.dart';
import 'package:chess_master/screens/history/game_history_screen.dart';
import 'package:chess_master/core/utils/pgn_handler.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Home screen - main dashboard for the Chess App
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-initialize engine
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockfishServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
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
                    _buildHeader(context),
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
                child: _buildSectionTitle(context, 'Game Modes'),
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
                    onTap: () => _showBotGameSetup(context),
                  ),
                  _buildGameModeCard(
                    context,
                    title: 'Play Friend',
                    subtitle: 'Local Match',
                    icon: Icons.people_outline,
                    color: AppTheme.secondaryColor,
                    onTap: () => _showLocalMultiplayerSetup(context),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Continue Playing Carousel
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _buildContinueSection(context)),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Bottom padding
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Chess Master',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPlayHero(BuildContext context) {
    return GestureDetector(
      onTap: () => _startQuickGame(3), // Defaulting to Level 3 for Quick Play
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF0D0D0D),
            ], // Deep Green to Black
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.videogame_asset,
                  size: 180,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
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
                  const Spacer(),
                  Text(
                    'Quick Play',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jump into a match instantly',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        // Optional: 'See All' button
      ],
    );
  }

  Widget _buildGameModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueSection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(context, 'Continue Game'),
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
                'View All',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: FutureBuilder<List<GameSession>>(
            future: ref
                .read(gameSessionRepositoryProvider)
                .getUnfinishedGames(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyStateCard(context);
              }

              final games = snapshot.data!;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: games.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final game = games[index];
                  return _buildContinueGameCard(context, game);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueGameCard(BuildContext context, GameSession game) {
    final fen = game.fen;
    final opponent =
        game.gameMode == GameMode.bot
            ? game.blackPlayerName.contains('Bot')
                ? game.blackPlayerName
                : game.whitePlayerName
            : 'Friend';
    final moveCount = game.moveHistory.length;
    final isCompleted = game.isCompleted;
    final gameId = game.id;

    return GestureDetector(
      onTap: () => _resumeGameFromSession(context, game),
      onLongPress: () => _showGameOptionsDialog(context, gameId, null),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // Mini Board Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 100,
                child: AbsorbPointer(
                  child: ChessBoard(
                    fen: fen,
                    showCoordinates: false,
                    showHint: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vs $opponent',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Move $moveCount',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCompleted
                              ? Colors.grey.withOpacity(0.2)
                              : AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Resume',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isCompleted ? Colors.grey : AppTheme.primaryColor,
                      ),
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

  Widget _buildEmptyStateCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 16),
          Text(
            'No recent games',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Actions & Logic ==========

  void _showBotGameSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NewGameSetupScreen(initialMode: GameMode.bot),
      ),
    );
  }

  void _showLocalMultiplayerSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => const NewGameSetupScreen(
              initialMode: GameMode.localMultiplayer,
            ),
      ),
    );
  }

  Future<void> _startQuickGame(int level) async {
    setState(() => _isLoading = true);

    try {
      final difficulty = AppConstants.difficultyLevels[level - 1];
      ref
          .read(gameSessionProvider.notifier)
          .startNewGame(
            gameMode: GameMode.bot,
            botType: BotType.simple,
            difficulty: difficulty,
            timeControl: AppConstants.timeControls[0], // No timer
            playerColor: PlayerColor.white,
          );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start quick game: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resumeGameFromSession(
    BuildContext context,
    GameSession session,
  ) async {
    try {
      if (session.isCompleted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameHistoryScreen()),
        );
        return;
      }

      await ref.read(gameSessionProvider.notifier).loadSession(session.id);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading game: $e')));
      }
    }
  }

  Future<void> _resumeGame(
    BuildContext context,
    Map<String, dynamic> gameData,
  ) async {
    try {
      final isCompleted =
          (gameData['is_completed'] as int?) == 1 || gameData['result'] != null;

      if (isCompleted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameHistoryScreen()),
        );
        return;
      }

      final gameId = gameData['id'] as String;
      await ref.read(gameSessionProvider.notifier).loadSession(gameId);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading game: $e')));
      }
    }
  }

  /// Show game options dialog (rename, delete, etc.)
  Future<void> _showGameOptionsDialog(
    BuildContext context,
    String gameId,
    String? currentName,
  ) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text(
              'Game Options',
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: AppTheme.primaryColor),
                  title: Text(
                    'Rename Game',
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameDialog(context, gameId, currentName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Delete Game',
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            backgroundColor: AppTheme.surfaceDark,
                            title: Text(
                              'Delete Game?',
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            content: Text(
                              'This action cannot be undone.',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true && context.mounted) {
                      await ref
                          .read(databaseServiceProvider)
                          .deleteGame(gameId);
                      setState(() {}); // Refresh the list
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// Show rename dialog
  Future<void> _showRenameDialog(
    BuildContext context,
    String gameId,
    String? currentName,
  ) async {
    final controller = TextEditingController(text: currentName ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text(
              'Rename Game',
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter game name',
                hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  await ref
                      .read(databaseServiceProvider)
                      .updateGameName(gameId, name);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Refresh the list
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
