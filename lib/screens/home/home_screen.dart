import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/history/game_history_screen.dart';
import 'package:chess_master/core/utils/pgn_handler.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
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
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textPrimary,
            ),
            onPressed: () {
              // Settings navigation handled by main tab controller
              // Or we can push settings screen directly if not using tabs
            },
          ),
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref
                .read(databaseServiceProvider)
                .getRecentGames(limit: 5, includeCompleted: false),
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

  Widget _buildContinueGameCard(
    BuildContext context,
    Map<String, dynamic> game,
  ) {
    final fen =
        game['fen_current'] as String? ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    final opponent =
        game['game_mode'] == 'bot'
            ? 'Bot (${game['bot_elo'] ?? 1200})'
            : 'Friend';
    final moveCount = game['move_count'] ?? 0;
    final isCompleted = (game['is_completed'] as int?) == 1;
    final customName = game['custom_name'] as String?;
    final gameId = game['id'] as String;

    return GestureDetector(
      onTap: () => _resumeGame(context, game),
      onLongPress: () => _showGameOptionsDialog(context, gameId, customName),
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
                  if (customName != null && customName.isNotEmpty) ...[
                    Text(
                      customName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    'Vs $opponent',
                    style: GoogleFonts.inter(
                      fontSize:
                          customName != null && customName.isNotEmpty ? 14 : 16,
                      fontWeight:
                          customName != null && customName.isNotEmpty
                              ? FontWeight.normal
                              : FontWeight.bold,
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
    // First, show bot type selection
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _BotTypeSelectionSheet(
            onBotTypeSelected: (botType) {
              Navigator.pop(context);
              _showLevelSelection(context, botType);
            },
          ),
    );
  }

  void _showLevelSelection(BuildContext context, BotType botType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _LevelSelectionSheet(
            botType: botType,
            onLevelSelected: (level) {
              Navigator.pop(context);
              _showGameSetupSheet(context, level, botType);
            },
          ),
    );
  }

  void _showGameSetupSheet(BuildContext context, int level, BotType botType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _GameSetupSheet(
            difficultyLevel: level,
            botType: botType,
            onStartGame: (playerColor, timeControl) async {
              Navigator.pop(context);
              await _startBotGame(level, playerColor, timeControl, botType);
            },
          ),
    );
  }

  void _showLocalMultiplayerSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _LocalMultiplayerSheet(
            onStartGame: (timeControl, allowTakeback, autoFlip) async {
              Navigator.pop(context);
              await _startLocalGame(timeControl, allowTakeback, autoFlip);
            },
          ),
    );
  }

  Future<void> _startQuickGame(int level) async {
    final difficulty = AppConstants.difficultyLevels[level - 1];
    await _startBotGame(
      level,
      PlayerColor.white,
      AppConstants.timeControls[0],
      BotType.simple,
    );
  }

  Future<void> _startBotGame(
    int level,
    PlayerColor playerColor,
    TimeControl timeControl,
    BotType botType,
  ) async {
    setState(() => _isLoading = true);

    try {
      final difficulty = AppConstants.difficultyLevels[level - 1];

      // Only initialize engine if using Stockfish
      if (botType == BotType.stockfish) {
        final engineNotifier = ref.read(engineProvider.notifier);
        try {
          await engineNotifier.initialize().timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('Engine init warning: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Stockfish unavailable. Switching to Simple Bot.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            // Fall back to Simple Bot
            botType = BotType.simple;
          }
        }
        engineNotifier.resetForNewGame();
      }

      // Resolve random color
      PlayerColor actualColor = playerColor;
      if (playerColor == PlayerColor.random) {
        actualColor =
            DateTime.now().millisecond % 2 == 0
                ? PlayerColor.white
                : PlayerColor.black;
      }

      // Start game
      ref
          .read(gameProvider.notifier)
          .startNewGame(
            playerColor: actualColor,
            difficulty: difficulty,
            timeControl: timeControl,
            gameMode: GameMode.bot,
            botType: botType,
            useTimer: timeControl.hasTimer,
          );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start game: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startLocalGame(
    TimeControl timeControl,
    bool allowTakeback,
    bool autoFlip,
  ) async {
    final settings = ref.read(settingsProvider);
    if (settings.autoFlipBoard != autoFlip) {
      ref.read(settingsProvider.notifier).toggleAutoFlipBoard();
    }

    ref
        .read(gameProvider.notifier)
        .startNewGame(
          playerColor: PlayerColor.white,
          difficulty: AppConstants.difficultyLevels[4],
          timeControl: timeControl,
          gameMode: GameMode.localMultiplayer,
          allowTakeback: allowTakeback,
          useTimer: timeControl.hasTimer,
        );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  Future<void> _resumeGame(
    BuildContext context,
    Map<String, dynamic> game,
  ) async {
    try {
      final isCompleted = (game['is_completed'] as int?) == 1;

      // If completed, maybe just navigate to review or history
      // But for now, let's load it as a game (maybe in analysis mode?)
      // For simplicity, we restart it or handle it as resume.
      // If it's completed, we probably shouldn't "resume" it in gameplay sense.
      // But let's assume the user wants to see the position.

      if (isCompleted) {
        // Navigate to history/analysis
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GameHistoryScreen()),
        );
        return;
      }

      // Initialize engine
      final engineNotifier = ref.read(engineProvider.notifier);
      await engineNotifier.initialize();
      engineNotifier.resetForNewGame();

      // Load game settings
      final playerColorStr = game['player_color'] as String? ?? 'white';
      final playerColor =
          playerColorStr == 'white' ? PlayerColor.white : PlayerColor.black;
      final botElo = game['bot_elo'] as int? ?? 1200;
      final difficultyIndex = AppConstants.difficultyLevels
          .indexWhere((d) => d.elo == botElo)
          .clamp(0, 9);
      final difficulty = AppConstants.difficultyLevels[difficultyIndex];
      final timeControlStr = game['time_control'] as String? ?? 'No Timer';
      final timeControlIndex = AppConstants.timeControls
          .indexWhere((tc) => tc.name == timeControlStr)
          .clamp(0, AppConstants.timeControls.length - 1);
      final timeControl = AppConstants.timeControls[timeControlIndex];
      final fenCurrent = game['fen_current'] as String?;

      // Read game_mode from database and convert to GameMode enum
      final gameModeStr = game['game_mode'] as String? ?? 'bot';
      final gameMode =
          gameModeStr == 'local' ? GameMode.localMultiplayer : GameMode.bot;

      ref
          .read(gameProvider.notifier)
          .startNewGame(
            playerColor: playerColor,
            difficulty: difficulty,
            timeControl: timeControl,
            startingFen: fenCurrent,
            gameMode: gameMode,
          );

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

// Helpers/Bottom Sheets... (Including the existing ones like _LevelSelectionSheet, etc.)
// Since I'm replacing the whole file, I need to include the sheet classes.

class _LevelSelectionSheet extends StatelessWidget {
  final BotType botType;
  final Function(int level) onLevelSelected;

  const _LevelSelectionSheet({
    required this.botType,
    required this.onLevelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Select Difficulty',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            botType == BotType.simple
                                ? AppTheme.primaryColor.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        botType.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              botType == BotType.simple
                                  ? AppTheme.primaryColor
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    return _LevelButton(
                      level: level,
                      elo: AppConstants.difficultyLevels[index].elo,
                      onTap: () => onLevelSelected(level),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final int level;
  final int elo;
  final VoidCallback onTap;

  const _LevelButton({
    required this.level,
    required this.elo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // simplified color logic
    Color color = AppTheme.primaryColor;
    if (level > 3) color = Colors.orange;
    if (level > 7) color = Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$level',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$elo',
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameSetupSheet extends StatefulWidget {
  final int difficultyLevel;
  final BotType botType;
  final Function(PlayerColor, TimeControl) onStartGame;

  const _GameSetupSheet({
    required this.difficultyLevel,
    required this.botType,
    required this.onStartGame,
  });

  @override
  State<_GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends State<_GameSetupSheet> {
  PlayerColor _selectedColor = PlayerColor.white;
  TimeControl _selectedTimeControl = AppConstants.timeControls[0];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Game Options',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Play As',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildColorOption(
                PlayerColor.white,
                'White',
                Icons.circle_outlined,
              ),
              const SizedBox(width: 12),
              _buildColorOption(PlayerColor.random, 'Random', Icons.shuffle),
              const SizedBox(width: 12),
              _buildColorOption(PlayerColor.black, 'Black', Icons.circle),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Time Control',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  AppConstants.timeControls.map((tc) {
                    final isSelected = _selectedTimeControl == tc;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(tc.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedTimeControl = tc);
                        },
                        backgroundColor: AppTheme.cardDark,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () =>
                      widget.onStartGame(_selectedColor, _selectedTimeControl),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start Game'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(PlayerColor color, String label, IconData icon) {
    final isSelected = _selectedColor == color;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedColor = color),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : AppTheme.cardDark,
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalMultiplayerSheet extends StatefulWidget {
  final Function(TimeControl, bool, bool) onStartGame;

  const _LocalMultiplayerSheet({required this.onStartGame});

  @override
  State<_LocalMultiplayerSheet> createState() => _LocalMultiplayerSheetState();
}

class _LocalMultiplayerSheetState extends State<_LocalMultiplayerSheet> {
  TimeControl _selectedTimeControl = AppConstants.timeControls[0];
  bool _allowTakeback = false;
  bool _autoFlip = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Local Multiplayer',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow Takeback'),
            value: _allowTakeback,
            onChanged: (val) => setState(() => _allowTakeback = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Flip Board'),
            value: _autoFlip,
            onChanged: (val) => setState(() => _autoFlip = val),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () => widget.onStartGame(
                    _selectedTimeControl,
                    _allowTakeback,
                    _autoFlip,
                  ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start Game'),
            ),
          ),
        ],
      ),
    );
  }
}

// Bot Type Selection Sheet
class _BotTypeSelectionSheet extends StatelessWidget {
  final Function(BotType) onBotTypeSelected;

  const _BotTypeSelectionSheet({required this.onBotTypeSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Bot Type',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildBotTypeCard(
                  context,
                  botType: BotType.simple,
                  icon: Icons.psychology_outlined,
                  color: AppTheme.primaryColor,
                  onTap: () => onBotTypeSelected(BotType.simple),
                ),
                const SizedBox(height: 16),
                _buildBotTypeCard(
                  context,
                  botType: BotType.stockfish,
                  icon: Icons.rocket_launch_outlined,
                  color: Colors.red,
                  onTap: () => onBotTypeSelected(BotType.stockfish),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotTypeCard(
    BuildContext context, {
    required BotType botType,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    botType.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    botType.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
