import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/stockfish_service.dart' as stockfish;
import 'package:chess_master/core/services/basic_evaluator_service.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Provider for analysis state
final analysisProvider = StateNotifierProvider<AnalysisNotifier, AnalysisState>(
  (ref) {
    return AnalysisNotifier();
  },
);

/// Analysis state
class AnalysisState {
  final bool isAnalyzing;
  final int currentMoveIndex;
  final List<MoveAnalysis> analyzedMoves;
  final GameAnalysis? fullAnalysis;
  final chess.Chess? board;
  final List<ChessMove> originalMoves;
  final String? selectedSquare;
  final List<String> legalMoves;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final double currentEval;
  final List<EngineLine> currentEngineLines;
  final String? bestMove;
  final String? errorMessage;
  final double analysisProgress;
  final bool isLiveAnalysis;
  final String startingFen;
  final String? gameId;

  const AnalysisState({
    this.isAnalyzing = false,
    this.currentMoveIndex = -1,
    this.analyzedMoves = const [],
    this.fullAnalysis,
    this.board,
    this.originalMoves = const [],
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.currentEval = 0.0,
    this.currentEngineLines = const [],
    this.bestMove,
    this.errorMessage,
    this.analysisProgress = 0.0,
    this.isLiveAnalysis = true,
    this.startingFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.gameId,
  });

  AnalysisState copyWith({
    bool? isAnalyzing,
    int? currentMoveIndex,
    List<MoveAnalysis>? analyzedMoves,
    GameAnalysis? fullAnalysis,
    chess.Chess? board,
    List<ChessMove>? originalMoves,
    String? selectedSquare,
    List<String>? legalMoves,
    String? lastMoveFrom,
    String? lastMoveTo,
    double? currentEval,
    List<EngineLine>? currentEngineLines,
    String? bestMove,
    String? errorMessage,
    double? analysisProgress,
    bool? isLiveAnalysis,
    String? startingFen,
    String? gameId,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return AnalysisState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      analyzedMoves: analyzedMoves ?? this.analyzedMoves,
      fullAnalysis: fullAnalysis ?? this.fullAnalysis,
      board: board ?? this.board,
      originalMoves: originalMoves ?? this.originalMoves,
      selectedSquare:
          clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? [] : (legalMoves ?? this.legalMoves),
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      currentEval: currentEval ?? this.currentEval,
      currentEngineLines: currentEngineLines ?? this.currentEngineLines,
      bestMove: bestMove ?? this.bestMove,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      analysisProgress: analysisProgress ?? this.analysisProgress,
      isLiveAnalysis: isLiveAnalysis ?? this.isLiveAnalysis,
      startingFen: startingFen ?? this.startingFen,
      gameId: gameId ?? this.gameId,
    );
  }

  /// Current FEN position
  String get fen => board?.fen ?? startingFen;

  /// Is white's turn
  bool get isWhiteTurn => board?.turn == chess.Color.WHITE;

  /// Total moves count
  int get totalMoves => originalMoves.length;

  /// Can go to previous move
  bool get canGoPrevious => currentMoveIndex >= 0;

  /// Can go to next move
  bool get canGoNext => currentMoveIndex < originalMoves.length - 1;

  /// Current move if any
  ChessMove? get currentMove {
    if (currentMoveIndex < 0 || currentMoveIndex >= originalMoves.length)
      return null;
    return originalMoves[currentMoveIndex];
  }

  /// Current move analysis if available
  MoveAnalysis? get currentMoveAnalysis {
    if (currentMoveIndex < 0 || currentMoveIndex >= analyzedMoves.length)
      return null;
    return analyzedMoves[currentMoveIndex];
  }

  /// Get piece at square
  String? getPieceAt(String square) {
    if (board == null) return null;
    final piece = board!.get(square);
    if (piece == null) return null;

    final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final pieceChar = piece.type.name.toUpperCase();
    return '$colorPrefix$pieceChar';
  }

  /// Get all evaluations for graphing
  List<double> get evaluations {
    if (analyzedMoves.isEmpty) return [currentEval];
    List<double> evals = [analyzedMoves.first.evalBefore];
    for (final move in analyzedMoves) {
      evals.add(move.evalAfter);
    }
    return evals;
  }
}

/// Analysis notifier managing game analysis
class AnalysisNotifier extends StateNotifier<AnalysisState> {
  stockfish.StockfishService? _stockfish;
  final DatabaseService _db = DatabaseService.instance;
  bool _isInitialized = false;
  bool _isAnalyzing = false; // Guard flag to prevent concurrent analysis
  int _analysisToken = 0; // Cancellation token for analyzeFullGame

  @visibleForTesting
  int stateUpdateCount = 0;

  AnalysisNotifier([this._stockfish]) : super(const AnalysisState());

  /// Initialize engine for analysis
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _stockfish ??= stockfish.StockfishService.instance;
      await _stockfish!.initialize();
      _isInitialized = true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to initialize analysis engine: $e',
      );
    }
  }

  /// Load a game for analysis
  Future<void> loadGame({
    required List<ChessMove> moves,
    String startingFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  }) async {
    final board = chess.Chess.fromFEN(startingFen);

    state = state.copyWith(
      originalMoves: moves,
      board: board,
      currentMoveIndex: -1,
      analyzedMoves: [],
      fullAnalysis: null,
      startingFen: startingFen,
      currentEval: 0.0,
      currentEngineLines: [],
      bestMove: null,
      clearSelection: true,
      clearError: true,
    );

    // Start live analysis if engine is ready
    if (_isInitialized) {
      await _analyzeCurrentPosition();
    }
  }

  /// Navigate to a specific move index
  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

    // Cancel any running analysis
    _analysisToken++;
    // Give the engine loop a chance to exit before starting new analysis
    await Future.delayed(Duration.zero);

    // Rebuild board from start
    final board = chess.Chess.fromFEN(state.startingFen);

    String? lastFrom;
    String? lastTo;

    // Apply moves up to the target index
    for (int i = 0; i <= moveIndex && i < state.originalMoves.length; i++) {
      final move = state.originalMoves[i];
      board.move({
        'from': move.from,
        'to': move.to,
        'promotion': move.promotion,
      });
      lastFrom = move.from;
      lastTo = move.to;
    }

    // Instantly sync evaluation state from analyzedMoves if available
    double currentEval = state.currentEval;
    List<EngineLine> currentEngineLines = state.currentEngineLines;
    String? bestMove = state.bestMove;

    if (moveIndex >= 0 && moveIndex < state.analyzedMoves.length) {
      final analyzedMove = state.analyzedMoves[moveIndex];
      currentEval = analyzedMove.evalAfter;
      currentEngineLines = analyzedMove.engineLines;
      bestMove = analyzedMove.bestMove;
    } else if (moveIndex == -1 && state.analyzedMoves.isNotEmpty) {
      currentEval = state.analyzedMoves.first.evalBefore;
    }

    state = state.copyWith(
      currentMoveIndex: moveIndex,
      board: board,
      lastMoveFrom: moveIndex >= 0 ? lastFrom : null,
      lastMoveTo: moveIndex >= 0 ? lastTo : null,
      currentEval: currentEval,
      currentEngineLines: currentEngineLines,
      bestMove: bestMove,
      clearSelection: true,
    );

    // Analyze new position if live analysis is active and full game analysis isn't running
    if (_isInitialized && state.isLiveAnalysis && !state.isAnalyzing) {
      await _analyzeCurrentPosition();
    }
  }

  /// Go to next move
  Future<void> nextMove() async {
    if (!state.canGoNext) return;
    await goToMove(state.currentMoveIndex + 1);
  }

  /// Go to previous move
  Future<void> previousMove() async {
    if (!state.canGoPrevious) return;
    await goToMove(state.currentMoveIndex - 1);
  }

  /// Go to first move
  Future<void> firstMove() async {
    await goToMove(-1);
  }

  /// Go to last move
  Future<void> lastMove() async {
    await goToMove(state.originalMoves.length - 1);
  }

  /// Toggle live analysis

  /// Analyze current position (with eval caching)
  Future<void> _analyzeCurrentPosition() async {
    if (_stockfish == null || !_isInitialized) return;
    if (_isAnalyzing) return;

    final fen = state.fen;
    final depth = AppConstants.analysisDepth;
    final multiPv = AppConstants.topEngineLinesCount;

    try {
      final cached = await _db.getCachedEvaluation(
        fen: fen,
        requiredDepth: depth,
        requiredMultiPv: multiPv,
      );

      if (cached != null) {
        final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
        final lines = linesJson.map((l) => EngineLine(
          rank: l['rank'] as int,
          evaluation: (l['evaluation'] as num).toDouble(),
          depth: l['depth'] as int,
          moves: List<String>.from(l['moves']),
          isMate: (l['isMate'] as bool?) ?? false,
          mateIn: l['mateIn'] as int?,
        )).toList();

        state = state.copyWith(
          currentEval: (cached['evaluation'] as num).toDouble(),
          currentEngineLines: lines,
          bestMove: lines.isNotEmpty ? lines.first.moves.first : null,
        );
        return;
      }
    } catch (e) {
      debugPrint('Eval cache lookup failed: $e');
    }

    try {
      _isAnalyzing = true;
      final result = await _stockfish!.analyzePosition(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        onUpdate: (partialResult) {
          state = state.copyWith(
            currentEval: partialResult.evalInPawns,
            currentEngineLines: partialResult.lines,
            bestMove:
                partialResult.lines.isNotEmpty
                    ? partialResult.lines.first.moves.first
                    : null,
          );
        },
      );

      final linesJson = result.lines.map((l) => ({
        'rank': l.rank,
        'evaluation': l.evaluation,
        'depth': l.depth,
        'moves': l.moves,
        'isMate': l.isMate,
        'mateIn': l.mateIn,
      })).toList();

      await _db.cacheEvaluation(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        evaluation: result.evalInPawns,
        engineLines: jsonEncode(linesJson),
        isMate: result.lines.isNotEmpty && result.lines.first.isMate,
        mateIn: result.lines.isNotEmpty ? result.lines.first.mateIn : null,
      );

      state = state.copyWith(
        currentEval: result.evalInPawns,
        currentEngineLines: result.lines,
        bestMove:
            result.lines.isNotEmpty ? result.lines.first.moves.first : null,
      );
    } catch (e) {
      debugPrint('Stockfish analysis failed: $e. Using BasicEvaluator.');
      try {
        final basicResult = await BasicEvaluatorService.instance.analyze(fen);
        state = state.copyWith(
          currentEval: basicResult.evalInPawns,
          currentEngineLines: basicResult.lines,
          bestMove:
              basicResult.lines.isNotEmpty
                  ? basicResult.lines.first.moves.first
                  : null,
        );
      } catch (e2) {
        // Silently fail
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Run full game analysis
  Future<void> analyzeFullGame() async {
    if (_isAnalyzing) return; // Prevent concurrent analysis
    if (_stockfish == null) {
      await initialize();
    }

    if (_stockfish == null || state.originalMoves.isEmpty) return;

    final token = ++_analysisToken; // Capture cancellation token

    // Ensure engine is at maximum strength for full game analysis
    _stockfish!.setMaxStrength();

    state = state.copyWith(
      isAnalyzing: true,
      analysisProgress: 0.0,
      analyzedMoves: [],
    );

    try {
      _isAnalyzing = true;
      final moves = state.originalMoves;
      final analyzedMoves = <MoveAnalysis>[];
      final board = chess.Chess.fromFEN(state.startingFen);

      double prevEval = 0.0;

      // Get initial evaluation (check cache first)
      try {
        if (token != _analysisToken) return;
        final initialData = await _getCachedOrAnalyze(board.fen, depth: 15, multiPv: 1);
        prevEval = initialData.eval;
      } catch (e) {
        try {
          final basicResult = await BasicEvaluatorService.instance.analyze(board.fen);
          prevEval = basicResult.evalInPawns;
        } catch (e2) {
          prevEval = 0.0;
        }
      }

      for (int i = 0; i < moves.length; i++) {
        // Check cancellation token
        if (token != _analysisToken) return;

        final move = moves[i];
        final isWhiteMove = board.turn == chess.Color.WHITE;

        // Yield to event loop every 5 moves to prevent ANR
        if (i % 5 == 0 && i > 0) {
          await Future.delayed(Duration.zero);
        }

        // Apply the actual move
        board.move({
          'from': move.from,
          'to': move.to,
          'promotion': move.promotion,
        });

        // Get evaluation after move (check cache first)
        double afterEval = 0.0;
        List<EngineLine> engineLines = [];
        String? bestMove;

        try {
          if (!_isAnalyzing) break;
          if (token != _analysisToken) return;

          final cachedResult = await _getCachedOrAnalyze(
            board.fen,
            depth: 15,
            multiPv: 3,
          );

          afterEval = cachedResult.eval;
          engineLines = cachedResult.lines;
          if (cachedResult.lines.isNotEmpty && cachedResult.lines.first.moves.isNotEmpty) {
            bestMove = cachedResult.lines.first.moves.first;
          }
        } catch (e) {
          try {
            final basicResult = await BasicEvaluatorService.instance.analyze(
              board.fen,
            );
            afterEval = basicResult.evalInPawns;
            engineLines = basicResult.lines;
            if (basicResult.lines.isNotEmpty &&
                basicResult.lines.first.moves.isNotEmpty) {
              bestMove = basicResult.lines.first.moves.first;
            }
          } catch (e2) {
            afterEval = prevEval;
          }
        }

        // Classify the move
        final classification = classifyMove(
          evalBefore: prevEval,
          evalAfter: afterEval,
          isWhiteMove: isWhiteMove,
          bestMove: bestMove,
          actualMove: '${move.from}${move.to}${move.promotion ?? ''}',
        );

        // Debug logging
        if (i < 5) {
          // Log first 5 moves for debugging
          debugPrint(
            '📊 Move ${i + 1}: ${move.san} | '
            'Before: ${prevEval.toStringAsFixed(2)} | '
            'After: ${afterEval.toStringAsFixed(2)} | '
            'Loss: ${isWhiteMove ? (prevEval - afterEval).toStringAsFixed(2) : (afterEval - prevEval).toStringAsFixed(2)} | '
            'Class: ${classification.name}',
          );
        }

        final cpl = computeCentipawnLoss(
          evalBefore: prevEval,
          evalAfter: afterEval,
          isWhiteMove: isWhiteMove,
        );
        final moveAccuracy = computeWinPercentAccuracy(
          evalBeforePawns: prevEval,
          evalAfterPawns: afterEval,
          isWhiteMove: isWhiteMove,
        );
        final winBefore = EvalConstants.centipawnsToWinPercent(prevEval * 100);
        final winAfter = EvalConstants.centipawnsToWinPercent(afterEval * 100);
        analyzedMoves.add(
          MoveAnalysis(
            moveIndex: i,
            san: move.san,
            fen: board.fen,
            evalBefore: prevEval,
            evalAfter: afterEval,
            winPercentBefore: winBefore,
            winPercentAfter: winAfter,
            bestMove: bestMove,
            classification: classification,
            engineLines: engineLines,
            isWhiteMove: isWhiteMove,
            centipawnLoss: cpl,
            accuracy: moveAccuracy,
          ),
        );

        prevEval = afterEval;

        // Update progress
        // Batch updates to improve performance (reduce UI rebuilds)
        // Update every 10 moves (changed from 5) or on the last move to reduce render thread pressure
        if ((i + 1) % 10 == 0 || i == moves.length - 1) {
          state = state.copyWith(
            analysisProgress: (i + 1) / moves.length,
            analyzedMoves: List.from(analyzedMoves),
          );
          stateUpdateCount++;
        }
      }

      // Create full analysis result
      final fullAnalysis = GameAnalysis.fromMoves(analyzedMoves);

      state = state.copyWith(
        isAnalyzing: false,
        analysisProgress: 1.0,
        analyzedMoves: analyzedMoves,
        fullAnalysis: fullAnalysis,
      );
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Stop analysis
  void stopAnalysis() {
    _analysisToken++; // Cancel any running analyzeFullGame
    _isAnalyzing = false; // Clear guard flag
    _stockfish?.stopAnalysis();
    state = state.copyWith(isAnalyzing: false);
  }

  /// Reset state
  void reset() {
    state = const AnalysisState();
  }

  /// Helper: get cached evaluation or run analysis and cache the result.
  Future<({double eval, List<EngineLine> lines})> _getCachedOrAnalyze(
    String fen, {
    required int depth,
    required int multiPv,
  }) async {
    // Check cache first
    try {
      final cached = await _db.getCachedEvaluation(
        fen: fen,
        requiredDepth: depth,
        requiredMultiPv: multiPv,
      );

      if (cached != null) {
        final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
        final lines = linesJson.map((l) => EngineLine(
          rank: l['rank'] as int,
          evaluation: (l['evaluation'] as num).toDouble(),
          depth: l['depth'] as int,
          moves: List<String>.from(l['moves']),
          isMate: (l['isMate'] as bool?) ?? false,
          mateIn: l['mateIn'] as int?,
        )).toList();
        return (eval: (cached['evaluation'] as num).toDouble(), lines: lines);
      }
    } catch (e) {
      debugPrint('Eval cache lookup failed: $e');
    }

    // Run analysis
    final result = await _stockfish!.analyzePosition(
      fen: fen,
      depth: depth,
      multiPv: multiPv,
    );

    // Cache the result
    try {
      final linesJson = result.lines.map((l) => ({
        'rank': l.rank,
        'evaluation': l.evaluation,
        'depth': l.depth,
        'moves': l.moves,
        'isMate': l.isMate,
        'mateIn': l.mateIn,
      })).toList();

      await _db.cacheEvaluation(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        evaluation: result.evalInPawns,
        engineLines: jsonEncode(linesJson),
        isMate: result.lines.isNotEmpty && result.lines.first.isMate,
        mateIn: result.lines.isNotEmpty ? result.lines.first.mateIn : null,
      );
    } catch (e) {
      debugPrint('Failed to cache eval: $e');
    }

    return (eval: result.evalInPawns, lines: result.lines);
  }

  @override
  void dispose() {
    _stockfish?.stopAnalysis();
    super.dispose();
  }
}
