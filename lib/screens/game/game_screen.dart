import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/game/widgets/move_list.dart';
import 'package:chess_master/screens/game/widgets/timer_widget.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';

/// Main game screen for playing chess
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _isBotThinking = false;
  bool _dialogShown = false;
  int _lastMoveCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTimer();
      _checkBotMove();
    });
  }

  @override
  void dispose() {
    // Auto-save game when leaving
    _autoSaveGame();
    super.dispose();
  }

  /// Initialize the timer with current game's time control
  void _initializeTimer() {
    final gameState = ref.read(gameProvider);
    final timerNotifier = ref.read(timerProvider.notifier);
    
    timerNotifier.initialize(gameState.timeControl);
    timerNotifier.setTurn(gameState.isWhiteTurn);
    
    if (gameState.timeControl.hasTimer && gameState.status == GameStatus.active) {
      timerNotifier.start();
    }
  }

  /// Auto-save the current game
  Future<void> _autoSaveGame() async {
    try {
      final gameState = ref.read(gameProvider);
      final timerState = ref.read(timerProvider);
      
      if (gameState.moveHistory.isEmpty) return;
      
      final dbService = ref.read(databaseServiceProvider);
      await dbService.saveGame({
        'id': gameState.id,
        'pgn': _generatePGN(gameState),
        'fen_current': gameState.fen,
        'result': gameState.result?.pgn,
        'result_reason': gameState.resultReason,
        'player_color': gameState.playerColor == PlayerColor.white ? 'white' : 'black',
        'bot_elo': gameState.difficulty.elo,
        'time_control': gameState.timeControl.name,
        'white_time_remaining': timerState.whiteTime.inMilliseconds,
        'black_time_remaining': timerState.blackTime.inMilliseconds,
        'created_at': gameState.startedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'move_count': gameState.moveHistory.length,
        'is_completed': gameState.status == GameStatus.finished ? 1 : 0,
        'hints_used': gameState.hintsUsed,
      });
    } catch (e) {
      debugPrint('Error auto-saving game: $e');
    }
  }

  /// Generate PGN from game state
  String _generatePGN(GameState gameState) {
    final buffer = StringBuffer();
    buffer.writeln('[Event "ChessMaster Offline"]');
    buffer.writeln('[Date "${DateTime.now().toIso8601String().split('T')[0]}"]');
    buffer.writeln('[White "${gameState.playerColor == PlayerColor.white ? 'Player' : 'Bot (${gameState.difficulty.elo})'}"]');
    buffer.writeln('[Black "${gameState.playerColor == PlayerColor.black ? 'Player' : 'Bot (${gameState.difficulty.elo})'}"]');
    buffer.writeln('[Result "${gameState.result?.pgn ?? '*'}"]');
    buffer.writeln();
    
    for (int i = 0; i < gameState.moveHistory.length; i++) {
      if (i % 2 == 0) {
        buffer.write('${(i ~/ 2) + 1}. ');
      }
      buffer.write('${gameState.moveHistory[i].san} ');
    }
    
    if (gameState.result != null) {
      buffer.write(gameState.result!.pgn);
    }
    
    return buffer.toString();
  }


  /// Check if it's bot's turn and trigger bot move
  Future<void> _checkBotMove() async {
    final gameState = ref.read(gameProvider);
    
    if (gameState.status != GameStatus.active) return;
    if (gameState.isPlayerTurn) return;
    if (_isBotThinking) return;

    setState(() => _isBotThinking = true);

    try {
      final engineNotifier = ref.read(engineProvider.notifier);
      final result = await engineNotifier.getBotMove(
        fen: gameState.fen,
        difficulty: gameState.difficulty,
      );

      if (result != null && result.isValid) {
        final (from, to, promotion) = result.parsedMove;
        ref.read(gameProvider.notifier).applyBotMove(from, to, promotion: promotion);
      }
    } catch (e) {
      print('Error getting bot move: $e');
    } finally {
      if (mounted) {
        setState(() => _isBotThinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final engineState = ref.watch(engineProvider);
    final timerState = ref.watch(timerProvider);
    // Watch settings to trigger rebuilds on settings changes
    ref.watch(settingsProvider);

    // Handle timer switching when move count changes
    if (gameState.moveHistory.length != _lastMoveCount) {
      _lastMoveCount = gameState.moveHistory.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(timerProvider.notifier).switchTurn();
      });
    }

    // Trigger bot move when it's bot's turn
    if (gameState.status == GameStatus.active && 
        !gameState.isPlayerTurn && 
        !_isBotThinking &&
        !engineState.isThinking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkBotMove();
      });
    }

    // Stop timer and show game over dialog when game ends
    if (gameState.status == GameStatus.finished && gameState.result != null && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(timerProvider.notifier).stop();
        _autoSaveGame();
        _showGameOverDialog(context, gameState);
      });
    }

    // Reset dialog flag when game restarts
    if (gameState.status == GameStatus.active && _dialogShown) {
      _dialogShown = false;
    }

    // Handle timer timeout
    if (timerState.isTimedOut && gameState.status == GameStatus.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(gameProvider.notifier).handleTimeout(timerState.whiteTimedOut);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: _buildAppBar(context, gameState),
      body: SafeArea(
        child: Column(
          children: [
            // Opponent info bar
            _buildPlayerBar(
              context,
              isOpponent: true,
              name: 'Bot (${gameState.difficulty.elo})',
              isActive: !gameState.isPlayerTurn && gameState.status == GameStatus.active,
              isWhite: gameState.playerColor == PlayerColor.black, // Bot is opposite color
              isThinking: _isBotThinking,
            ),

            // Captured pieces (opponent)
            _buildCapturedPieces(gameState, forOpponent: true),

            // Chess board
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ChessBoard.internal(
                interactive: gameState.status == GameStatus.active,
                flipped: gameState.playerColor == PlayerColor.black,
                onMoveCallback: () {
                  // TODO: Play sound, trigger bot move
                },
              ),
            ),

            // Captured pieces (player)
            _buildCapturedPieces(gameState, forOpponent: false),

            // Player info bar
            _buildPlayerBar(
              context,
              isOpponent: false,
              name: 'You (${gameState.playerColor == PlayerColor.white ? "White" : "Black"})',
              isActive: gameState.isPlayerTurn && gameState.status == GameStatus.active,
              isWhite: gameState.playerColor == PlayerColor.white,
              isThinking: false,
            ),

            // Move history
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 18, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Moves',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            'Move ${gameState.moveNumber}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: MoveList(
                          moves: gameState.moveHistory,
                          currentMoveIndex: gameState.moveHistory.length - 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Control buttons
            _buildControlBar(context, gameState),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GameState gameState) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _showExitConfirmation(context),
      ),
      title: Column(
        children: [
          const Text('Game'),
          Text(
            gameState.timeControl.displayString,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.flip),
          tooltip: 'Flip board',
          onPressed: () {
            ref.read(settingsProvider.notifier).toggleBoardFlip();
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlayerBar(
    BuildContext context, {
    required bool isOpponent,
    required String name,
    required bool isActive,
    required bool isWhite,
    bool isThinking = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Player avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(color: AppTheme.primaryLight, width: 2)
                  : null,
            ),
            child: Icon(
              isOpponent ? Icons.smart_toy : Icons.person,
              color: isActive ? Colors.white : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          // Player name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
                if (isActive && isOpponent)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isThinking)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      if (isThinking) const SizedBox(width: 6),
                      Text(
                        isThinking ? 'Thinking...' : 'Your turn',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryLight,
                            ),
                      ),
                    ],
                  )
                else if (isActive)
                  Text(
                    'Your turn',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryLight,
                        ),
                  ),
              ],
            ),
          ),
          // Timer widget
          ChessTimerWidget(
            isWhite: isWhite,
            isActive: isActive,
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedPieces(GameState gameState, {required bool forOpponent}) {
    // TODO: Calculate captured pieces from move history
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: const Text(
        '',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, GameState gameState) {
    final gameNotifier = ref.read(gameProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Hint button
          _ControlButton(
            icon: Icons.lightbulb_outline,
            label: 'Hint',
            badge: gameState.canRequestHint
                ? '${AppConstants.maxHintsPerGame - gameState.hintsUsed}'
                : null,
            onPressed: gameState.canRequestHint && gameState.isPlayerTurn
                ? _requestHint
                : null,
          ),
          // Undo button
          _ControlButton(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: gameState.canUndo
                ? () {
                    gameNotifier.undoMove();
                  }
                : null,
          ),
          // Draw button
          _ControlButton(
            icon: Icons.handshake_outlined,
            label: 'Draw',
            onPressed: gameState.status == GameStatus.active
                ? () => _showDrawConfirmation(context)
                : null,
          ),
          // Resign button
          _ControlButton(
            icon: Icons.flag_outlined,
            label: 'Resign',
            onPressed: gameState.status == GameStatus.active
                ? () => _showResignConfirmation(context)
                : null,
          ),
        ],
      ),
    );
  }

  /// Request a hint from the engine
  Future<void> _requestHint() async {
    await ref.read(gameProvider.notifier).useHint(ref);
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('Your progress will be saved automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showResignConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign this game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameProvider.notifier).resign();
            },
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _showDrawConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offer Draw?'),
        content: const Text('The bot will consider your draw offer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameProvider.notifier).offerDraw();
            },
            child: const Text('Offer Draw'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, GameState gameState) {
    final isWin = (gameState.result == GameResult.whiteWins &&
            gameState.playerColor == PlayerColor.white) ||
        (gameState.result == GameResult.blackWins &&
            gameState.playerColor == PlayerColor.black);
    final isDraw = gameState.result == GameResult.draw;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isWin
                  ? Icons.emoji_events
                  : isDraw
                      ? Icons.handshake
                      : Icons.sentiment_dissatisfied,
              color: isWin
                  ? Colors.amber
                  : isDraw
                      ? Colors.blue
                      : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              isWin
                  ? 'Victory!'
                  : isDraw
                      ? 'Draw'
                      : 'Defeat',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gameState.resultReason ?? ''),
            const SizedBox(height: 16),
            Text(
              '${gameState.moveHistory.length} moves played',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Home'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalysisScreen(
                    moves: gameState.moveHistory,
                  ),
                ),
              );
            },
            child: const Text('Analyze'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Start new game with same settings
              ref.read(gameProvider.notifier).startNewGame(
                    playerColor: gameState.playerColor,
                    difficulty: gameState.difficulty,
                    timeControl: gameState.timeControl,
                  );
            },
            child: const Text('Rematch'),
          ),
        ],
      ),
    );
  }
}

/// Control button widget for game actions
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.badge,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isEnabled ? AppTheme.textPrimary : AppTheme.textHint,
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled ? AppTheme.textSecondary : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
