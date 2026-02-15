import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'dart:math';

/// Provider for the game state
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});

/// Game state notifier managing chess game logic
class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(GameState.initial());

  /// Start a new game with settings
  void startNewGame({
    required PlayerColor playerColor,
    required DifficultyLevel difficulty,
    required TimeControl timeControl,
    GameMode gameMode = GameMode.bot,
    bool allowTakeback = true,
    bool showHints = true,
    bool useTimer = true,
    String? startingFen,
  }) {
    // Handle random color selection
    final actualColor =
        playerColor == PlayerColor.random
            ? (Random().nextBool() ? PlayerColor.white : PlayerColor.black)
            : playerColor;

    final board =
        startingFen != null ? chess.Chess.fromFEN(startingFen) : chess.Chess();

    state = GameState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      board: board,
      status: GameStatus.active,
      playerColor: actualColor,
      difficulty: difficulty,
      timeControl:
          useTimer
              ? timeControl
              : AppConstants.timeControls.firstWhere(
                (tc) => tc.minutes == 0,
                orElse:
                    () => const TimeControl(
                      name: 'No Timer',
                      minutes: 0,
                      increment: 0,
                    ),
              ),
      gameMode: gameMode,
      allowTakeback: allowTakeback,
      hintsUsed: 0,
      whiteTime: timeControl.initialDuration,
      blackTime: timeControl.initialDuration,
      startedAt: DateTime.now(),
    );
  }

  /// Select a square on the board
  bool selectSquare(String square) {
    if (state.status != GameStatus.active) return false;
    if (!state.isPlayerTurn) return false;

    // If clicking on already selected square, deselect
    if (state.selectedSquare == square) {
      state = state.copyWith(clearSelection: true);
      return false;
    }

    // If a square is already selected and this is a legal move, make the move
    if (state.selectedSquare != null && state.legalMoves.contains(square)) {
      _makeMove(state.selectedSquare!, square);
      return true;
    }

    // Check if this square has a piece we can move
    final piece = state.board.get(square);
    if (piece == null) {
      state = state.copyWith(clearSelection: true);
      return false;
    }

    // Check if the piece belongs to the current player
    final isWhitePiece = piece.color == chess.Color.WHITE;
    final canMove =
        (state.isWhiteTurn && isWhitePiece) ||
        (!state.isWhiteTurn && !isWhitePiece);

    if (!canMove) {
      state = state.copyWith(clearSelection: true);
      return false;
    }

    // Get legal moves for this piece
    final moves = state.board.moves({'square': square, 'verbose': true});
    final legalSquares = moves.map((m) => (m as Map)['to'] as String).toList();

    state = state.copyWith(
      selectedSquare: square,
      legalMoves: legalSquares.cast<String>(),
    );
    return false;
  }

  /// Make a move from one square to another
  void _makeMove(String from, String to, {String? promotion}) {
    final board = state.board.copy();

    // Check if this is a pawn promotion
    final piece = board.get(from);
    final isPromotion =
        piece?.type == chess.PieceType.PAWN &&
        ((piece?.color == chess.Color.WHITE && to[1] == '8') ||
            (piece?.color == chess.Color.BLACK && to[1] == '1'));

    // Default promotion to queen if not specified
    final promotionPiece = isPromotion ? (promotion ?? 'q') : null;

    // Build the move string for SAN generation
    final moveMap = {
      'from': from,
      'to': to,
      if (promotionPiece != null) 'promotion': promotionPiece,
    };

    // Get the move in SAN format before making the move
    // The move() method returns bool and mutates the board
    final moveSuccess = board.move(moveMap);

    if (!moveSuccess) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    // Get the last move from history to extract details
    final history = board.getHistory({'verbose': true});
    final lastMove = history.isNotEmpty ? history.last as Map : null;

    // Get SAN from the board's move history
    final sanHistory = board.getHistory();
    final san = sanHistory.isNotEmpty ? sanHistory.last.toString() : '$from$to';

    final captured = lastMove?['captured'];
    final isCapture = captured != null;
    final capturedPieceName =
        captured is chess.PieceType ? captured.name : null;

    final isCastle =
        lastMove?['flags']?.toString().contains('k') == true ||
        lastMove?['flags']?.toString().contains('q') == true;

    // Create move record
    final chessMove = ChessMove(
      from: from,
      to: to,
      san: san,
      promotion: promotionPiece,
      capturedPiece: capturedPieceName,
      isCapture: isCapture,
      isCheck: board.in_check,
      isCheckmate: board.in_checkmate,
      isCastle: isCastle,
      fen: board.fen,
    );

    // Check for game over conditions
    GameResult? result;
    String? resultReason;
    GameStatus status = GameStatus.active;

    if (board.in_checkmate) {
      result =
          board.turn == chess.Color.WHITE
              ? GameResult.blackWins
              : GameResult.whiteWins;
      resultReason = 'Checkmate';
      status = GameStatus.finished;
    } else if (board.in_stalemate) {
      result = GameResult.draw;
      resultReason = 'Stalemate';
      status = GameStatus.finished;
    } else if (board.in_draw) {
      result = GameResult.draw;
      if (board.insufficient_material) {
        resultReason = 'Insufficient material';
      } else if (board.in_threefold_repetition) {
        resultReason = 'Threefold repetition';
      } else {
        resultReason = 'Fifty-move rule';
      }
      status = GameStatus.finished;
    }

    state = state.copyWith(
      board: board,
      moveHistory: [...state.moveHistory, chessMove],
      status: status,
      lastMoveFrom: from,
      lastMoveTo: to,
      result: result,
      resultReason: resultReason,
      clearSelection: true,
    );
  }

  /// Make a move (public method for drag and drop)
  bool tryMove(String from, String to, {String? promotion}) {
    if (state.status != GameStatus.active) return false;
    if (!state.isPlayerTurn) return false;

    final moves = state.board.moves({'square': from, 'verbose': true});
    final isLegal = moves.any((m) => (m as Map)['to'] == to);

    if (!isLegal) return false;

    _makeMove(from, to, promotion: promotion);
    return true;
  }

  /// Apply a bot move (called after engine returns a move)
  void applyBotMove(String from, String to, {String? promotion}) {
    if (state.status != GameStatus.active) return;
    if (state.isPlayerTurn) return;

    _makeMove(from, to, promotion: promotion);
  }

  /// Undo the last move
  void undoMove() {
    if (!state.canUndo) return;

    final board = state.board.copy();
    int movesToUndo = 1;

    // If playing against bot and it's player's turn (meaning last move was bot's),
    // we undo twice to go back to before player's move.
    if (state.gameMode == GameMode.bot &&
        state.isPlayerTurn &&
        state.moveHistory.length >= 2) {
      movesToUndo = 2;
    }

    for (int i = 0; i < movesToUndo; i++) {
      board.undo();
    }

    // Rebuild move history
    final newHistoryLength = state.moveHistory.length - movesToUndo;
    final newHistory =
        newHistoryLength > 0
            ? state.moveHistory.sublist(0, newHistoryLength)
            : <ChessMove>[];

    final lastMove = newHistory.isNotEmpty ? newHistory.last : null;

    state = state.copyWith(
      board: board,
      moveHistory: newHistory,
      lastMoveFrom: lastMove?.from,
      lastMoveTo: lastMove?.to,
      clearSelection: true,
      clearResult: true,
      status: GameStatus.active,
    );
  }

  /// Request a hint
  Future<void> useHint(WidgetRef ref) async {
    if (!state.canRequestHint) return;

    final engineNotifier = ref.read(engineProvider.notifier);
    final result = await engineNotifier.getHint(fen: state.fen);

    if (result != null && result.isValid) {
      final (from, to, promotion) = result.parsedMove;

      // Check for capture (simple check, may miss en passant)
      final targetPiece = state.board.get(to);
      final capturedPieceName =
          targetPiece != null ? targetPiece.type.name : null;

      final move = ChessMove(
        from: from,
        to: to,
        promotion: promotion,
        san: '', // SAN is not available from the engine
        capturedPiece: capturedPieceName,
        isCapture: targetPiece != null,
        isCheck: false,
        isCheckmate: false,
        isCastle: false,
        fen: '',
      );
      state = state.copyWith(hint: move, hintsUsed: state.hintsUsed + 1);
    }
  }

  /// Clear the hint
  void clearHint() {
    state = state.copyWith(hint: null);
  }

  /// Resign the game
  void resign() {
    if (state.status != GameStatus.active) return;

    final result =
        state.playerColor == PlayerColor.white
            ? GameResult.blackWins
            : GameResult.whiteWins;

    state = state.copyWith(
      status: GameStatus.finished,
      result: result,
      resultReason: 'Resignation',
    );
  }

  /// Offer a draw (auto-accept for bot games)
  void offerDraw() {
    if (state.status != GameStatus.active) return;

    // For MVP, bot always accepts draw offers
    state = state.copyWith(
      status: GameStatus.finished,
      result: GameResult.draw,
      resultReason: 'Draw agreed',
    );
  }

  /// Pause the game
  void pauseGame() {
    if (state.status != GameStatus.active) return;
    state = state.copyWith(status: GameStatus.paused);
  }

  /// Resume the game
  void resumeGame() {
    if (state.status != GameStatus.paused) return;
    state = state.copyWith(status: GameStatus.active);
  }

  /// Update timer
  void updateTime({Duration? whiteTime, Duration? blackTime}) {
    state = state.copyWith(
      whiteTime: whiteTime ?? state.whiteTime,
      blackTime: blackTime ?? state.blackTime,
    );
  }

  /// Handle time out
  void handleTimeout(bool isWhite) {
    if (state.status != GameStatus.active) return;

    state = state.copyWith(
      status: GameStatus.finished,
      result: isWhite ? GameResult.blackWins : GameResult.whiteWins,
      resultReason: 'Time out',
    );
  }

  /// Reset to initial state
  void reset() {
    state = GameState.initial();
  }

  /// Validate that the board displays the correct starting position
  bool validateStartingPosition() {
    if (state.moveHistory.isNotEmpty) return false;

    // Check that we have the standard starting FEN
    const startingFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    return state.fen == startingFen;
  }

  /// Validate that all 32 pieces are correctly placed (for any position)
  bool validateAllPiecesPlaced() {
    int pieceCount = 0;

    // Check all squares for pieces
    for (int rank = 1; rank <= 8; rank++) {
      for (String file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        final square = '$file$rank';
        final piece = state.board.get(square);
        if (piece != null) {
          pieceCount++;
        }
      }
    }

    // Should have exactly 32 pieces in starting position, or fewer if captures occurred
    return pieceCount <= 32 && pieceCount >= 2; // At least 2 kings must remain
  }

  /// Validate that all 32 pieces are in starting position specifically
  bool validateStartingPieceCount() {
    if (state.moveHistory.isNotEmpty) return false;

    int pieceCount = 0;
    for (int rank = 1; rank <= 8; rank++) {
      for (String file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        final square = '$file$rank';
        final piece = state.board.get(square);
        if (piece != null) {
          pieceCount++;
        }
      }
    }

    return pieceCount == 32;
  }

  /// Validate specific piece placements in starting position
  bool validatePiecePlacements() {
    if (state.moveHistory.isNotEmpty) return false;

    // White pieces
    final whitePieces = {
      'a1': chess.PieceType.ROOK,
      'b1': chess.PieceType.KNIGHT,
      'c1': chess.PieceType.BISHOP,
      'd1': chess.PieceType.QUEEN,
      'e1': chess.PieceType.KING,
      'f1': chess.PieceType.BISHOP,
      'g1': chess.PieceType.KNIGHT,
      'h1': chess.PieceType.ROOK,
    };

    // Black pieces
    final blackPieces = {
      'a8': chess.PieceType.ROOK,
      'b8': chess.PieceType.KNIGHT,
      'c8': chess.PieceType.BISHOP,
      'd8': chess.PieceType.QUEEN,
      'e8': chess.PieceType.KING,
      'f8': chess.PieceType.BISHOP,
      'g8': chess.PieceType.KNIGHT,
      'h8': chess.PieceType.ROOK,
    };

    // Check white pieces
    for (final entry in whitePieces.entries) {
      final piece = state.board.get(entry.key);
      if (piece == null ||
          piece.type != entry.value ||
          piece.color != chess.Color.WHITE) {
        return false;
      }
    }

    // Check black pieces
    for (final entry in blackPieces.entries) {
      final piece = state.board.get(entry.key);
      if (piece == null ||
          piece.type != entry.value ||
          piece.color != chess.Color.BLACK) {
        return false;
      }
    }

    // Check pawns
    for (String file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
      // White pawns on rank 2
      final whitePawn = state.board.get('${file}2');
      if (whitePawn == null ||
          whitePawn.type != chess.PieceType.PAWN ||
          whitePawn.color != chess.Color.WHITE) {
        return false;
      }

      // Black pawns on rank 7
      final blackPawn = state.board.get('${file}7');
      if (blackPawn == null ||
          blackPawn.type != chess.PieceType.PAWN ||
          blackPawn.color != chess.Color.BLACK) {
        return false;
      }
    }

    return true;
  }

  /// Comprehensive board display validation
  bool validateBoardDisplay() {
    return validateStartingPosition() &&
        validateStartingPieceCount() &&
        validatePiecePlacements();
  }

  /// Get piece at square
  String? getPieceAt(String square) {
    final piece = state.board.get(square);
    if (piece == null) return null;

    final color = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final type = piece.type.name.toUpperCase();
    return '$color$type';
  }

  /// Check if square has a legal move indicator
  bool isLegalMoveSquare(String square) {
    return state.legalMoves.contains(square);
  }

  /// Check if square has piece that can be captured
  bool isCapturableSquare(String square) {
    if (!isLegalMoveSquare(square)) return false;
    return state.board.get(square) != null;
  }

  /// Check if we need to show promotion dialog
  bool needsPromotion(String from, String to) {
    final piece = state.board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;

    final isWhite = piece.color == chess.Color.WHITE;
    return (isWhite && to[1] == '8') || (!isWhite && to[1] == '1');
  }

  /// Get all legal moves for current position
  List<Map<String, String>> getAllLegalMoves() {
    final moves = state.board.moves({'verbose': true});
    return moves.map((m) {
      final move = m as Map;
      return {
        'from': move['from'] as String,
        'to': move['to'] as String,
        if (move['promotion'] != null) 'promotion': move['promotion'] as String,
      };
    }).toList();
  }
}
