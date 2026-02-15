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

/// Home screen - main tab for starting games
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 32),

              // Play with Bot Section
              _buildSectionTitle(context, '🤖 Play with Bot'),
              const SizedBox(height: 16),
              _buildBotOptionsCard(context),
              const SizedBox(height: 24),

              // Play with Friend Section
              _buildSectionTitle(context, '👥 Play with Friend'),
              const SizedBox(height: 16),
              _buildFriendModeCard(context),
              const SizedBox(height: 24),

              // Continue / Load Game Section
              _buildSectionTitle(context, '📂 Continue Game'),
              const SizedBox(height: 16),
              _buildLoadGameCard(context),
              const SizedBox(height: 32),

              // Quick Start
              _buildQuickStartSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '♔',
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Play Chess',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Choose your game mode',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildBotOptionsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceDark),
      ),
      child: Column(
        children: [
          // Standard Game - Level Selection
          _buildOptionTile(
            context,
            icon: Icons.trending_up,
            title: 'Standard Game',
            subtitle: 'Play through levels 1-10',
            color: Colors.green,
            onTap: () => _showLevelSelectionSheet(context),
          ),
          const Divider(height: 1, color: AppTheme.surfaceDark),
          // Custom ELO
          _buildOptionTile(
            context,
            icon: Icons.tune,
            title: 'Choose ELO',
            subtitle: 'Custom difficulty (800-2800)',
            color: Colors.orange,
            onTap: () => _showCustomEloDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendModeCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceDark),
      ),
      child: _buildOptionTile(
        context,
        icon: Icons.people,
        title: 'Local Multiplayer',
        subtitle: '2 players on same device',
        color: Colors.blue,
        onTap: () => _showLocalMultiplayerSetup(context),
      ),
    );
  }

  Widget _buildLoadGameCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceDark),
      ),
      child: Column(
        children: [
          // Resume Last Game
          _buildOptionTile(
            context,
            icon: Icons.play_circle_outline,
            title: 'Resume Last Game',
            subtitle: 'Continue where you left off',
            color: Colors.purple,
            onTap: () => _continueLastGame(context),
          ),
          const Divider(height: 1, color: AppTheme.surfaceDark),
          // Saved Games
          _buildOptionTile(
            context,
            icon: Icons.folder_outlined,
            title: 'Saved Games',
            subtitle: 'Load from game history',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GameHistoryScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, color: AppTheme.surfaceDark),
          // Load from PGN
          _buildOptionTile(
            context,
            icon: Icons.upload_file,
            title: 'Load from PGN',
            subtitle: 'Import game or position',
            color: Colors.amber,
            onTap: () => _showLoadPGNDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStartSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryLight.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Start',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickStartButton(
                  label: 'Easy',
                  sublabel: 'Level 3',
                  color: Colors.green,
                  onTap: () => _startQuickGame(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickStartButton(
                  label: 'Medium',
                  sublabel: 'Level 5',
                  color: Colors.orange,
                  onTap: () => _startQuickGame(5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickStartButton(
                  label: 'Hard',
                  sublabel: 'Level 7',
                  color: Colors.red,
                  onTap: () => _startQuickGame(7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== Actions ==========

  void _showLevelSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _LevelSelectionSheet(
            onLevelSelected: (level) {
              Navigator.pop(context);
              _showGameSetupSheet(context, level);
            },
          ),
    );
  }

  void _showGameSetupSheet(BuildContext context, int level) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _GameSetupSheet(
            difficultyLevel: level,
            onStartGame: (playerColor, timeControl) async {
              Navigator.pop(context);
              await _startBotGame(level, playerColor, timeControl);
            },
          ),
    );
  }

  void _showCustomEloDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _CustomEloSheet(
            onStartGame: (elo, playerColor, timeControl) async {
              Navigator.pop(context);
              // Find closest difficulty level
              final level =
                  AppConstants.difficultyLevels
                      .indexWhere((d) => d.elo >= elo)
                      .clamp(0, 9) +
                  1;
              await _startBotGame(level, playerColor, timeControl);
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

  void _showLoadPGNDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _LoadPGNSheet(
            onLoad: (pgn) {
              Navigator.pop(context);
              final gameState = PGNHandler.parsePgn(pgn);
              if (gameState != null) {
                ref.read(gameProvider.notifier).state = gameState;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Invalid PGN!')));
              }
            },
          ),
    );
  }

  Future<void> _startQuickGame(int level) async {
    final difficulty = AppConstants.difficultyLevels[level - 1];
    await _startBotGame(level, PlayerColor.white, AppConstants.timeControls[0]);
  }

  Future<void> _startBotGame(
    int level,
    PlayerColor playerColor,
    TimeControl timeControl,
  ) async {
    setState(() => _isLoading = true);

    try {
      final difficulty = AppConstants.difficultyLevels[level - 1];

      // Initialize engine with timeout to prevent hanging
      final engineNotifier = ref.read(engineProvider.notifier);
      try {
        await engineNotifier.initialize().timeout(const Duration(seconds: 5));
      } catch (e) {
        // Engine initialization failed - show warning but don't start bot game
        debugPrint('Engine init warning: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Engine initialization failed. You can still play local multiplayer games.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return; // Don't start bot game if engine failed
      }
      engineNotifier.resetForNewGame();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
    // Start local multiplayer game (no engine needed)

    // Update auto flip setting
    final settings = ref.read(settingsProvider);
    if (settings.autoFlipBoard != autoFlip) {
      ref.read(settingsProvider.notifier).toggleAutoFlipBoard();
    }

    ref
        .read(gameProvider.notifier)
        .startNewGame(
          playerColor:
              PlayerColor.white, // In local mode, both players use same device
          difficulty:
              AppConstants.difficultyLevels[4], // Not used in local mode
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

  Future<void> _continueLastGame(BuildContext context) async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final lastGame = await dbService.getLastUnfinishedGame();

      if (lastGame == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No saved game found')));
        }
        return;
      }

      // Initialize engine
      final engineNotifier = ref.read(engineProvider.notifier);
      await engineNotifier.initialize();
      engineNotifier.resetForNewGame();

      // Load game settings
      final playerColorStr = lastGame['player_color'] as String? ?? 'white';
      final playerColor =
          playerColorStr == 'white' ? PlayerColor.white : PlayerColor.black;

      final botElo = lastGame['bot_elo'] as int? ?? 1200;
      final difficultyIndex = AppConstants.difficultyLevels
          .indexWhere((d) => d.elo == botElo)
          .clamp(0, AppConstants.difficultyLevels.length - 1);
      final difficulty = AppConstants.difficultyLevels[difficultyIndex];

      final timeControlStr = lastGame['time_control'] as String? ?? 'No Timer';
      final timeControlIndex = AppConstants.timeControls
          .indexWhere((tc) => tc.name == timeControlStr)
          .clamp(0, AppConstants.timeControls.length - 1);
      final timeControl = AppConstants.timeControls[timeControlIndex];

      final fenCurrent = lastGame['fen_current'] as String?;

      ref
          .read(gameProvider.notifier)
          .startNewGame(
            playerColor: playerColor,
            difficulty: difficulty,
            timeControl: timeControl,
            startingFen: fenCurrent,
            gameMode: GameMode.bot,
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
}

// ========== Quick Start Button ==========

class _QuickStartButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickStartButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Level Selection Sheet ==========

class _LevelSelectionSheet extends StatelessWidget {
  final Function(int level) onLevelSelected;

  const _LevelSelectionSheet({required this.onLevelSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Level',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your difficulty level',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                // Level grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    final difficulty = AppConstants.difficultyLevels[index];
                    return _LevelButton(
                      level: level,
                      elo: difficulty.elo,
                      onTap: () => onLevelSelected(level),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
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
    final color = _getLevelColor(level);

    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
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
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level <= 3) return Colors.green;
    if (level <= 5) return Colors.orange;
    if (level <= 7) return Colors.deepOrange;
    return Colors.red;
  }
}

// ========== Game Setup Sheet ==========

class _GameSetupSheet extends StatefulWidget {
  final int difficultyLevel;
  final Function(PlayerColor, TimeControl) onStartGame;

  const _GameSetupSheet({
    required this.difficultyLevel,
    required this.onStartGame,
  });

  @override
  State<_GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends State<_GameSetupSheet> {
  PlayerColor _selectedColor = PlayerColor.white;
  int _selectedTimeControlIndex = 0;

  @override
  Widget build(BuildContext context) {
    final difficulty =
        AppConstants.difficultyLevels[widget.difficultyLevel - 1];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${widget.difficultyLevel} - ${difficulty.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${difficulty.elo} ELO',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Color selection
                Text('Play as', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children:
                      PlayerColor.values.map((color) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ColorChip(
                              color: color,
                              isSelected: _selectedColor == color,
                              onTap:
                                  () => setState(() => _selectedColor = color),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),

                // Time control
                Text(
                  'Time Control',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(AppConstants.timeControls.length, (
                    index,
                  ) {
                    final tc = AppConstants.timeControls[index];
                    return ChoiceChip(
                      label: Text(tc.name),
                      selected: _selectedTimeControlIndex == index,
                      onSelected:
                          (_) =>
                              setState(() => _selectedTimeControlIndex = index),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onStartGame(
                        _selectedColor,
                        AppConstants.timeControls[_selectedTimeControlIndex],
                      );
                    },
                    child: const Text('Start Game'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final PlayerColor color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.primaryColor : AppTheme.cardDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                color == PlayerColor.white
                    ? '♔'
                    : color == PlayerColor.black
                    ? '♚'
                    : '🎲',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                color.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Custom ELO Sheet ==========

class _CustomEloSheet extends StatefulWidget {
  final Function(int elo, PlayerColor, TimeControl) onStartGame;

  const _CustomEloSheet({required this.onStartGame});

  @override
  State<_CustomEloSheet> createState() => _CustomEloSheetState();
}

class _CustomEloSheetState extends State<_CustomEloSheet> {
  double _selectedElo = 1200;
  PlayerColor _selectedColor = PlayerColor.white;
  int _selectedTimeControlIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose ELO',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                // ELO Slider
                Text(
                  'Bot Strength: ${_selectedElo.round()} ELO',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _selectedElo,
                  min: 800,
                  max: 2800,
                  divisions: 20,
                  label: '${_selectedElo.round()}',
                  onChanged: (value) => setState(() => _selectedElo = value),
                ),
                const SizedBox(height: 24),

                // Color selection
                Text('Play as', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children:
                      PlayerColor.values.map((color) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ColorChip(
                              color: color,
                              isSelected: _selectedColor == color,
                              onTap:
                                  () => setState(() => _selectedColor = color),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),

                // Time control
                Text(
                  'Time Control',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(AppConstants.timeControls.length, (
                    index,
                  ) {
                    final tc = AppConstants.timeControls[index];
                    return ChoiceChip(
                      label: Text(tc.name),
                      selected: _selectedTimeControlIndex == index,
                      onSelected:
                          (_) =>
                              setState(() => _selectedTimeControlIndex = index),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onStartGame(
                        _selectedElo.round(),
                        _selectedColor,
                        AppConstants.timeControls[_selectedTimeControlIndex],
                      );
                    },
                    child: const Text('Start Game'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ========== Local Multiplayer Sheet ==========

class _LocalMultiplayerSheet extends ConsumerStatefulWidget {
  final Function(TimeControl, bool, bool) onStartGame;

  const _LocalMultiplayerSheet({required this.onStartGame});

  @override
  ConsumerState<_LocalMultiplayerSheet> createState() =>
      _LocalMultiplayerSheetState();
}

class _LocalMultiplayerSheetState
    extends ConsumerState<_LocalMultiplayerSheet> {
  bool _useTimer = false;
  int _selectedTimeControlIndex = 7; // 10+0 default
  bool _allowTakeback = true;
  late bool _autoFlip;

  @override
  void initState() {
    super.initState();
    _autoFlip = ref.read(settingsProvider).autoFlipBoard;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Multiplayer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '2 players on same device',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Timer toggle
                SwitchListTile(
                  title: const Text('Use Timer'),
                  subtitle: const Text('Add time control to the game'),
                  value: _useTimer,
                  onChanged: (value) => setState(() => _useTimer = value),
                  contentPadding: EdgeInsets.zero,
                ),

                if (_useTimer) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      AppConstants.timeControls.length -
                          1, // Exclude "No Timer"
                      (index) {
                        final tc = AppConstants.timeControls[index + 1];
                        return ChoiceChip(
                          label: Text(tc.name),
                          selected: _selectedTimeControlIndex == index + 1,
                          onSelected:
                              (_) => setState(
                                () => _selectedTimeControlIndex = index + 1,
                              ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Takeback toggle
                SwitchListTile(
                  title: const Text('Allow Takeback'),
                  subtitle: const Text('Players can undo moves'),
                  value: _allowTakeback,
                  onChanged: (value) => setState(() => _allowTakeback = value),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Auto Flip toggle
                SwitchListTile(
                  title: const Text('Auto Flip Board'),
                  subtitle: const Text('Flip board after each move'),
                  value: _autoFlip,
                  onChanged: (value) => setState(() => _autoFlip = value),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      final timeControl =
                          _useTimer
                              ? AppConstants
                                  .timeControls[_selectedTimeControlIndex]
                              : AppConstants.timeControls[0]; // No Timer
                      widget.onStartGame(
                        timeControl,
                        _allowTakeback,
                        _autoFlip,
                      );
                    },
                    child: const Text('Start Game'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ========== Load PGN Sheet ==========

class _LoadPGNSheet extends StatefulWidget {
  final Function(String) onLoad;

  const _LoadPGNSheet({required this.onLoad});

  @override
  State<_LoadPGNSheet> createState() => _LoadPGNSheetState();
}

class _LoadPGNSheetState extends State<_LoadPGNSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Load from PGN',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'Paste PGN or FEN here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardDark,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        widget.onLoad(_controller.text);
                      }
                    },
                    child: const Text('Load'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
