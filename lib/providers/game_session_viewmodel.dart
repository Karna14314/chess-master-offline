import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/services/notification_service.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/providers/streak_provider.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess/chess.dart' as chess;

/// Provider for the active game session
final gameSessionProvider =
    StateNotifierProvider<GameSessionViewModel, GameSession?>((ref) {
      final repository = ref.watch(gameSessionRepositoryProvider);
      return GameSessionViewModel(repository, ref);
    });

/// ViewModel for managing the active game session
class GameSessionViewModel extends StateNotifier<GameSession?> {
  final GameSessionRepository _repository;
  final Ref _ref;
  int _sessionGeneration = 0;
  int? _activeSessionGeneration;
  bool _isBotThinking = false;

  GameSessionViewModel(this._repository, this._ref) : super(null);

  /// Start a new game
  Future<void> startNewGame({
    required PlayerColor playerColor,
    required DifficultyLevel difficulty,
    required TimeControl timeControl,
    GameMode gameMode = GameMode.bot,
    BotType botType = BotType.stockfish,
    String? startingFen,
    BotProfile? botProfile,
    int? campaignLevel,
  }) async {
    final generation = ++_sessionGeneration;
    _isBotThinking = false;

    // Reset engine first to ensure clean state for new game (except local multiplayer).
    // Awaited: resetForNewGame serializes stop + skill level + ucinewgame
    // ahead of the first search, so no arbitrary delay is needed.
    if (gameMode != GameMode.localMultiplayer) {
      final engineNotifier = _ref.read(engineProvider.notifier);
      try {
        await engineNotifier.resetForNewGame(difficulty: difficulty);
      } catch (e) {
        debugPrint('Engine reset failed while starting game: $e');
      }
    }

    if (generation != _sessionGeneration) return;

    final session = GameSession.create(
      gameMode: gameMode,
      botType: botProfile?.engineType ?? botType,
      difficulty: botProfile?.difficultyLevel ?? difficulty,
      timeControl: timeControl,
      playerColor: playerColor,
      startingFen: startingFen,
      botId: botProfile?.id,
      campaignLevel: campaignLevel,
    );

    _activeSessionGeneration = generation;
    state = session;
    try {
      await _repository.saveSession(session);
    } catch (e) {
      debugPrint('Failed to save new game session: $e');
    }

    // If bot is White, it starts the game
    if (gameMode == GameMode.bot && session.playerColor == PlayerColor.black) {
      unawaited(_makeBotMove(generation));
    }
  }

  bool _ownsSession(int generation, GameSession session) {
    return generation == _sessionGeneration &&
        generation == _activeSessionGeneration &&
        state?.id == session.id;
  }

  /// Rebuild the board from the starting FEN + full move history so the
  /// board's internal history is preserved (required for draw-by-repetition
  /// detection). Falls back to the stored FEN if the history is inconsistent
  /// with it (e.g. a corrupted/legacy session).
  chess.Chess _reconstructBoard(GameSession session) {
    final board = chess.Chess.fromFEN(session.startingFen);
    for (final move in session.moveHistory) {
      board.move({
        'from': move.from,
        'to': move.to,
        if (move.promotion != null) 'promotion': move.promotion,
      });
    }
    if (board.fen != session.fen) {
      return chess.Chess.fromFEN(session.fen);
    }
    return board;
  }

  /// The session's move history as UCI strings (from+to, with promotion).
  List<String> _uciMoves(GameSession session) =>
      session.moveHistory
          .map((m) => m.from + m.to + (m.promotion ?? ''))
          .toList();

  /// Make a move
  Future<bool> makeMove(
    String from,
    String to, {
    String? promotion,
    double? evaluation,
    int? sessionGeneration,
  }) async {
    final generation = sessionGeneration ?? _sessionGeneration;
    final currentSession = state;
    if (currentSession == null ||
        currentSession.isCompleted ||
        !_ownsSession(generation, currentSession)) {
      return false;
    }

    final board = _reconstructBoard(currentSession);

    // Check if player turn (unless it's a bot move being processed)
    if (!_isBotThinking &&
        !currentSession.isPlayerTurn &&
        currentSession.gameMode == GameMode.bot) {
      return false;
    }

    final moveSuccess = board.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    if (!moveSuccess) return false;

    final history = board.getHistory({'verbose': true});
    final lastMove = history.isNotEmpty ? history.last as Map : null;
    final san = lastMove?['san'] ?? '$from$to';

    final isCapture = lastMove?['captured'] != null;
    final isCastle =
        (lastMove?['flags'] as String? ?? '').contains('k') ||
        (lastMove?['flags'] as String? ?? '').contains('q');

    final chessMove = ChessMove(
      from: from,
      to: to,
      san: san,
      promotion: promotion,
      capturedPiece:
          (lastMove?['captured'] is chess.PieceType)
              ? (lastMove?['captured'] as chess.PieceType).name
              : null,
      isCapture: isCapture,
      isCheck: board.in_check,
      isCheckmate: board.in_checkmate,
      isCastle: isCastle,
      fen: board.fen,
      evaluation: evaluation,
    );

    final terminal = _terminalResult(board);
    final result = terminal?.result;
    final resultReason = terminal?.reason;

    final updatedSession = currentSession.copyWith(
      fen: board.fen,
      pgn: board.pgn(),
      moveHistory: [...currentSession.moveHistory, chessMove],
      result: result,
      resultReason: resultReason,
      lastMoveTime: DateTime.now(),
      clearAnalysis: true,
      clearSelection: true,
    );

    state = updatedSession;
    await _repository.saveSession(updatedSession);
    if (!_ownsSession(generation, updatedSession)) return false;

    // Record streak activity whenever player plays a move or completes a game
    _ref.read(streakProvider.notifier).recordActivity();

    if (result != null) {
      unawaited(_recordStatisticsIfNeeded(generation).catchError((_) {}));
    } else if (currentSession.gameMode == GameMode.bot &&
        !updatedSession.isPlayerTurn &&
        !_isBotThinking) {
      unawaited(_makeBotMove(generation));
    }

    // Play haptic feedback if enabled. Guarded: the vibration plugin
    // throws MissingPluginException on unsupported devices/emulators,
    // which would otherwise crash the game on every move.
    final settings = _ref.read(settingsProvider);
    if (settings.vibrationEnabled) {
      try {
        if (board.in_checkmate) {
          Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 200]);
        } else if (board.in_check) {
          Vibration.vibrate(pattern: [0, 50, 50, 50]);
        } else if (isCapture) {
          Vibration.vibrate(duration: 50, amplitude: 128);
        } else if (promotion != null) {
          Vibration.vibrate(duration: 80, amplitude: 128);
        } else {
          Vibration.vibrate(duration: 15, amplitude: 64);
        }
      } catch (_) {
        // Haptics unavailable — game continues without feedback.
      }
    }

    return true;
  }

  Future<void> _makeBotMove([int? sessionGeneration]) async {
    final generation = sessionGeneration ?? _sessionGeneration;
    final currentSession = state;
    if (currentSession == null ||
        currentSession.isCompleted ||
        !_ownsSession(generation, currentSession) ||
        _isBotThinking) {
      return;
    }

    _isBotThinking = true;

    // ISSUE-015: Pause the player's chess clock while the engine thinks.
    // Resume after the bot's move is applied and the turn switches back.
    final timerNotifier = _ref.read(timerProvider.notifier);
    timerNotifier.pause();

    try {
      final engineNotifier = _ref.read(engineProvider.notifier);
      BotProfile? botProfile;
      if (currentSession.botId != null) {
        try {
          botProfile = BotProfile.getById(currentSession.botId!);
        } catch (_) {
          botProfile = null;
        }
      }
      final result = await engineNotifier.getBotMove(
        fen: currentSession.fen,
        difficulty: currentSession.difficulty,
        botType: currentSession.botType,
        botProfile: botProfile,
        startingFen: currentSession.startingFen,
        moves: _uciMoves(currentSession),
      );

      if (!_ownsSession(generation, currentSession)) return;
      if (result == null) return;

      if (result.isValid) {
        final (from, to, promotion) = result.parsedMove;
        final eval =
            result.evaluation != null ? result.evaluation! / 100.0 : null;
        await makeMove(
          from,
          to,
          promotion: promotion,
          evaluation: eval,
          sessionGeneration: generation,
        );
        return;
      }

      // The engine reported no legal move (bestmove (none) / 0000) or returned
      // an unparseable move. Reconcile with the board: if the game is over,
      // record the result instead of silently hanging on the bot's turn.
      final session = state;
      if (session == null ||
          session.isCompleted ||
          !_ownsSession(generation, currentSession)) {
        return;
      }

      final board = _reconstructBoard(session);
      final terminal = _terminalResult(board);
      if (terminal != null) {
        debugPrint(
          'ENGINE: No legal move reported; recording game end ($terminal.reason)',
        );
        final updated = session.copyWith(
          result: terminal.result,
          resultReason: terminal.reason,
        );
        state = updated;
        await _repository.saveSession(updated);
        if (!_ownsSession(generation, updated)) return;
        unawaited(_recordStatisticsIfNeeded(generation).catchError((_) {}));
      } else {
        debugPrint(
          'ENGINE: No legal move reported but the board is not terminal; '
          'refusing to play an invalid move.',
        );
      }
    } finally {
      if (_ownsSession(generation, currentSession)) {
        _isBotThinking = false;
        // Resume the timer for the human player's turn (switchTurn was
        // already called by the moveHistory listener in game_screen.dart).
        if (state != null && !state!.isCompleted) {
          timerNotifier.start();
        }
      }
    }
  }

  /// Determine the game result from the board, if the game is over.
  /// Returns `null` when the game is still in progress.
  ({GameResult result, String reason})? _terminalResult(chess.Chess board) {
    if (board.in_checkmate) {
      return (
        result:
            board.turn == chess.Color.WHITE
                ? GameResult.blackWins
                : GameResult.whiteWins,
        reason: 'Checkmate',
      );
    }
    if (board.in_stalemate) {
      return (result: GameResult.draw, reason: 'Stalemate');
    }
    if (board.in_draw) {
      return (
        result: GameResult.draw,
        reason:
            board.insufficient_material
                ? 'Insufficient material'
                : board.in_threefold_repetition
                ? 'Threefold repetition'
                : 'Fifty-move rule',
      );
    }
    return null;
  }

  /// Update timer values
  Future<void> updateTimers(Duration whiteTime, Duration blackTime) async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return;

    final updatedSession = currentSession.copyWith(
      whiteTimeRemaining: whiteTime,
      blackTimeRemaining: blackTime,
    );

    state = updatedSession;
    await _repository.saveSession(updatedSession);
  }

  /// Handle time out
  Future<void> handleTimeout(bool isWhiteTimeout) async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return;

    final updatedSession = currentSession.copyWith(
      result: isWhiteTimeout ? GameResult.blackWins : GameResult.whiteWins,
      resultReason: 'Time out',
      whiteTimeRemaining:
          isWhiteTimeout ? Duration.zero : currentSession.whiteTimeRemaining,
      blackTimeRemaining:
          !isWhiteTimeout ? Duration.zero : currentSession.blackTimeRemaining,
    );

    state = updatedSession;
    await _repository.saveSession(updatedSession);
    unawaited(_recordStatisticsIfNeeded().catchError((_) {}));
  }

  Future<void> resign() async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return;

    final result =
        currentSession.playerColor == PlayerColor.white
            ? GameResult.blackWins
            : GameResult.whiteWins;

    final updatedSession = currentSession.copyWith(
      result: result,
      resultReason: 'Resignation',
    );

    state = updatedSession;
    await _repository.saveSession(updatedSession);
    unawaited(_recordStatisticsIfNeeded().catchError((_) {}));
  }

  Future<void> handleDraw() async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return;

    final updatedSession = currentSession.copyWith(
      result: GameResult.draw,
      resultReason: 'Agreed draw',
    );

    state = updatedSession;
    await _repository.saveSession(updatedSession);
    unawaited(_recordStatisticsIfNeeded().catchError((_) {}));
  }

  Future<void> undoMove() async {
    final currentSession = state;
    if (currentSession == null ||
        currentSession.moveHistory.isEmpty ||
        currentSession.isCompleted) {
      return;
    }

    int historyPopCount = 1;
    if (currentSession.gameMode == GameMode.bot &&
        currentSession.moveHistory.length >= 2) {
      historyPopCount = 2;
    }

    final newHistory = currentSession.moveHistory.sublist(
      0,
      currentSession.moveHistory.length - historyPopCount,
    );
    final board = chess.Chess.fromFEN(currentSession.startingFen);
    for (var move in newHistory) {
      board.move({
        'from': move.from,
        'to': move.to,
        if (move.promotion != null) 'promotion': move.promotion,
      });
    }

    final updatedSession = currentSession.copyWith(
      fen: board.fen,
      pgn: board.pgn(),
      moveHistory: newHistory,
      clearResult: true,
      clearAnalysis: true,
      clearSelection: true,
    );

    state = updatedSession;
    await _repository.saveSession(updatedSession);
  }

  bool selectSquare(String square) {
    var currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return false;
    if (!currentSession.isPlayerTurn) return false;

    if (currentSession.selectedSquare == square) {
      state = currentSession.copyWith(clearSelection: true);
      return false;
    }

    if (currentSession.selectedSquare != null &&
        currentSession.legalMoves.contains(square)) {
      makeMove(currentSession.selectedSquare!, square);
      return true;
    }

    final board = chess.Chess.fromFEN(currentSession.fen);
    final piece = board.get(square);
    if (piece == null) {
      state = currentSession.copyWith(clearSelection: true);
      return false;
    }

    final isWhitePiece = piece.color == chess.Color.WHITE;
    final canMove =
        (currentSession.isWhiteTurn && isWhitePiece) ||
        (!currentSession.isWhiteTurn && !isWhitePiece);

    if (!canMove) {
      state = currentSession.copyWith(clearSelection: true);
      return false;
    }

    final moves = board.moves({'square': square, 'verbose': true});
    final legalSquares = moves.map((m) => (m as Map)['to'] as String).toList();

    state = currentSession.copyWith(
      selectedSquare: square,
      legalMoves: legalSquares,
    );
    return false;
  }

  Future<void> useHint(WidgetRef ref) async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return;

    final engineNotifier = ref.read(engineProvider.notifier);
    final result = await engineNotifier.getHint(
      fen: currentSession.fen,
      startingFen: currentSession.startingFen,
      moves: _uciMoves(currentSession),
    );

    if (result != null && result.isValid) {
      final (from, to, promotion) = result.parsedMove;
      state = currentSession.copyWith(
        hint: ChessMove(
          from: from,
          to: to,
          promotion: promotion,
          san: '',
          isCapture: false,
          isCheck: false,
          isCheckmate: false,
          isCastle: false,
          fen: '',
        ),
        hintDetails: result,
        hintsUsed: currentSession.hintsUsed + 1,
      );
    }
  }

  void clearHint() {
    if (state != null) {
      state = state!.copyWith(clearHint: true);
    }
  }

  void toggleFlip() {
    final currentSession = state;
    if (currentSession != null) {
      final updated = currentSession.copyWith(
        isFlipped: !currentSession.isFlipped,
      );
      state = updated;
      _repository.saveSession(updated);
    }
  }

  Future<void> _recordStatisticsIfNeeded([int? sessionGeneration]) async {
    if (!mounted) return;
    final generation = sessionGeneration ?? _sessionGeneration;
    final currentSession = state;
    if (currentSession == null ||
        !currentSession.isCompleted ||
        currentSession.isRecorded ||
        !_ownsSession(generation, currentSession)) {
      return;
    }
    if (currentSession.gameMode == GameMode.analysis ||
        currentSession.isPuzzle) {
      return;
    }

    final isWhite = currentSession.playerColor == PlayerColor.white;
    final isWin =
        currentSession.result ==
        (isWhite ? GameResult.whiteWins : GameResult.blackWins);
    final isLoss =
        currentSession.result ==
        (isWhite ? GameResult.blackWins : GameResult.whiteWins);
    final isDraw = currentSession.result == GameResult.draw;

    double accuracy = _calculateAccuracy(currentSession);

    final botElo =
        currentSession.botProfile?.elo ?? currentSession.difficulty.elo;

    final statsNotifier = _ref.read(statisticsProvider.notifier);
    await statsNotifier.recordGameResult(
      isWin: isWin,
      isLoss: isLoss,
      isDraw: isDraw,
      botElo: botElo,
      moveCount: currentSession.moveHistory.length,
      gameTimeSeconds:
          DateTime.now().difference(currentSession.startedAt).inSeconds,
    );
    if (!mounted || !_ownsSession(generation, currentSession)) return;

    if (currentSession.gameMode == GameMode.bot) {
      await statsNotifier.recordGameElo(
        botElo: botElo,
        isWin: isWin,
        isLoss: isLoss,
        isDraw: isDraw,
      );
      if (!mounted || !_ownsSession(generation, currentSession)) return;

      if (currentSession.result != null) {
        String botId = currentSession.botId ?? '';
        if (botId.isEmpty) {
          try {
            botId =
                BotProfile.getClosestToElo(currentSession.difficulty.elo).id;
          } catch (_) {
            botId = BotProfile.allBots.first.id;
          }
        }
        await _ref
            .read(botProgressProvider.notifier)
            .recordBotMatch(
              botId: botId,
              result: currentSession.result!,
              isPlayerWhite: isWhite,
              usedTakebacks: false,
              hintsUsed: currentSession.hintsUsed,
            );
        if (currentSession.campaignLevel != null) {
          await _ref
              .read(botProgressProvider.notifier)
              .recordCampaignMatch(
                levelNumber: currentSession.campaignLevel!,
                result: currentSession.result!,
                isPlayerWhite: isWhite,
                usedTakebacks: false,
                hintsUsed: currentSession.hintsUsed,
              );
        }
      }
      if (!mounted || !_ownsSession(generation, currentSession)) return;
    }

    if (isWin && mounted) {
      try {
        _ref
            .read(achievementProvider.notifier)
            .checkWins(difficultyLevel: currentSession.difficulty.level);
      } catch (_) {}
    }

    if (!mounted) return;
    final prevElo = statsNotifier.state.currentGameElo;

    if (!_ownsSession(generation, currentSession)) return;
    final recordedSession = currentSession.copyWith(
      isRecorded: true,
      whiteAccuracy: isWhite ? accuracy : null,
      blackAccuracy: !isWhite ? accuracy : null,
    );
    state = recordedSession;
    await _repository.saveSession(recordedSession);
    if (!mounted || !_ownsSession(generation, currentSession)) return;

    final newElo = statsNotifier.state.currentGameElo;
    if (newElo > prevElo &&
        (newElo % 100 == 0 || (newElo > 1500 && newElo - prevElo > 50))) {
      NotificationService.instance.showRatingMilestone(newElo);
    }
  }

  double _calculateAccuracy(GameSession session) {
    if (session.moveHistory.isEmpty) return EvalConstants.defaultAccuracy;

    final playerIsWhite = session.playerColor == PlayerColor.white;
    double totalAccuracy = 0;
    int movesCount = 0;

    // Derive evalBefore from the preceding move's eval (or 0.0 for the first move).
    // move.evaluation stores the white-relative eval AFTER the move (in pawns).
    for (int i = 0; i < session.moveHistory.length; i++) {
      final isPlayerMove =
          (playerIsWhite && i % 2 == 0) || (!playerIsWhite && i % 2 != 0);
      if (!isPlayerMove) continue;

      final move = session.moveHistory[i];
      if (move.evaluation == null) continue;

      // evalBefore = eval after the preceding move (opponent's move),
      // or 0.0 for the very first move of the game.
      final double? prevEval =
          i > 0 ? session.moveHistory[i - 1].evaluation : null;
      final double evalBefore = prevEval ?? 0.0;
      final double evalAfter = move.evaluation!;

      // Compute accuracy from CPL using the standard formula.
      final accuracy = computeAccuracy(
        evalBefore: evalBefore,
        evalAfter: evalAfter,
        isWhiteMove: playerIsWhite,
      );
      totalAccuracy += accuracy;
      movesCount++;
    }

    if (movesCount == 0) return EvalConstants.defaultAccuracy;

    return (totalAccuracy / movesCount * 10).round() / 10.0;
  }

  void setSession(GameSession session) {
    _sessionGeneration++;
    _activeSessionGeneration = _sessionGeneration;
    _isBotThinking = false;
    state = session;
  }

  /// Resume a game session and trigger bot if it's the bot's turn
  void resumeSession(GameSession session) {
    _sessionGeneration++;
    _activeSessionGeneration = _sessionGeneration;
    _isBotThinking = false;
    state = session;
    if (session.gameMode == GameMode.bot &&
        !session.isPlayerTurn &&
        !session.isCompleted) {
      unawaited(_makeBotMove());
    }
  }

  Future<void> loadSession(String id) async {
    final session = await _repository.getSession(id);
    if (session != null) {
      resumeSession(session);
    }
  }

  /// Get piece at square
  String? getPieceAt(String square) {
    final currentSession = state;
    if (currentSession == null) return null;

    final board = chess.Chess.fromFEN(currentSession.fen);
    final piece = board.get(square);
    if (piece == null) return null;

    final color = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final type = _pieceTypeToChar(piece.type);
    return '$color$type';
  }

  /// Convert piece type to single character
  String _pieceTypeToChar(chess.PieceType type) {
    switch (type) {
      case chess.PieceType.PAWN:
        return 'P';
      case chess.PieceType.KNIGHT:
        return 'N';
      case chess.PieceType.BISHOP:
        return 'B';
      case chess.PieceType.ROOK:
        return 'R';
      case chess.PieceType.QUEEN:
        return 'Q';
      case chess.PieceType.KING:
        return 'K';
      default:
        return 'P';
    }
  }

  /// Check if move needs promotion
  bool needsPromotion(String from, String to) {
    final currentSession = state;
    if (currentSession == null) return false;

    final board = chess.Chess.fromFEN(currentSession.fen);
    final piece = board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;

    final toRank = to[1];
    return toRank == '8' || toRank == '1';
  }

  /// Try to make a move
  Future<bool> tryMove(String from, String to, {String? promotion}) async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return false;

    return await makeMove(from, to, promotion: promotion);
  }

  /// Test-only hook to drive the bot's move pipeline directly.
  @visibleForTesting
  Future<void> triggerBotMoveForTesting() => _makeBotMove();
}
