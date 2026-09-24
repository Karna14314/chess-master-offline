import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/game/widgets/timer_widget.dart';
import 'package:chess_master/screens/game/widgets/move_list.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/widgets/engine_status_indicator.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/widgets/shared/bot_avatar.dart';
import 'package:chess_master/widgets/shared/player_bar.dart';
import 'package:chess_master/widgets/shared/bottom_action_bar.dart';
import 'package:chess_master/widgets/shared/result_card.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final ScrollController _moveListController = ScrollController();
  String? _initializedSessionId;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitializeSession();
    });
  }

  Future<void> _checkAndInitializeSession() async {
    final currentSession = ref.read(gameSessionProvider);
    if (currentSession == null) {
      final repo = ref.read(gameSessionRepositoryProvider);
      final games = await repo.getUnfinishedGames(limit: 1);
      if (games.isNotEmpty && mounted) {
        ref.read(gameSessionProvider.notifier).resumeSession(games.first);
      } else if (mounted) {
        Navigator.of(context).pop();
        return;
      }
    }
    _initializeTimer();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Stop any in-flight bot search so native threads don't outlive the
    // screen and fire callbacks after dispose (DartMessenger SIGABRT).
    try {
      ref.read(engineProvider.notifier).stopAnalysis();
    } catch (_) {}
    _moveListController.dispose();
    super.dispose();
  }

  void _initializeTimer() {
    final gameState = ref.read(gameSessionProvider);
    if (gameState == null) return;
    if (gameState.id == _initializedSessionId) return;
    _initializedSessionId = gameState.id;

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
        duration: const Duration(milliseconds: 250),
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

    // Listen for move history changes
    ref.listen<GameSession?>(gameSessionProvider, (previous, next) {
      if (next == null) return;

      if (next.id != _initializedSessionId) {
        _initializeTimer();
      }

      // Handle move count change
      if (previous != null &&
          previous.moveHistory.length != next.moveHistory.length) {
        ref.read(timerProvider.notifier).switchTurn();
        _scrollToLastMove();
      }

      // Handle game completion
      if (previous != null &&
          !previous.isCompleted &&
          next.isCompleted &&
          next.result != null) {
        ref.read(timerProvider.notifier).stop();
        _showGameOverDialog(context, next);
      }
    });

    // Listen for timer timeouts
    ref.listen<TimerState>(timerProvider, (previous, next) {
      if (next.isTimedOut && !gameState.isCompleted) {
        ref
            .read(gameSessionProvider.notifier)
            .handleTimeout(next.whiteTimedOut);
      }
    });

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceLevel0(context),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;
              return Column(
                children: [
                  _buildCustomAppBar(context, gameState),
                  Expanded(
                    child: isLandscape
                        ? _buildLandscapeLayout(context, gameState)
                        : _buildPortraitLayout(context, gameState),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, GameSession gameState) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final isBot = gameState.gameMode == GameMode.bot;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8, vertical: AppTheme.space4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
            tooltip: 'Back',
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isBot
                            ? (gameState.botProfile != null
                                ? gameState.botProfile!.name
                                : 'Bot (${gameState.difficulty.elo})')
                            : 'Pass & Play',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isBot && gameState.botProfile != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: gameState.botProfile!.tier.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          '${gameState.botProfile!.elo}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: gameState.botProfile!.tier.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  gameState.timeControl.hasTimer
                      ? gameState.timeControl.displayString
                      : 'Casual / No Clock',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const EngineStatusIndicator(),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            color: AppTheme.surfaceLevel2(context),
            onSelected: (action) => _handleMenuAction(context, action, gameState),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'flip',
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Flip Board'),
                  ],
                ),
              ),
              if (!gameState.isCompleted) ...[
                const PopupMenuItem(
                  value: 'draw',
                  child: Row(
                    children: [
                      Icon(Icons.handshake_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Offer Draw'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'resign',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 20, color: AppTheme.crimsonRed),
                      SizedBox(width: 12),
                      Text('Resign Match', style: TextStyle(color: AppTheme.crimsonRed)),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, GameSession gameState) {
    switch (action) {
      case 'flip':
        ref.read(gameSessionProvider.notifier).toggleFlip();
        break;
      case 'draw':
        _showDrawConfirmation(context);
        break;
      case 'resign':
        _showResignConfirmation(context);
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  Widget _buildPortraitLayout(BuildContext context, GameSession gameState) {
    final opponentIsWhite = gameState.playerColor == PlayerColor.black;
    final playerIsWhite = gameState.playerColor == PlayerColor.white;

    return Column(
      children: [
        // Main Board Play Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final totalHeight = constraints.maxHeight;
                // Reserve space for top and bottom player bars (~56px each + spacing)
                final availableHeight = (totalHeight - 144.0).clamp(0.0, double.infinity);
                final maxDimension = totalWidth < availableHeight ? totalWidth : availableHeight;
                final boardSize = maxDimension.clamp(160.0, 540.0);

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    // Opponent Bar
                    PlayerBar(
                      avatar: (gameState.gameMode == GameMode.bot && gameState.botProfile != null)
                          ? BotAvatar(bot: gameState.botProfile!, size: 40, showElo: false)
                          : Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLevel2(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                gameState.gameMode == GameMode.bot
                                    ? Icons.smart_toy_rounded
                                    : Icons.person_rounded,
                                color: AppTheme.textPrimaryFor(context),
                                size: 20,
                              ),
                            ),
                      name: gameState.gameMode == GameMode.bot
                          ? (gameState.botProfile?.name ?? 'Bot (${gameState.difficulty.elo})')
                          : 'Friend',
                      elo: gameState.gameMode == GameMode.bot
                          ? (gameState.botProfile?.elo ?? gameState.difficulty.elo)
                          : null,
                      isActive: !gameState.isPlayerTurn && !gameState.isCompleted,
                      isWhite: opponentIsWhite,
                      timerWidget: gameState.timeControl.hasTimer
                          ? ChessTimerWidget(
                              isWhite: opponentIsWhite,
                              isActive: !gameState.isPlayerTurn && !gameState.isCompleted,
                              compact: true,
                            )
                          : null,
                      capturedPieces: _getCapturedPieces(gameState, forOpponent: true),
                      materialAdvantage: _calculateMaterialAdvantage(gameState, isWhite: opponentIsWhite),
                    ),

                    const SizedBox(height: AppTheme.space8),

                    // Chess Board Container
                    _buildBoard(boardSize, gameState),

                    const SizedBox(height: AppTheme.space8),

                    // Player Bar
                    PlayerBar(
                      avatar: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      name: 'You',
                      isActive: gameState.isPlayerTurn && !gameState.isCompleted,
                      isWhite: playerIsWhite,
                      timerWidget: gameState.timeControl.hasTimer
                          ? ChessTimerWidget(
                              isWhite: playerIsWhite,
                              isActive: gameState.isPlayerTurn && !gameState.isCompleted,
                              compact: true,
                            )
                          : null,
                      capturedPieces: _getCapturedPieces(gameState, forOpponent: false),
                      materialAdvantage: _calculateMaterialAdvantage(gameState, isWhite: playerIsWhite),
                    ),
                  ],
                ),
              ),
            );
              },
            ),
          ),
        ),

        // Bottom Controls Area
        _buildBottomPanel(gameState),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, GameSession gameState) {
    return Row(
      children: [
        // 75% Board
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space12),
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

        // 25% Side Panel
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLevel1(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.borderStroke(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space12),
              child: Column(
                children: [
                  // Opponent summary
                  Text(
                    gameState.botProfile != null
                        ? "${gameState.botProfile!.name} (${gameState.botProfile!.elo})"
                        : (gameState.gameMode == GameMode.bot
                            ? "Bot (${gameState.difficulty.elo})"
                            : "Opponent"),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryFor(context),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (gameState.timeControl.hasTimer) ...[
                    const SizedBox(height: 4),
                    ChessTimerWidget(
                      isWhite: gameState.playerColor == PlayerColor.black,
                      isActive: !gameState.isPlayerTurn && !gameState.isCompleted,
                      compact: true,
                    ),
                  ],

                  const Divider(height: 16),

                  // Move list scroll
                  Expanded(
                    child: MoveList(
                      moves: gameState.moveHistory,
                      scrollController: _moveListController,
                    ),
                  ),

                  const Divider(height: 16),

                  // Player summary
                  Text(
                    "You",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryFor(context),
                      fontSize: 12,
                    ),
                  ),
                  if (gameState.timeControl.hasTimer) ...[
                    const SizedBox(height: 4),
                    ChessTimerWidget(
                      isWhite: gameState.playerColor == PlayerColor.white,
                      isActive: gameState.isPlayerTurn && !gameState.isCompleted,
                      compact: true,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo_rounded, size: 20),
                        tooltip: 'Undo',
                        onPressed: gameState.isCompleted
                            ? null
                            : () => ref.read(gameSessionProvider.notifier).undoMove(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
                        tooltip: 'Hint',
                        onPressed: gameState.isCompleted
                            ? null
                            : () => _showHintDialog(context, ref),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_vert_rounded, size: 20),
                        tooltip: 'Flip',
                        onPressed: () => ref.read(gameSessionProvider.notifier).toggleFlip(),
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
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppTheme.borderStroke(context),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1.5),
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
        color: AppTheme.surfaceLevel1(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderStroke(context),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Move history strip
            MoveList(
              moves: gameState.moveHistory,
              scrollController: _moveListController,
              onExpandTap: () => _showMoveHistorySheet(context, gameState),
            ),

            // Ergonomic thumb-zone bottom action bar
            BottomActionBar(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12, vertical: AppTheme.space4),
              children: [
                BottomActionItem(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onPressed: gameState.isCompleted
                      ? null
                      : () => ref.read(gameSessionProvider.notifier).undoMove(),
                ),
                BottomActionItem(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Hint',
                  onPressed: gameState.isCompleted
                      ? null
                      : () => _showHintDialog(context, ref),
                ),
                BottomActionItem(
                  icon: Icons.swap_vert_rounded,
                  label: 'Flip',
                  onPressed: () => ref.read(gameSessionProvider.notifier).toggleFlip(),
                ),
                BottomActionItem(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  onPressed: () => _showGameMenuBottomSheet(context, gameState),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveHistorySheet(BuildContext context, GameSession gameState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLevel1(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => MoveTableSheet(moves: gameState.moveHistory),
    );
  }

  void _showGameMenuBottomSheet(BuildContext context, GameSession gameState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLevel1(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (sheetContext) {
        final textPrimary = AppTheme.textPrimaryFor(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.borderStroke(sheetContext),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (!gameState.isCompleted) ...[
                  ListTile(
                    leading: const Icon(Icons.handshake_outlined),
                    title: Text('Offer Draw', style: TextStyle(color: textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showDrawConfirmation(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: AppTheme.crimsonRed),
                    title: const Text('Resign Match', style: TextStyle(color: AppTheme.crimsonRed)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showResignConfirmation(context);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text('Analyze Position', style: TextStyle(color: textPrimary)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalysisScreen(
                          moves: gameState.moveHistory,
                          startingFen: gameState.startingFen,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text('Game Settings', style: TextStyle(color: textPrimary)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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

  void _showGameOverDialog(BuildContext context, GameSession gameState) {
    final isWhite = gameState.playerColor == PlayerColor.white;
    final isBot = gameState.gameMode == GameMode.bot;
    final bool isDraw = gameState.result == GameResult.draw;
    final bool isWin = !isDraw &&
        ((gameState.result == GameResult.whiteWins && isWhite) ||
            (gameState.result == GameResult.blackWins && !isWhite));

    final String title;
    if (isDraw) {
      title = 'Draw';
    } else if (gameState.gameMode == GameMode.localMultiplayer) {
      title = gameState.result == GameResult.whiteWins ? 'White Victory!' : 'Black Victory!';
    } else if (isWin) {
      title = 'Victory!';
    } else {
      title = 'Defeat';
    }

    final reason = gameState.resultReason ??
        (isDraw ? 'Game drawn' : (isWin ? 'Checkmate' : 'Defeat'));

    final opponentName = isBot
        ? (gameState.botProfile?.name ?? 'Bot')
        : 'Pass & Play';

    final opponentElo = isBot
        ? (gameState.botProfile?.elo ?? gameState.difficulty.elo)
        : null;

    final playerAccuracy = isWhite ? gameState.whiteAccuracy : gameState.blackAccuracy;
    final opponentAccuracy = isWhite ? gameState.blackAccuracy : gameState.whiteAccuracy;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ResultCard(
          title: title,
          subtitle: reason,
          isWin: isWin,
          isDraw: isDraw,
          opponentName: opponentName,
          opponentElo: opponentElo,
          playerAccuracy: playerAccuracy,
          opponentAccuracy: opponentAccuracy,
          campaignStarsEarned: (isWin && gameState.campaignLevel != null) ? 3 : null,
          onRematch: () async {
            Navigator.pop(dialogContext);
            try {
              await ref.read(gameSessionProvider.notifier).startNewGame(
                    playerColor: gameState.playerColor,
                    difficulty: gameState.difficulty,
                    timeControl: gameState.timeControl,
                    gameMode: gameState.gameMode,
                    botType: gameState.botType,
                    botProfile: gameState.botProfile,
                    campaignLevel: gameState.campaignLevel,
                  );
            } catch (_) {}
          },
          onAnalyse: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalysisScreen(
                  moves: gameState.moveHistory,
                  startingFen: gameState.startingFen,
                ),
              ),
            );
          },
          onHome: () {
            Navigator.pop(dialogContext);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showHintDialog(BuildContext context, WidgetRef ref) async {
    final state = ref.read(gameSessionProvider);
    if (state == null) return;

    if (state.hintDetails == null) {
      await ref.read(gameSessionProvider.notifier).useHint(ref);
    }

    final updatedState = ref.read(gameSessionProvider);
    if (updatedState == null || updatedState.hintDetails == null) return;

    final hint = updatedState.hintDetails!;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppTheme.surfaceLevel2(dialogCtx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          title: Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: AppTheme.amberGold),
              const SizedBox(width: 8),
              Text(
                'Engine Hint',
                style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textPrimaryFor(dialogCtx),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Best Move: ${hint.bestMove}',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint.explanation,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryFor(dialogCtx),
                  fontSize: 13,
                ),
              ),
              if (hint.tacticalMotif != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: AppTheme.amberGold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Motif: ${hint.tacticalMotif}',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(dialogCtx),
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  void _showResignConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceLevel2(innerContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(
          'Resign Match?',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimaryFor(innerContext),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to resign? This will count as a loss in your match history.',
          style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(innerContext)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext),
            child: const Text('Keep Playing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
            onPressed: () {
              Navigator.pop(innerContext);
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
      builder: (innerContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceLevel2(innerContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(
          'Offer Draw?',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimaryFor(innerContext),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Offer a draw to your opponent for this game?',
          style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(innerContext)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
            onPressed: () {
              Navigator.pop(innerContext);
              ref.read(gameSessionProvider.notifier).handleDraw();
            },
            child: const Text('Offer Draw'),
          ),
        ],
      ),
    );
  }

  List<String> _getCapturedPieces(GameSession gameState, {required bool forOpponent}) {
    final isWhite = gameState.playerColor == PlayerColor.white;
    final piecesToShow = <String>[];

    for (int i = 0; i < gameState.moveHistory.length; i++) {
      final move = gameState.moveHistory[i];
      if (move.capturedPiece != null) {
        final moveByWhite = i % 2 == 0;
        if (forOpponent) {
          if (isWhite && !moveByWhite) {
            piecesToShow.add('w${move.capturedPiece!.toUpperCase()}');
          } else if (!isWhite && moveByWhite) {
            piecesToShow.add('b${move.capturedPiece!.toUpperCase()}');
          }
        } else {
          if (isWhite && moveByWhite) {
            piecesToShow.add('b${move.capturedPiece!.toUpperCase()}');
          } else if (!isWhite && !moveByWhite) {
            piecesToShow.add('w${move.capturedPiece!.toUpperCase()}');
          }
        }
      }
    }
    return piecesToShow;
  }

  int _calculateMaterialAdvantage(GameSession gameState, {required bool isWhite}) {
    int whiteCapturedValue = 0;
    int blackCapturedValue = 0;

    for (int i = 0; i < gameState.moveHistory.length; i++) {
      final move = gameState.moveHistory[i];
      if (move.capturedPiece != null) {
        final val = _pieceValue(move.capturedPiece);
        final moveByWhite = (i % 2 == 0);
        if (moveByWhite) {
          whiteCapturedValue += val;
        } else {
          blackCapturedValue += val;
        }
      }
    }

    return isWhite
        ? (whiteCapturedValue - blackCapturedValue)
        : (blackCapturedValue - whiteCapturedValue);
  }

  int _pieceValue(String? pieceChar) {
    if (pieceChar == null || pieceChar.isEmpty) return 0;
    switch (pieceChar.toLowerCase()) {
      case 'p':
        return 1;
      case 'n':
      case 'b':
        return 3;
      case 'r':
        return 5;
      case 'q':
        return 9;
      default:
        return 0;
    }
  }
}
