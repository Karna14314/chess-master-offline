import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/core/constants/app_constants.dart';
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
  bool _isBotThinking = false;

  GameSessionViewModel(this._repository, this._ref) : super(null);

  /// Start a new game
  void startNewGame({
    required PlayerColor playerColor,
    required DifficultyLevel difficulty,
    required TimeControl timeControl,
    GameMode gameMode = GameMode.bot,
    BotType botType = BotType.stockfish,
  }) {
    final session = GameSession.create(
      gameMode: gameMode,
      botType: botType,
      difficulty: difficulty,
      timeControl: timeControl,
      playerColor: playerColor,
    );

    state = session;
    _repository.saveSession(session);

    // If bot is White, it starts the game
    if (gameMode == GameMode.bot && session.playerColor == PlayerColor.black) {
      _makeBotMove();
    }
  }

  /// Make a move
  Future<bool> makeMove(
    String from,
    String to, {
    String? promotion,
    double? evaluation,
  }) async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return false;

    final board = chess.Chess.fromFEN(currentSession.fen);

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

    GameResult? result;
    String? resultReason;

    if (board.in_checkmate) {
      result =
          board.turn == chess.Color.WHITE
              ? GameResult.blackWins
              : GameResult.whiteWins;
      resultReason = 'Checkmate';
    } else if (board.in_stalemate) {
      result = GameResult.draw;
      resultReason = 'Stalemate';
    } else if (board.in_draw) {
      result = GameResult.draw;
      resultReason =
          board.insufficient_material
              ? 'Insufficient material'
              : board.in_threefold_repetition
              ? 'Threefold repetition'
              : 'Fifty-move rule';
    }

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

    if (result != null) {
      _recordStatisticsIfNeeded();
    } else if (currentSession.gameMode == GameMode.bot &&
        !updatedSession.isPlayerTurn &&
        !_isBotThinking) {
      _makeBotMove();
    }

    return true;
  }

  Future<void> _makeBotMove() async {
    final currentSession = state;
    if (currentSession == null || currentSession.isCompleted) return;
    if (_isBotThinking) return;

    _isBotThinking = true;
    try {
      final engineNotifier = _ref.read(engineProvider.notifier);
      final result = await engineNotifier.getBotMove(
        fen: currentSession.fen,
        difficulty: currentSession.difficulty,
        botType: currentSession.botType,
      );

      if (result != null && result.isValid) {
        final (from, to, promotion) = result.parsedMove;
        final eval =
            result.evaluation != null ? result.evaluation! / 100.0 : null;
        await makeMove(from, to, promotion: promotion, evaluation: eval);
      }
    } finally {
      _isBotThinking = false;
    }
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
    _recordStatisticsIfNeeded();
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
    _recordStatisticsIfNeeded();
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
    _recordStatisticsIfNeeded();
  }

  Future<void> undoMove() async {
    final currentSession = state;
    if (currentSession == null ||
        currentSession.moveHistory.isEmpty ||
        currentSession.isCompleted)
      return;

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
    final result = await engineNotifier.getHint(fen: currentSession.fen);

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

  void _recordStatisticsIfNeeded() async {
    final currentSession = state;
    if (currentSession == null ||
        !currentSession.isCompleted ||
        currentSession.isRecorded)
      return;
    if (currentSession.gameMode == GameMode.analysis || currentSession.isPuzzle)
      return;

    final isWhite = currentSession.playerColor == PlayerColor.white;
    final isWin =
        currentSession.result ==
        (isWhite ? GameResult.whiteWins : GameResult.blackWins);
    final isLoss =
        currentSession.result ==
        (isWhite ? GameResult.blackWins : GameResult.whiteWins);
    final isDraw = currentSession.result == GameResult.draw;

    double accuracy = _calculateAccuracy(currentSession);

    final statsNotifier = _ref.read(statisticsProvider.notifier);
    await statsNotifier.recordGameResult(
      isWin: isWin,
      isLoss: isLoss,
      isDraw: isDraw,
      botElo: currentSession.difficulty.elo,
      moveCount: currentSession.moveHistory.length,
      gameTimeSeconds:
          DateTime.now().difference(currentSession.startedAt).inSeconds,
    );

    state = currentSession.copyWith(
      isRecorded: true,
      whiteAccuracy: isWhite ? accuracy : null,
      blackAccuracy: !isWhite ? accuracy : null,
    );
    await _repository.saveSession(state!);
  }

  double _calculateAccuracy(GameSession session) {
    if (session.moveHistory.isEmpty) return 0.0;

    // Calculate Average Centipawn Loss (ACL)
    // For a simple real-time approximation, we use the move evaluations we have
    int totalLoss = 0;
    int movesCount = 0;

    // We only evaluate player's moves
    final playerIsWhite = session.playerColor == PlayerColor.white;

    for (int i = 0; i < session.moveHistory.length; i++) {
      final move = session.moveHistory[i];
      final isPlayerMove =
          (playerIsWhite && i % 2 == 0) || (!playerIsWhite && i % 2 != 0);

      if (isPlayerMove && move.evaluation != null) {
        // Very simplified: assume best was 0.0 and player move is relative to it
        // Real ACL requires knowing the best move eval at that moment
        // For now, we use a mapping based on the stored evaluation
        double absEval = move.evaluation!.abs();
        if (absEval > 3.0)
          totalLoss += 100; // Blunder-ish
        else if (absEval > 1.5)
          totalLoss += 50; // Inaccuracy
        else if (absEval > 0.5)
          totalLoss += 20;
        movesCount++;
      }
    }

    if (movesCount == 0) return 85.0; // Default sensible value

    double acl = totalLoss / movesCount;
    // Formula: 100 * exp(-0.003 * ACL)
    double accuracy = 100 * (1.0 - (acl / 100.0)).clamp(0.0, 1.0);
    return (accuracy * 10).round() / 10.0;
  }

  void setSession(GameSession session) {
    state = session;
  }

  Future<void> loadSession(String id) async {
    final session = await _repository.getSession(id);
    if (session != null) {
      state = session;
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
}
