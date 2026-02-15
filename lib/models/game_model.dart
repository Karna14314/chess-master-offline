import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/constants/app_constants.dart';

/// Represents a chess move with metadata
class ChessMove {
  final String from;
  final String to;
  final String san; // Standard Algebraic Notation
  final String? promotion;
  final String? capturedPiece; // The captured piece type (p, n, b, r, q)
  final bool isCapture;
  final bool isCheck;
  final bool isCheckmate;
  final bool isCastle;
  final String fen; // Position after the move

  const ChessMove({
    required this.from,
    required this.to,
    required this.san,
    this.promotion,
    this.capturedPiece,
    required this.isCapture,
    required this.isCheck,
    required this.isCheckmate,
    required this.isCastle,
    required this.fen,
  });

  /// Create from chess package move
  factory ChessMove.fromChessMove(chess.Move move, chess.Chess game) {
    return ChessMove(
      from: move.fromAlgebraic,
      to: move.toAlgebraic,
      san: game.move_to_san(move),
      promotion: move.promotion?.name,
      capturedPiece: move.captured?.name,
      isCapture: move.captured != null,
      isCheck: game.in_check,
      isCheckmate: game.in_checkmate,
      isCastle:
          move.flags & chess.Chess.BITS_KSIDE_CASTLE != 0 ||
          move.flags & chess.Chess.BITS_QSIDE_CASTLE != 0,
      fen: game.fen,
    );
  }

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'san': san,
    'promotion': promotion,
    'capturedPiece': capturedPiece,
    'isCapture': isCapture,
    'isCheck': isCheck,
    'isCheckmate': isCheckmate,
    'isCastle': isCastle,
    'fen': fen,
  };

  factory ChessMove.fromJson(Map<String, dynamic> json) => ChessMove(
    from: json['from'],
    to: json['to'],
    san: json['san'],
    promotion: json['promotion'],
    capturedPiece: json['capturedPiece'],
    isCapture: json['isCapture'],
    isCheck: json['isCheck'],
    isCheckmate: json['isCheckmate'],
    isCastle: json['isCastle'],
    fen: json['fen'],
  );
}

/// Game state enumeration
enum GameStatus { setup, active, paused, finished }

/// Represents the current game state
class GameState {
  final String id;
  final chess.Chess board;
  final List<ChessMove> moveHistory;
  final GameStatus status;
  final PlayerColor playerColor;
  final DifficultyLevel difficulty;
  final TimeControl timeControl;
  final GameMode gameMode;
  final bool allowTakeback;
  final int hintsUsed;
  final String? selectedSquare;
  final List<String> legalMoves;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final GameResult? result;
  final String? resultReason;
  final Duration whiteTime;
  final Duration blackTime;
  final DateTime? startedAt;
  final String? openingName;
  final ChessMove? hint;
  final ChessMove? bestMove;

  GameState({
    required this.id,
    required this.board,
    this.moveHistory = const [],
    this.status = GameStatus.setup,
    this.playerColor = PlayerColor.white,
    DifficultyLevel? difficulty,
    TimeControl? timeControl,
    this.gameMode = GameMode.bot,
    this.allowTakeback = true,
    this.hintsUsed = 0,
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.result,
    this.resultReason,
    this.whiteTime = Duration.zero,
    this.blackTime = Duration.zero,
    this.startedAt,
    this.openingName,
    this.hint,
    this.bestMove,
  }) : difficulty = difficulty ?? AppConstants.difficultyLevels[4],
       timeControl = timeControl ?? AppConstants.timeControls[0];

  /// Create initial game state
  factory GameState.initial() {
    return GameState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      board: chess.Chess(),
    );
  }

  /// Create from FEN string
  factory GameState.fromFen(String fen) {
    return GameState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      board: chess.Chess.fromFEN(fen),
    );
  }

  /// Current position as FEN
  String get fen => board.fen;

  /// Is it white's turn
  bool get isWhiteTurn => board.turn == chess.Color.WHITE;

  /// Is local multiplayer mode
  bool get isLocalMultiplayer => gameMode == GameMode.localMultiplayer;

  /// Is it the player's turn (in local multiplayer, always true since both players use same device)
  bool get isPlayerTurn {
    if (isLocalMultiplayer)
      return true; // Both players take turns on same device
    if (playerColor == PlayerColor.white) {
      return isWhiteTurn;
    } else if (playerColor == PlayerColor.black) {
      return !isWhiteTurn;
    }
    return true; // Random color - shouldn't happen during active game
  }

  /// Is the game in check
  bool get inCheck => board.in_check;

  /// Is the game in checkmate
  bool get inCheckmate => board.in_checkmate;

  /// Is the game in stalemate
  bool get inStalemate => board.in_stalemate;

  /// Is the game a draw
  bool get inDraw => board.in_draw;

  /// Is game over
  bool get isGameOver => board.game_over;

  /// Current move number
  int get moveNumber => (moveHistory.length ~/ 2) + 1;

  /// Full move count
  int get fullMoveCount => moveHistory.length;

  /// Can request hint (only in bot mode)
  bool get canRequestHint => !isLocalMultiplayer;

  /// Can undo move
  bool get canUndo =>
      moveHistory.isNotEmpty && status == GameStatus.active && allowTakeback;

  /// Copy with new values
  GameState copyWith({
    String? id,
    chess.Chess? board,
    List<ChessMove>? moveHistory,
    GameStatus? status,
    PlayerColor? playerColor,
    DifficultyLevel? difficulty,
    TimeControl? timeControl,
    GameMode? gameMode,
    bool? allowTakeback,
    int? hintsUsed,
    String? selectedSquare,
    List<String>? legalMoves,
    String? lastMoveFrom,
    String? lastMoveTo,
    GameResult? result,
    String? resultReason,
    Duration? whiteTime,
    Duration? blackTime,
    DateTime? startedAt,
    String? openingName,
    ChessMove? hint,
    ChessMove? bestMove,
    bool clearSelection = false,
    bool clearResult = false,
  }) {
    return GameState(
      id: id ?? this.id,
      board: board ?? this.board,
      moveHistory: moveHistory ?? this.moveHistory,
      status: status ?? this.status,
      playerColor: playerColor ?? this.playerColor,
      difficulty: difficulty ?? this.difficulty,
      timeControl: timeControl ?? this.timeControl,
      gameMode: gameMode ?? this.gameMode,
      allowTakeback: allowTakeback ?? this.allowTakeback,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      selectedSquare:
          clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? [] : (legalMoves ?? this.legalMoves),
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      result: clearResult ? null : (result ?? this.result),
      resultReason: clearResult ? null : (resultReason ?? this.resultReason),
      whiteTime: whiteTime ?? this.whiteTime,
      blackTime: blackTime ?? this.blackTime,
      startedAt: startedAt ?? this.startedAt,
      openingName: openingName ?? this.openingName,
      hint: hint ?? this.hint,
      bestMove: bestMove ?? this.bestMove,
    );
  }
}

/// Saved game model for database
class SavedGame {
  final int? id;
  final String name;
  final String pgn;
  final String? fenStart;
  final String result;
  final String playerColor;
  final int botElo;
  final String? timeControl;
  final DateTime createdAt;
  final int durationSeconds;
  final int moveCount;
  final bool isSaved;
  final String? openingName;

  const SavedGame({
    this.id,
    required this.name,
    required this.pgn,
    this.fenStart,
    required this.result,
    required this.playerColor,
    required this.botElo,
    this.timeControl,
    required this.createdAt,
    required this.durationSeconds,
    required this.moveCount,
    this.isSaved = false,
    this.openingName,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pgn': pgn,
    'fen_start': fenStart,
    'result': result,
    'player_color': playerColor,
    'bot_elo': botElo,
    'time_control': timeControl,
    'created_at': createdAt.millisecondsSinceEpoch,
    'duration_seconds': durationSeconds,
    'move_count': moveCount,
    'is_saved': isSaved ? 1 : 0,
    'opening_name': openingName,
  };

  factory SavedGame.fromMap(Map<String, dynamic> map) => SavedGame(
    id: map['id'],
    name: map['name'],
    pgn: map['pgn'],
    fenStart: map['fen_start'],
    result: map['result'],
    playerColor: map['player_color'],
    botElo: map['bot_elo'],
    timeControl: map['time_control'],
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    durationSeconds: map['duration_seconds'],
    moveCount: map['move_count'],
    isSaved: map['is_saved'] == 1,
    openingName: map['opening_name'],
  );
}
