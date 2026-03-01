import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/screens/game/widgets/timer_widget.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';
import 'package:chess_master/screens/widgets/engine_status_indicator.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _dialogShown = false;
  int _lastMoveCount = 0;
  bool _isLandscapeLocked = false;
  final ScrollController _moveListController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTimer();
    });
  }

  @override
  void dispose() {
    _moveListController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _toggleOrientationLock() {
    setState(() {
      _isLandscapeLocked = !_isLandscapeLocked;
      if (_isLandscapeLocked) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    });
  }

  void _initializeTimer() {
    final gameState = ref.read(gameSessionProvider);
    if (gameState == null) return;
    final timerNotifier = ref.read(timerProvider.notifier);
    timerNotifier.initialize(gameState.timeControl);
    timerNotifier.setTimes(
      whiteTime: gameState.whiteTimeRemaining,
      blackTime: gameState.blackTimeRemaining,
    );
    timerNotifier.setTurn(gameState.isWhiteTurn);
    if (gameState.timeControl.hasTimer && !gameState.isCompleted) {
      timerNotifier.start();
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
    final gameState = ref.watch(gameSessionProvider);
    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final timerState = ref.watch(timerProvider);

    if (gameState.moveHistory.length != _lastMoveCount) {
      _lastMoveCount = gameState.moveHistory.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(timerProvider.notifier).switchTurn();
        _scrollToLastMove();
      });
    }

    if (gameState.isCompleted && gameState.result != null && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(timerProvider.notifier).stop();
        _showGameOverDialog(context, gameState);
      });
    }

    if (!gameState.isCompleted && _dialogShown) {
      _dialogShown = false;
    }

    if (timerState.isTimedOut && !gameState.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(gameSessionProvider.notifier)
            .handleTimeout(timerState.whiteTimedOut);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            return Column(
              children: [
                _buildCustomAppBar(context, gameState),
                Expanded(
                  child:
                      isLandscape
                          ? _buildLandscapeLayout(context, gameState)
                          : _buildPortraitLayout(context, gameState),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, GameSession gameState) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final totalHeight = constraints.maxHeight;
                final boardSize = (totalWidth).clamp(0.0, totalHeight - 160.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCompactPlayerBar(
                      context,
                      isOpponent: true,
                      name:
                          gameState.gameMode == GameMode.bot ? "Bot (${gameState.difficulty.elo})" : "Friend",
                      isActive:
                          !gameState.isPlayerTurn && !gameState.isCompleted,
                      isWhite: gameState.playerColor == PlayerColor.black,
                      gameState: gameState,
                    ),
                    const SizedBox(height: 16),
                    _buildBoard(boardSize, gameState),
                    const SizedBox(height: 16),
                    _buildCompactPlayerBar(
                      context,
                      isOpponent: false,
                      name: "You",
                      isActive:
                          gameState.isPlayerTurn && !gameState.isCompleted,
                      isWhite: gameState.playerColor == PlayerColor.white,
                      gameState: gameState,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        _buildBottomPanel(gameState),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, GameSession gameState) {
    // A 4:1 flex means the side panel gets 20% of the screen width. On phones, this can be ~95px.
    // Instead of wide rows, we stack the necessary info vertically.
    return Row(
      children: [
        // 80% Board (Flex 4)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxHeight < constraints.maxWidth
                    ? constraints.maxHeight
                    : constraints.maxWidth;
                return Center(child: _buildBoard(size, gameState));
              },
            ),
          ),
        ),
        // 20% Side Panel (Flex 1)
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Opponent Top Zone
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          gameState.gameMode == GameMode.bot
                              ? "Bot (${gameState.difficulty.elo})"
                              : "Friend",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ChessTimerWidget(
                        isWhite: gameState.playerColor == PlayerColor.black,
                        isActive: !gameState.isPlayerTurn && !gameState.isCompleted,
                        compact: true,
                      ),
                    ],
                  ),

                  // Middle Controls Zone
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.white70, size: 20),
                        onPressed: () => ref.read(gameSessionProvider.notifier).undoMove(),
                        tooltip: 'Undo',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.lightbulb_outline, color: Colors.white70, size: 20),
                        onPressed: () => ref.read(gameSessionProvider.notifier).useHint(ref),
                        tooltip: 'Hint',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),

                  // Player Bottom Zone
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChessTimerWidget(
                        isWhite: gameState.playerColor == PlayerColor.white,
                        isActive: gameState.isPlayerTurn && !gameState.isCompleted,
                        compact: true,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          "You",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(double size, GameSession gameState) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ChessBoard.internal(
            interactive: !gameState.isCompleted,
            flipped: gameState.isFlipped,
            onMoveCallback: () => _onMoveMade(gameState),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(GameSession gameState) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: Colors.white10),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _buildHorizontalMoveList(gameState),
            const SizedBox(height: 8),
            _buildControlBar(context, gameState),
          ],
        ),
      ),
    );
  }

  void _onMoveMade(GameSession gameState) {
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
  }

  Widget _buildCustomAppBar(BuildContext context, GameSession gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Text(
            gameState.timeControl.displayString,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.flip, color: AppTheme.textSecondary),
                    onPressed:
                        () => ref.read(gameSessionProvider.notifier).toggleFlip(),
                    tooltip: 'Flip Board',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.handshake_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => _showDrawConfirmation(context),
                    tooltip: 'Offer Draw',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.flag_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => _showResignConfirmation(context),
                    tooltip: 'Resign',
                  ),
                  IconButton(
                    icon: Icon(
                      _isLandscapeLocked
                          ? Icons.screen_lock_landscape
                          : Icons.screen_rotation,
                      color: _isLandscapeLocked ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                    onPressed: _toggleOrientationLock,
                    tooltip: 'Toggle Landscape Lock',
                  ),
                  const EngineStatusIndicator(),
                  _buildMoreMenu(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
      color: AppTheme.surfaceDark,
      onSelected: (value) {
        switch (value) {
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
            break;
          case 'exit':
            Navigator.pop(context);
            break;
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'settings',
              child: Text(
                'Settings',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
            PopupMenuItem(
              value: 'exit',
              child: Text(
                'Save & Exit',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
    );
  }

  void _showGameOverDialog(BuildContext context, GameSession gameState) {
    final isWin =
        (gameState.result == GameResult.whiteWins &&
            gameState.playerColor == PlayerColor.white) ||
        (gameState.result == GameResult.blackWins &&
            gameState.playerColor == PlayerColor.black);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Text(isWin ? 'Victory!' : 'Game Over'),
            content: Text(gameState.resultReason ?? 'Game finished'),
            actions: [
              TextButton(
                onPressed:
                    () => {Navigator.pop(context), Navigator.pop(context)},
                child: const Text('Home'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref
                      .read(gameSessionProvider.notifier)
                      .startNewGame(
                        playerColor: gameState.playerColor,
                        difficulty: gameState.difficulty,
                        timeControl: gameState.timeControl,
                        gameMode: gameState.gameMode,
                        botType: gameState.botType,
                      );
                },
                child: const Text('New Game'),
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
    required GameSession gameState,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                isActive ? AppTheme.primaryColor : AppTheme.cardDark,
            child: Icon(
              isOpponent ? Icons.smart_toy : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                _buildCapturedPiecesCompact(gameState, forOpponent: isOpponent),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: ChessTimerWidget(isWhite: isWhite, isActive: isActive),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedPiecesCompact(
    GameSession gameState, {
    required bool forOpponent,
  }) {
    final settings = ref.watch(settingsProvider);
    final isWhite = gameState.playerColor == PlayerColor.white;

    // Determine which pieces were captured by analyzing move history
    // We need to track which color made the capture based on move index
    final piecesToShow = <String>[];
    for (int i = 0; i < gameState.moveHistory.length; i++) {
      final move = gameState.moveHistory[i];
      if (move.capturedPiece != null) {
        // Even index = white's move, odd index = black's move
        final moveByWhite = i % 2 == 0;

        if (forOpponent) {
          // Show pieces captured BY opponent
          if (isWhite && !moveByWhite) {
            // Player is white, show pieces captured by black (white pieces)
            piecesToShow.add('w${move.capturedPiece!.toUpperCase()}');
          } else if (!isWhite && moveByWhite) {
            // Player is black, show pieces captured by white (black pieces)
            piecesToShow.add('b${move.capturedPiece!.toUpperCase()}');
          }
        } else {
          // Show pieces captured BY player
          if (isWhite && moveByWhite) {
            // Player is white, show pieces captured by white (black pieces)
            piecesToShow.add('b${move.capturedPiece!.toUpperCase()}');
          } else if (!isWhite && !moveByWhite) {
            // Player is black, show pieces captured by black (white pieces)
            piecesToShow.add('w${move.capturedPiece!.toUpperCase()}');
          }
        }
      }
    }

    return Row(
      children:
          piecesToShow
              .take(8)
              .map(
                (piece) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: ChessPiece(
                    piece: piece,
                    size: 10,
                    pieceSet: settings.currentPieceSet,
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildHorizontalMoveList(GameSession gameState) {
    return SizedBox(
      height: 36,
      child: _buildMoveList(gameState, horizontal: true),
    );
  }

  Widget _buildMoveList(GameSession gameState, {bool horizontal = false}) {
    final moves = gameState.moveHistory;
    return ListView.builder(
      controller: _moveListController,
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: (moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final moveNum = index + 1;
        final whiteMove = moves[index * 2];
        final blackMove =
            (index * 2 + 1 < moves.length) ? moves[index * 2 + 1] : null;

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$moveNum. ', style: const TextStyle(color: Colors.white38)),
            Text(whiteMove.san, style: const TextStyle(color: Colors.white)),
            if (blackMove != null) ...[
              const SizedBox(width: 8),
              Text(blackMove.san, style: const TextStyle(color: Colors.white)),
            ],
            if (horizontal) const SizedBox(width: 16),
          ],
        );

        return horizontal
            ? content
            : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: content,
            );
      },
    );
  }

  Widget _buildControlBar(BuildContext context, GameSession gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white70),
            onPressed: () => ref.read(gameSessionProvider.notifier).undoMove(),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: Colors.white70),
            onPressed:
                () => ref.read(gameSessionProvider.notifier).useHint(ref),
          ),
        ],
      ),
    );
  }

  void _showResignConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Resign?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(gameSessionProvider.notifier).resign();
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
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Offer Draw?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(gameSessionProvider.notifier).handleDraw();
                },
                child: const Text('Offer Draw'),
              ),
            ],
          ),
    );
  }
}
