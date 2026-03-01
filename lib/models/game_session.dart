import 'dart:convert';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess/chess.dart' as chess;

/// Represents a centralized game session and acts as the single source of truth for the game state.
class GameSession {
  final String id;
  final GameMode gameMode;
  final BotType botType;
  final DifficultyLevel difficulty;
  final TimeControl timeControl;
  final Duration whiteTimeRemaining;
  final Duration blackTimeRemaining;
  final PlayerColor playerColor;
  final String whitePlayerName;
  final String blackPlayerName;

  final String fen;
  final String startingFen;
  final String pgn;
  final List<ChessMove> moveHistory;

  // Game session metadata
  final GameResult? result;
  final String? resultReason;
  final DateTime startedAt;
  final DateTime lastMoveTime;

  final bool isPuzzle;
  final String? puzzleId;
  final Map<String, dynamic>? analysisData;
  final bool isFlipped;
  final bool isRecorded;
  final double? whiteAccuracy;
  final double? blackAccuracy;

  // UI State (Not persisted in DB)
  final String? selectedSquare;
  final List<String> legalMoves;
  final ChessMove? hint;
  final int hintsUsed;

  const GameSession({
    required this.id,
    required this.gameMode,
    this.botType = BotType.simple,
    required this.difficulty,
    required this.timeControl,
    required this.whiteTimeRemaining,
    required this.blackTimeRemaining,
    this.playerColor = PlayerColor.white,
    this.whitePlayerName = 'White',
    this.blackPlayerName = 'Black',
    required this.fen,
    required this.startingFen,
    this.pgn = '',
    this.moveHistory = const [],
    this.result,
    this.resultReason,
    required this.startedAt,
    required this.lastMoveTime,
    this.isPuzzle = false,
    this.puzzleId,
    this.analysisData,
    this.isFlipped = false,
    this.isRecorded = false,
    this.whiteAccuracy,
    this.blackAccuracy,
    this.selectedSquare,
    this.legalMoves = const [],
    this.hint,
    this.hintsUsed = 0,
  });

  /// Create a fresh session
  factory GameSession.create({
    required GameMode gameMode,
    BotType botType = BotType.simple,
    DifficultyLevel? difficulty,
    TimeControl? timeControl,
    PlayerColor playerColor = PlayerColor.white,
    String? startingFen,
    bool isPuzzle = false,
    String? puzzleId,
  }) {
    final now = DateTime.now();
    final diff = difficulty ?? AppConstants.difficultyLevels[4];
    final tc = timeControl ?? AppConstants.timeControls[0];

    PlayerColor actualColor = playerColor;
    if (actualColor == PlayerColor.random) {
      actualColor = now.millisecondsSinceEpoch % 2 == 0 ? PlayerColor.white : PlayerColor.black;
    }

    // Determine player names based on game mode
    String whiteName = 'White';
    String blackName = 'Black';

    if (gameMode == GameMode.localMultiplayer) {
      whiteName = 'Player 1';
      blackName = 'Player 2';
    } else if (gameMode == GameMode.bot) {
      if (actualColor == PlayerColor.white) {
        whiteName = 'Player';
        blackName = 'Bot (${diff.elo})';
      } else {
        whiteName = 'Bot (${diff.elo})';
        blackName = 'Player';
      }
    }

    final board =
        startingFen != null ? chess.Chess.fromFEN(startingFen) : chess.Chess();

    return GameSession(
      id: now.millisecondsSinceEpoch.toString(),
      gameMode: gameMode,
      botType: botType,
      difficulty: diff,
      timeControl: tc,
      playerColor: actualColor,
      whitePlayerName: whiteName,
      blackPlayerName: blackName,
      whiteTimeRemaining: tc.initialDuration,
      blackTimeRemaining: tc.initialDuration,
      fen: board.fen,
      startingFen: board.fen,
      startedAt: now,
      lastMoveTime: now,
      isPuzzle: isPuzzle,
      puzzleId: puzzleId,
      isFlipped:
          actualColor == PlayerColor.black, // Default flip for black player
      hintsUsed: 0,
    );
  }

  bool get isWhiteTurn => fen.split(' ')[1] == 'w';
  bool get isBlackTurn => !isWhiteTurn;
  bool get isBot => gameMode == GameMode.bot;
  bool get isLocalMultiplayer => gameMode == GameMode.localMultiplayer;
  bool get isAnalysis => gameMode == GameMode.analysis;

  bool get isPlayerTurn =>
      (playerColor == PlayerColor.white && isWhiteTurn) ||
      (playerColor == PlayerColor.black && !isWhiteTurn) ||
      gameMode == GameMode.localMultiplayer ||
      gameMode == GameMode.analysis ||
      isPuzzle;
  bool get canUndo =>
      moveHistory.isNotEmpty &&
      (gameMode != GameMode.bot || !isPlayerTurn || moveHistory.length > 1);

  bool get isCompleted => result != null;

  GameSession copyWith({
    String? id,
    GameMode? gameMode,
    BotType? botType,
    DifficultyLevel? difficulty,
    TimeControl? timeControl,
    Duration? whiteTimeRemaining,
    Duration? blackTimeRemaining,
    PlayerColor? playerColor,
    String? whitePlayerName,
    String? blackPlayerName,
    String? fen,
    String? startingFen,
    String? pgn,
    List<ChessMove>? moveHistory,
    GameResult? result,
    String? resultReason,
    DateTime? startedAt,
    DateTime? lastMoveTime,
    bool? isPuzzle,
    String? puzzleId,
    Map<String, dynamic>? analysisData,
    bool clearResult = false,
    bool clearAnalysis = false,
    bool clearSelection = false,
    bool clearHint = false,
    bool? isFlipped,
    bool? isRecorded,
    double? whiteAccuracy,
    double? blackAccuracy,
    String? selectedSquare,
    List<String>? legalMoves,
    ChessMove? hint,
    int? hintsUsed,
  }) {
    return GameSession(
      id: id ?? this.id,
      gameMode: gameMode ?? this.gameMode,
      botType: botType ?? this.botType,
      difficulty: difficulty ?? this.difficulty,
      timeControl: timeControl ?? this.timeControl,
      whiteTimeRemaining: whiteTimeRemaining ?? this.whiteTimeRemaining,
      blackTimeRemaining: blackTimeRemaining ?? this.blackTimeRemaining,
      playerColor: playerColor ?? this.playerColor,
      whitePlayerName: whitePlayerName ?? this.whitePlayerName,
      blackPlayerName: blackPlayerName ?? this.blackPlayerName,
      fen: fen ?? this.fen,
      startingFen: startingFen ?? this.startingFen,
      pgn: pgn ?? this.pgn,
      moveHistory: moveHistory ?? this.moveHistory,
      result: clearResult ? null : (result ?? this.result),
      resultReason: clearResult ? null : (resultReason ?? this.resultReason),
      startedAt: startedAt ?? this.startedAt,
      lastMoveTime: lastMoveTime ?? this.lastMoveTime,
      isPuzzle: isPuzzle ?? this.isPuzzle,
      puzzleId: puzzleId ?? this.puzzleId,
      analysisData: clearAnalysis ? null : (analysisData ?? this.analysisData),
      isFlipped: isFlipped ?? this.isFlipped,
      isRecorded: isRecorded ?? this.isRecorded,
      whiteAccuracy: whiteAccuracy ?? this.whiteAccuracy,
      blackAccuracy: blackAccuracy ?? this.blackAccuracy,
      selectedSquare:
          clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? const [] : (legalMoves ?? this.legalMoves),
      hint: clearHint ? null : (hint ?? this.hint),
      hintsUsed: hintsUsed ?? this.hintsUsed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameMode': gameMode.index,
      'botType': botType.index,
      'difficultyLevel': difficulty.level,
      'timeControlMinutes': timeControl.minutes,
      'timeControlIncrement': timeControl.increment,
      'whiteTimeRemainingMs': whiteTimeRemaining.inMilliseconds,
      'blackTimeRemainingMs': blackTimeRemaining.inMilliseconds,
      'playerColor': playerColor.index,
      'whitePlayerName': whitePlayerName,
      'blackPlayerName': blackPlayerName,
      'fen': fen,
      'startingFen': startingFen,
      'pgn': pgn,
      'moveHistory': jsonEncode(moveHistory.map((m) => m.toJson()).toList()),
      'result': result?.name,
      'resultReason': resultReason,
      'startedAtMs': startedAt.millisecondsSinceEpoch,
      'lastMoveTimeMs': lastMoveTime.millisecondsSinceEpoch,
      'isPuzzle': isPuzzle ? 1 : 0,
      'puzzleId': puzzleId,
      'analysisData': analysisData != null ? jsonEncode(analysisData) : null,
      'isFlipped': isFlipped ? 1 : 0,
      'isRecorded': isRecorded ? 1 : 0,
      'whiteAccuracy': whiteAccuracy,
      'blackAccuracy': blackAccuracy,
      'hintsUsed': hintsUsed,
    };
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    // Parse time control
    final tcMinutes = map['timeControlMinutes'] as int? ?? 0;
    final tcIncrement = map['timeControlIncrement'] as int? ?? 0;
    final tc = AppConstants.timeControls.firstWhere(
      (tc) => tc.minutes == tcMinutes && tc.increment == tcIncrement,
      orElse:
          () => TimeControl(
            name: 'Custom',
            minutes: tcMinutes,
            increment: tcIncrement,
          ),
    );

    // Parse difficulty
    final diffLevel = map['difficultyLevel'] as int? ?? 5;
    final diff = AppConstants.difficultyLevels.firstWhere(
      (d) => d.level == diffLevel,
      orElse: () => AppConstants.difficultyLevels[4], // Default to level 5
    );

    // Parse move history
    List<ChessMove> history = [];
    if (map['moveHistory'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(map['moveHistory'] as String);
        history =
            decoded
                .map((item) => ChessMove.fromJson(item as Map<String, dynamic>))
                .toList();
      } catch (e) {
        // Fallback for invalid history
      }
    }

    GameResult? parsedResult;
    if (map['result'] != null) {
      final rName = map['result'] as String;
      parsedResult = GameResult.values.cast<GameResult?>().firstWhere(
        (e) => e?.name == rName,
        orElse: () => null,
      );
    }

    return GameSession(
      id: map['id'] as String,
      gameMode: GameMode.values[map['gameMode'] as int? ?? 0],
      botType: BotType.values[map['botType'] as int? ?? 0],
      difficulty: diff,
      timeControl: tc,
      whiteTimeRemaining: Duration(
        milliseconds: map['whiteTimeRemainingMs'] as int? ?? 0,
      ),
      blackTimeRemaining: Duration(
        milliseconds: map['blackTimeRemainingMs'] as int? ?? 0,
      ),
      playerColor: PlayerColor.values[map['playerColor'] as int? ?? 0],
      whitePlayerName: map['whitePlayerName'] as String? ?? 'White',
      blackPlayerName: map['blackPlayerName'] as String? ?? 'Black',
      fen: map['fen'] as String? ?? '',
      startingFen:
          map['startingFen'] as String? ?? (map['fen'] as String? ?? ''),
      pgn: map['pgn'] as String? ?? '',
      moveHistory: history,
      result: parsedResult,
      resultReason: map['resultReason'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['startedAtMs'] as int? ?? 0,
      ),
      lastMoveTime: DateTime.fromMillisecondsSinceEpoch(
        map['lastMoveTimeMs'] as int? ?? 0,
      ),
      isPuzzle: (map['isPuzzle'] as int? ?? 0) == 1,
      puzzleId: map['puzzleId'] as String?,
      analysisData:
          map['analysisData'] != null
              ? jsonDecode(map['analysisData'] as String)
              : null,
      isFlipped: (map['isFlipped'] as int? ?? 0) == 1,
      isRecorded: (map['isRecorded'] as int? ?? 0) == 1,
      whiteAccuracy: (map['whiteAccuracy'] as num?)?.toDouble(),
      blackAccuracy: (map['blackAccuracy'] as num?)?.toDouble(),
      hintsUsed: map['hintsUsed'] as int? ?? 0,
    );
  }
}
