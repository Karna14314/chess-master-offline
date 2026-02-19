import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/screens/game/widgets/move_list.dart'; // Keep for Analysis if needed, but we build custom list here
import 'package:chess_master/screens/game/widgets/timer_widget.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';
import 'package:chess_master/screens/widgets/engine_status_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final ScrollController _moveListController = ScrollController();

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
    _moveListController.dispose();
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

    if (gameState.timeControl.hasTimer &&
        gameState.status == GameStatus.active) {
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
        'player_color': gameState.playerColor == PlayerColor.white
            ? 'white'
            : 'black',
        'bot_elo': gameState.difficulty.elo,
        'game_mode': gameState.isLocalMultiplayer ? 'local' : 'bot',
        'time_control': gameState.timeControl.name,
        'white_time_remaining': timerState.whiteTime.inMilliseconds,
        'black_time_remaining': timerState.blackTime.inMilliseconds,
        'created_at':
            gameState.startedAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'move_count': gameState.moveHistory.length,
        'is_completed': gameState.status == GameStatus.finished ? 1 : 0,
        'is_saved': 1,
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
    buffer.writeln(
      '[Date "${DateTime.now().toIso8601String().split('T')[0]}"]',
    );
    buffer.writeln(
      '[White "${gameState.playerColor == PlayerColor.white ? 'Player' : 'Bot (${gameState.difficulty.elo})'}"]',
    );
    buffer.writeln(
      '[Black "${gameState.playerColor == PlayerColor.black ? 'Player' : 'Bot (${gameState.difficulty.elo})'}"]',
    );
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
      final currentVersion = gameState.version;

      final result = await engineNotifier.getBotMove(
        fen: gameState.fen,
        difficulty: gameState.difficulty,
        botType: gameState.botType,
      );

      // Check for race condition - if board state changed, discard move
      if (ref.read(gameProvider).version != currentVersion) {
        return;
      }

      if (result != null && result.isValid) {
        final (from, to, promotion) = result.parsedMove;
        ref
            .read(gameProvider.notifier)
            .applyBotMove(from, to, promotion: promotion);
      }
    } catch (e) {
      debugPrint('Error getting bot move: $e');
    } finally {
      if (mounted) {
        setState(() => _isBotThinking = false);
      }
    }
  }

  void _scrollToLastMove() {
    if (_moveListController.hasClients) {
      _moveListController.animateTo(
        _moveListController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
        _scrollToLastMove();
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
    if (gameState.status == GameStatus.finished &&
        gameState.result != null &&
        !_dialogShown) {
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
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Back button, Title, Settings)
            _buildCustomAppBar(context, gameState),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Opponent Profile
                  _buildCompactPlayerBar(
                    context,
                    isOpponent: true,
                    name: gameState.isLocalMultiplayer
                        ? (gameState.playerColor == PlayerColor.white
                              ? 'Player 2'
                              : 'Player 1')
                        : '${gameState.botType.displayName} (${gameState.difficulty.elo})',
                    isActive:
                        !gameState.isPlayerTurn &&
                        gameState.status == GameStatus.active,
                    isWhite: gameState.playerColor == PlayerColor.black,
                    isThinking: _isBotThinking,
                    gameState: gameState,
                  ),

                  const SizedBox(height: 12),

                  // Board Area
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFC5A028).withOpacity(0.3),
                          width: 1,
                        ), // Muted gold border
                      ),
                      child: ChessBoard.internal(
                        interactive: gameState.status == GameStatus.active,
                        flipped: gameState.playerColor == PlayerColor.black,
                        onMoveCallback: () => _onMoveMade(gameState),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Player Profile
                  _buildCompactPlayerBar(
                    context,
                    isOpponent: false,
                    name: gameState.isLocalMultiplayer
                        ? (gameState.playerColor == PlayerColor.white
                              ? 'Player 1'
                              : 'Player 2')
                        : 'You',
                    isActive:
                        gameState.isPlayerTurn &&
                        gameState.status == GameStatus.active,
                    isWhite: gameState.playerColor == PlayerColor.white,
                    isThinking: false,
                    gameState: gameState,
                  ),
                ],
              ),
            ),

            // Bottom Section: Move Ribbon & Controls
            Container(
              color: AppTheme.surfaceDark.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Horizontal Move List
                  _buildHorizontalMoveList(gameState),
                  const Divider(height: 1, color: AppTheme.borderColor),
                  // Controls
                  _buildControlBar(context, gameState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMoveMade(GameState gameState) {
    final settings = ref.read(settingsProvider);
    final audioService = ref.read(audioServiceProvider);

    audioService.setEnabled(settings.soundEnabled);

    if (gameState.moveHistory.isNotEmpty) {
      final lastMove = gameState.moveHistory.last;
      audioService.playMoveSound(
        isCapture: lastMove.isCapture,
        isCheck: lastMove.isCheck,
        isCheckmate: lastMove.isCheckmate,
        isCastle: lastMove.isCastle,
      );
    }
    _checkBotMove();
  }

  Widget _buildCustomAppBar(BuildContext context, GameState gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitConfirmation(context),
            icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          Text(
            gameState.timeControl.displayString,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.flip, color: AppTheme.textSecondary),
            onPressed: () {
              ref.read(settingsProvider.notifier).toggleBoardFlip();
            },
          ),
          const EngineStatusIndicator(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            color: AppTheme.surfaceDark,
            onSelected: (value) {
              switch (value) {
                case 'save_exit':
                  _saveAndExit(context);
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save_exit',
                child: Row(
                  children: [
                    const Icon(
                      Icons.save,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Save & Exit',
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPlayerBar(
    BuildContext context, {
    required bool isOpponent,
    required String name,
    required bool isActive,
    required bool isWhite,
    bool isThinking = false,
    required GameState gameState,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.primaryColor : AppTheme.cardDark,
              border: Border.all(
                color: isActive ? AppTheme.primaryLight : Colors.transparent,
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isOpponent ? Icons.smart_toy : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Name & Captures
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                // Captured Pieces
                _buildCapturedPiecesCompact(gameState, forOpponent: isOpponent),
              ],
            ),
          ),
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(color: AppTheme.primaryColor, width: 1)
                  : null,
            ),
            child: ChessTimerWidget(isWhite: isWhite, isActive: isActive),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedPiecesCompact(
    GameState gameState, {
    required bool forOpponent,
  }) {
    final settings = ref.watch(settingsProvider);

    // Calculate captured pieces and material advantage
    final whiteCaptures = <String>[]; // Pieces captured BY white (black pieces)
    final blackCaptures = <String>[]; // Pieces captured BY black (white pieces)

    for (int i = 0; i < gameState.moveHistory.length; i++) {
      final move = gameState.moveHistory[i];
      if (move.capturedPiece != null) {
        // Even index (0, 2, 4...) = White's move, so white captured a black piece
        // Odd index (1, 3, 5...) = Black's move, so black captured a white piece
        if (i % 2 == 0) {
          // White captured a black piece
          whiteCaptures.add('b${move.capturedPiece!.toUpperCase()}');
        } else {
          // Black captured a white piece
          blackCaptures.add('w${move.capturedPiece!.toUpperCase()}');
        }
      }
    }

    // Calculate material values
    int getMaterialValue(String piece) {
      final pieceType = piece.substring(1); // Remove color prefix
      switch (pieceType) {
        case 'P':
          return 1;
        case 'N':
          return 3;
        case 'B':
          return 3;
        case 'R':
          return 5;
        case 'Q':
          return 9;
        default:
          return 0;
      }
    }

    final whiteMaterial = whiteCaptures.fold<int>(
      0,
      (sum, piece) => sum + getMaterialValue(piece),
    );
    final blackMaterial = blackCaptures.fold<int>(
      0,
      (sum, piece) => sum + getMaterialValue(piece),
    );

    // Sort captures by value
    int getPieceValue(String p) =>
        {'P': 1, 'N': 2, 'B': 3, 'R': 4, 'Q': 5}[p.substring(1)] ?? 0;
    whiteCaptures.sort((a, b) => getPieceValue(a).compareTo(getPieceValue(b)));
    blackCaptures.sort((a, b) => getPieceValue(a).compareTo(getPieceValue(b)));

    // Determine which pieces to show based on player perspective
    List<String> piecesToShow;
    int materialAdvantage;

    if (gameState.isLocalMultiplayer) {
      // In local multiplayer, show pieces captured by each player
      if (forOpponent) {
        // Opponent's captures
        piecesToShow = gameState.playerColor == PlayerColor.white
            ? blackCaptures
            : whiteCaptures;
        materialAdvantage = gameState.playerColor == PlayerColor.white
            ? blackMaterial - whiteMaterial
            : whiteMaterial - blackMaterial;
      } else {
        // Current player's captures
        piecesToShow = gameState.playerColor == PlayerColor.white
            ? whiteCaptures
            : blackCaptures;
        materialAdvantage = gameState.playerColor == PlayerColor.white
            ? whiteMaterial - blackMaterial
            : blackMaterial - whiteMaterial;
      }
    } else {
      // In bot games, show pieces captured by each side
      if (forOpponent) {
        // Bot's captures (pieces bot captured from player)
        piecesToShow = gameState.playerColor == PlayerColor.white
            ? blackCaptures
            : whiteCaptures;
        materialAdvantage = gameState.playerColor == PlayerColor.white
            ? blackMaterial - whiteMaterial
            : whiteMaterial - blackMaterial;
      } else {
        // Player's captures (pieces player captured from bot)
        piecesToShow = gameState.playerColor == PlayerColor.white
            ? whiteCaptures
            : blackCaptures;
        materialAdvantage = gameState.playerColor == PlayerColor.white
            ? whiteMaterial - blackMaterial
            : blackMaterial - whiteMaterial;
      }
    }

    return SizedBox(
      height: 14,
      child: Row(
        children: [
          // Captured pieces
          if (piecesToShow.isNotEmpty)
            Flexible(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: piecesToShow.length,
                itemBuilder: (context, index) {
                  final piece = piecesToShow[index];
                  final isBlackPiece = piece.startsWith('b');

                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isBlackPiece
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      padding: const EdgeInsets.all(1),
                      child: ChessPiece(
                        piece: piece,
                        size: 12,
                        pieceSet: settings.currentPieceSet,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Material advantage indicator
          if (materialAdvantage > 0) ...[
            const SizedBox(width: 4),
            Text(
              '+$materialAdvantage',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          // Placeholder if no captures
          if (piecesToShow.isEmpty && materialAdvantage == 0)
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildHorizontalMoveList(GameState gameState) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        controller: _moveListController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: (gameState.moveHistory.length / 2).ceil(),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final moveNum = index + 1;
          final whiteIndex = index * 2;
          final blackIndex = index * 2 + 1;
          final whiteMove = gameState.moveHistory[whiteIndex];
          final blackMove = blackIndex < gameState.moveHistory.length
              ? gameState.moveHistory[blackIndex]
              : null;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$moveNum.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  whiteMove.san,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                ),
                if (blackMove != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    blackMove.san,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, GameState gameState) {
    final valid = gameState.status == GameStatus.active;
    final gameNotifier = ref.read(gameProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.lightbulb_outline,
            label: 'Hint',
            onPressed: (valid && gameState.isPlayerTurn) ? _requestHint : null,
          ),
          _ControlButton(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: (gameState.canUndo) ? gameNotifier.undoMove : null,
          ),
          _ControlButton(
            icon: Icons.handshake_outlined,
            label: 'Draw',
            onPressed: (valid) ? () => _showDrawConfirmation(context) : null,
          ),
          _ControlButton(
            icon: Icons.flag_outlined,
            label: 'Resign',
            onPressed: (valid) ? () => _showResignConfirmation(context) : null,
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
        backgroundColor: AppTheme.surfaceDark,
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

  Future<void> _saveAndExit(BuildContext context) async {
    // Save the game
    await _autoSaveGame();

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Game saved successfully',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Wait a moment for the snackbar to show
      await Future.delayed(const Duration(milliseconds: 500));

      // Exit to home
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showResignConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign this game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
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
        backgroundColor: AppTheme.surfaceDark,
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
    final isWin =
        (gameState.result == GameResult.whiteWins &&
            gameState.playerColor == PlayerColor.white) ||
        (gameState.result == GameResult.blackWins &&
            gameState.playerColor == PlayerColor.black);
    final isDraw = gameState.result == GameResult.draw;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
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
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gameState.resultReason ?? '',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
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
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Game Screen
            },
            child: const Text('Home'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Ensure we have moves before navigating
              if (gameState.moveHistory.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalysisScreen(
                      moves: gameState.moveHistory,
                      startingFen:
                          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No moves to analyze',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Analyze'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Start new game with same settings
              ref
                  .read(gameProvider.notifier)
                  .startNewGame(
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
                  size: 24,
                  color: isEnabled ? AppTheme.textPrimary : AppTheme.textHint,
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 8,
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
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isEnabled ? AppTheme.textPrimary : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
