import 'dart:async';
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
import 'package:chess_master/core/services/static_exchange_evaluator.dart';
import 'package:chess_master/core/services/opening_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';

class _AnalysisCancelled implements Exception {
  const _AnalysisCancelled();
}

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

  /// Get all evaluations for graphing.
  ///
  /// Index i == the position after i plies (index 0 = start position), built
  /// from the ACTUALLY reached evals so the curve matches the real game.
  List<double> get evaluations {
    if (analyzedMoves.isEmpty) return [currentEval];
    List<double> evals = [analyzedMoves.first.actualEvalBeforeMove];
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
  int? _analysisOwner;
  int _positionAnalysisToken = 0;
  bool _isDisposed = false;
  // Throttle for progressive Report-tab ticks (v90 ANR fix).
  DateTime _lastProgressTick = DateTime.fromMillisecondsSinceEpoch(0);

  @visibleForTesting
  int stateUpdateCount = 0;

  /// Fired once per successful full-game analysis (UI wires this to
  /// statistics so "Games Analysed" stays accurate without a Ref here).
  Future<void> Function()? onAnalysisComplete;

  AnalysisNotifier([this._stockfish]) : super(const AnalysisState());

  /// Initialize engine for analysis
  Future<void> initialize() async {
    if (_isDisposed || _isInitialized) return;

    try {
      _stockfish ??= stockfish.StockfishService.instance;
      await _stockfish!.initialize();
      _isInitialized = true;
    } catch (e) {
      if (!_isDisposed) {
        state = state.copyWith(
          errorMessage: 'Failed to initialize analysis engine: $e',
        );
      }
    }
  }

  /// Load a game for analysis
  Future<void> loadGame({
    required List<ChessMove> moves,
    String startingFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  }) async {
    if (_isDisposed) return;
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

    // Start full game analysis if engine is ready.
    // Don't also run _analyzeCurrentPosition() here — it contends with
    // analyzeFullGame() for the single-threaded engine and one will silently
    // fail due to the _isAnalyzing guard. The full-game loop already populates
    // engine lines for every position including the starting one.
    if (_isInitialized && moves.isNotEmpty) {
      unawaited(analyzeFullGame().catchError((_) {}));
    } else if (_isInitialized && moves.isEmpty) {
      // No moves to analyze — emit empty analysis immediately so Report tab
      // doesn't show infinite spinner.
      state = state.copyWith(
        isAnalyzing: false,
        analysisProgress: 1.0,
        fullAnalysis: GameAnalysis.empty(),
      );
    }
  }

  /// Navigate to a specific move index
  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

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
    if (_stockfish == null || !_isInitialized || _isDisposed) return;
    if (_isAnalyzing) return;

    final token = ++_positionAnalysisToken;
    _isAnalyzing = true;
    final fen = state.fen;
    final depth = AppConstants.analysisDepth;
    final multiPv = AppConstants.topEngineLinesCount;

    try {
      try {
        final cached = await _db.getCachedEvaluation(
          fen: fen,
          requiredDepth: depth,
          requiredMultiPv: multiPv,
        );

        if (_isDisposed || token != _positionAnalysisToken) return;
        if (cached != null) {
          final linesJson =
              jsonDecode(cached['engine_lines'] as String) as List;
          final lines =
              linesJson
                  .map(
                    (l) => EngineLine(
                      rank: l['rank'] as int,
                      evaluation: (l['evaluation'] as num).toDouble(),
                      depth: l['depth'] as int,
                      moves: List<String>.from(l['moves']),
                      isMate: (l['isMate'] as bool?) ?? false,
                      mateIn: l['mateIn'] as int?,
                    ),
                  )
                  .toList();

          state = state.copyWith(
            currentEval: (cached['evaluation'] as num).toDouble(),
            currentEngineLines: lines,
            bestMove:
                lines.isNotEmpty && lines.first.moves.isNotEmpty
                    ? lines.first.moves.first
                    : null,
          );
          return;
        }
      } catch (e) {
        debugPrint('Eval cache lookup failed: $e');
      }

      final result = await _stockfish!.analyzePosition(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        onUpdate: (partialResult) {
          if (_isDisposed || token != _positionAnalysisToken) return;
          state = state.copyWith(
            currentEval: partialResult.evalInPawns,
            currentEngineLines: partialResult.lines,
            bestMove:
                partialResult.lines.isNotEmpty &&
                        partialResult.lines.first.moves.isNotEmpty
                    ? partialResult.lines.first.moves.first
                    : null,
          );
        },
      );

      if (_isDisposed ||
          token != _positionAnalysisToken ||
          result.wasCancelled) {
        return;
      }
      if (result.lines.isEmpty) return;

      final linesJson =
          result.lines
              .map(
                (l) => ({
                  'rank': l.rank,
                  'evaluation': l.evaluation,
                  'depth': l.depth,
                  'moves': l.moves,
                  'isMate': l.isMate,
                  'mateIn': l.mateIn,
                }),
              )
              .toList();

      await _db.cacheEvaluation(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        evaluation: result.evalInPawns,
        engineLines: jsonEncode(linesJson),
        isMate: result.lines.first.isMate,
        mateIn: result.lines.first.mateIn,
      );

      if (_isDisposed || token != _positionAnalysisToken) return;
      state = state.copyWith(
        currentEval: result.evalInPawns,
        currentEngineLines: result.lines,
        bestMove: result.lines.first.moves.first,
      );
    } catch (e) {
      if (_isDisposed || token != _positionAnalysisToken) return;
      debugPrint('Stockfish analysis failed: $e. Using BasicEvaluator.');
      try {
        final basicResult = await BasicEvaluatorService.instance.analyze(fen);
        if (_isDisposed || token != _positionAnalysisToken) return;
        state = state.copyWith(
          currentEval: basicResult.evalInPawns,
          currentEngineLines: basicResult.lines,
          bestMove:
              basicResult.lines.isNotEmpty &&
                      basicResult.lines.first.moves.isNotEmpty
                  ? basicResult.lines.first.moves.first
                  : null,
        );
      } catch (_) {}
    } finally {
      if (!_isDisposed && token == _positionAnalysisToken) {
        _isAnalyzing = false;
      }
    }
  }

  /// Run full game analysis
  ///
  /// Pipeline overview (optimised):
  ///   1. Evaluate the starting position once → prevEval + bestMove.
  ///   2. For each move:
  ///      a. Reuse prevEval as the "before" eval (no extra engine call).
  ///      b. Reuse prevBestMove as the engine's best move for this position.
  ///      c. Apply the player's move, evaluate the resulting position → afterEval.
  ///      d. Classify using the consistent (prevEval, afterEval) pair.
  ///      e. Store afterEval's bestMove for the *next* iteration's step (b).
  ///   3. Emit partial fullAnalysis every 5 moves so the Report tab renders
  ///      progressively instead of showing a spinner until completion.
  Future<void> analyzeFullGame() async {
    if (_isAnalyzing || _analysisOwner != null || _isDisposed) return;
    final token = ++_analysisToken;
    _analysisOwner = token;
    _isAnalyzing = true;

    try {
      if (_stockfish == null) {
        await initialize();
        if (_isDisposed || token != _analysisToken) return;
      }

      if (_stockfish == null || state.originalMoves.isEmpty) return;

      await _stockfish!.setMaxStrength();
      if (_isDisposed || token != _analysisToken) return;
      await _stockfish!.setAnalysisStrength();
      if (_isDisposed || token != _analysisToken) return;
      await _stockfish!.newGame();
      if (_isDisposed || token != _analysisToken) return;

      if (_isDisposed || token != _analysisToken) return;
      state = state.copyWith(
        isAnalyzing: true,
        analysisProgress: 0.0,
        analyzedMoves: [],
      );
      _lastProgressTick = DateTime.now();

      final moves = state.originalMoves;
      // Running aggregates. Appending is O(1), so emitting a progress tick
      // after every ply no longer costs a full re-walk of the analysed list.
      final accumulator = GameAnalysisAccumulator();
      final board = chess.Chess.fromFEN(state.startingFen);

      // Identify game opening and ECO code using Master Opening Book
      final allMovesSan = moves.map((m) => m.san).toList();
      final identifiedOpening = OpeningService.instance.identifyOpening(
        allMovesSan,
      );
      if (identifiedOpening != null) {
        accumulator.setOpening(
          name: identifiedOpening.name,
          eco: identifiedOpening.eco,
        );
      }

      // Track SAN moves as we advance through the game
      final List<String> playedSanMoves = [];

      // Evaluation of the position ACTUALLY reached so far (white-relative
      // pawns). Seeded with the first position's best eval and then carried
      // forward as each ply's actualEval, so the graph/before-display series
      // follows the real game instead of the counterfactual best line.
      double? actualEvalSoFar;

      // ── Carry-forward of the previous ply's "after" analysis ──
      // The position reached after ply i is exactly the position to analyse
      // BEFORE ply i+1, so re-querying it costs a redundant cache hit plus a
      // full engine search. Hold the result here and reuse it next iteration.
      // Guarded by FEN so it is only used when the position genuinely matches
      // (branches, re-runs and jump-to-ply navigation fall back to the cache).
      ({double eval, List<EngineLine> lines, String fen})? carriedForward;

      // Instrumentation: proves searches-per-ply drops from ~2.0 to ~1.0.
      int engineQueries = 0;
      int carryForwardHits = 0;

      // ── Per-move analysis loop ──
      // For each position we do ONE engine analysis that gives us:
      //   1. bestEval: evaluation of the engine's top line (the best move)
      //   2. bestMove: the engine's top move in UCI format
      //   3. engineLines: top MultiPV lines for display
      // Then we play the ACTUAL move and evaluate that position.
      // Move classification follows Lichess Win-Probability Loss standards.
      for (int i = 0; i < moves.length; i++) {
        // Check cancellation token — save partial results before exiting
        if (token != _analysisToken) {
          if (accumulator.length > 0) {
            state = state.copyWith(
              analyzedMoves: accumulator.moves,
              fullAnalysis: accumulator.build(),
            );
          }
          return;
        }

        final move = moves[i];
        final isWhiteMove = board.turn == chess.Color.WHITE;

        // Check if this move continues recognized master opening theory
        final isBook = OpeningService.instance.isBookMove(
          playedSanMoves,
          move.san,
        );
        final isForcedMove = board.moves().length == 1;
        final isRecapture = _isRecapture(board, move);

        if (isBook || isForcedMove || isRecapture) {
          // Classify without heavy engine search:
          // Book moves receive dedicated Book classification, 0 CPL, 100% accuracy.
          final defaultEval = actualEvalSoFar ?? 0.0;
          actualEvalSoFar = defaultEval;
          final classification =
              isBook ? MoveClassification.book : MoveClassification.best;
          accumulator.add(
            MoveAnalysis(
              moveIndex: i,
              san: move.san,
              fen: board.fen,
              evalBefore: defaultEval,
              evalAfter: defaultEval,
              actualEvalBeforeMove: defaultEval,
              winPercentBefore: EvalConstants.centipawnsToWinPercent(
                defaultEval * 100,
              ),
              winPercentAfter: EvalConstants.centipawnsToWinPercent(
                defaultEval * 100,
              ),
              bestMove: '${move.from}${move.to}${move.promotion ?? ''}',
              classification: classification,
              engineLines: [],
              isWhiteMove: isWhiteMove,
              centipawnLoss: 0.0,
              accuracy: 100.0,
              isMateBefore: false,
              isMateAfter: false,
              isBookMove: isBook,
            ),
          );

          // Advance the board state and played SAN history.
          playedSanMoves.add(move.san);
          board.move({
            'from': move.from,
            'to': move.to,
            'promotion': move.promotion,
          });

          // Emit progress tick (throttled — see main-loop tick below).
          final bookElapsed = DateTime.now().difference(_lastProgressTick);
          if ((i + 1) % 5 == 0 ||
              bookElapsed.inMilliseconds >= 750 ||
              i == moves.length - 1) {
            _lastProgressTick = DateTime.now();
            state = state.copyWith(
              analysisProgress: (i + 1) / moves.length,
              analyzedMoves: accumulator.moves,
              fullAnalysis: accumulator.build(),
            );
          }
          continue;
        }

        // ── Step A: Analyze the current position with progressive deepening ──
        // Phase 2: First probe at depth 8, then adaptively decide whether to go deeper.
        // Two-tier classification:
        //   1. Probe at depth 8 / MultiPV 1 to get a quick bestEval.
        //   2. Evaluate the player's actual move at depth 8 as well.
        //   3. If CPL > 200 → Blunder (stop here).
        //      If CPL > 100 → Mistake  (stop here).
        //      If CPL > 50  → Inaccuracy (stop here).
        //      If CPL < 50  → Competitive: do a follow-up depth 14 for fine-grained eval.
        double bestEval = 0.0;
        String? bestMoveForPlayer;
        List<EngineLine> bestLines = [];
        bool bestIsMate = false;

        // Track whether the depth-8 probe was sufficient (early cutoff applied)
        bool depth8Sufficient = false;
        double depth8Cpl = 0.0;

        try {
          if (token != _analysisToken) {
            if (accumulator.length > 0) {
              state = state.copyWith(
                analyzedMoves: accumulator.moves,
                fullAnalysis: accumulator.build(),
              );
            }
            return;
          }

          final carried = carriedForward;
          final ({double eval, List<EngineLine> lines}) positionData;

          // Phase 2: Soft cache acceptance - try cache at depth 10 or 12 first
          final softCacheResult = await _getSoftCachedEvaluation(
            board.fen,
            softCacheThreshold: 10,
          );
          if (softCacheResult != null && token == _analysisToken) {
            positionData = softCacheResult;
            engineQueries++;
          } else if (carried != null && carried.fen == board.fen) {
            // Reuse carry-forward from previous ply's "after" result
            positionData = (eval: carried.eval, lines: carried.lines);
            carryForwardHits++;
          } else {
            // Phase 1: Depth 8 probe with MultiPV 1 (fast)
            positionData = await _getCachedOrAnalyze(
              board.fen,
              depth: 8,
              multiPv: 1,
              isBatchAnalysis: true,
            );
            engineQueries++;
          }

          bestEval = positionData.eval;
          bestLines = positionData.lines;
          if (positionData.lines.isNotEmpty) {
            bestIsMate = positionData.lines.first.isMate;
            if (positionData.lines.first.moves.isNotEmpty) {
              bestMoveForPlayer = positionData.lines.first.moves.first;
            }
          }
        } on _AnalysisCancelled {
          return;
        } catch (e) {
          try {
            final basicResult = await BasicEvaluatorService.instance.analyze(
              board.fen,
            );
            bestEval = basicResult.evalInPawns;
            bestLines = basicResult.lines;
            if (basicResult.lines.isNotEmpty &&
                basicResult.lines.first.moves.isNotEmpty) {
              bestMoveForPlayer = basicResult.lines.first.moves.first;
            }
          } catch (e2) {
            bestEval = 0.0;
          }
        }

        // ── SEE Calculation (computed before move is played) ──
        // How much worse the engine's second line is than its best, in
        // centipawns from the mover's perspective. Used to detect an "only
        // good move" (Great). Null when MultiPV returned a single line.
        double? secondBestCpl;
        if (bestLines.length >= 2) {
          final firstEval = bestLines[0].evaluation;
          final secondEval = bestLines[1].evaluation;
          final margin =
              isWhiteMove ? (firstEval - secondEval) : (secondEval - firstEval);
          secondBestCpl = (margin * 100.0).abs();
        }

        // Static exchange evaluation of the played move, computed on the
        // position BEFORE the move. Negative = material was given up.
        double? seeCentipawns;
        try {
          seeCentipawns =
              StaticExchangeEvaluator.evaluate(
                board,
                move.from,
                move.to,
                promotion: move.promotion,
              ).toDouble();
        } catch (_) {
          seeCentipawns = null;
        }

        // ── Step B: Play the actual move and evaluate at depth 8 ──
        playedSanMoves.add(move.san);
        board.move({
          'from': move.from,
          'to': move.to,
          'promotion': move.promotion,
        });

        final isDeliveredCheckmate = board.in_checkmate;
        double actualEval = bestEval;
        bool actualIsMate = false;

        if (isDeliveredCheckmate) {
          actualEval = isWhiteMove ? 100.0 : -100.0;
          actualIsMate = true;
          carriedForward = null;
        } else {
          // Evaluate the position AFTER the move at depth 8
          try {
            if (token != _analysisToken) {
              if (accumulator.length > 0) {
                state = state.copyWith(
                  analyzedMoves: accumulator.moves,
                  fullAnalysis: accumulator.build(),
                );
              }
              return;
            }

            // Try soft cache for the after position
            final afterCacheResult = await _getSoftCachedEvaluation(
              board.fen,
              softCacheThreshold: 10,
            );

            if (afterCacheResult != null) {
              actualEval = afterCacheResult.eval;
              if (afterCacheResult.lines.isNotEmpty) {
                actualIsMate = afterCacheResult.lines.first.isMate;
              }
              carriedForward = (
                eval: afterCacheResult.eval,
                lines: afterCacheResult.lines,
                fen: board.fen,
              );
            } else {
              final actualData = await _getCachedOrAnalyze(
                board.fen,
                depth: 8,
                multiPv: 1,
                isBatchAnalysis: true,
              );
              engineQueries++;
              actualEval = actualData.eval;
              if (actualData.lines.isNotEmpty) {
                actualIsMate = actualData.lines.first.isMate;
              }
              carriedForward = (
                eval: actualData.eval,
                lines: actualData.lines,
                fen: board.fen,
              );
            }
          } on _AnalysisCancelled {
            return;
          } catch (e) {
            carriedForward = null;
            try {
              final basicResult = await BasicEvaluatorService.instance.analyze(
                board.fen,
              );
              actualEval = basicResult.evalInPawns;
            } catch (e2) {
              actualEval = bestEval;
            }
          }
        }

        final playedUci =
            '${move.from}${move.to}${move.promotion ?? ''}'.toLowerCase();
        final isPlayedBestMove =
            bestMoveForPlayer != null &&
            playedUci == bestMoveForPlayer.toLowerCase();

        // Progressive deepening: If the played move matches the engine's best move
        // or delivered checkmate, we can safely accept the evaluation and save search time.
        // If the move deviates, we MUST refine at depth 14 so that tactical combinations
        // and sacrifices are verified before deciding on blunder or mistake tags.
        if (isPlayedBestMove || isDeliveredCheckmate) {
          depth8Sufficient = true;
        } else {
          // Re-analyze after position at depth 14
          try {
            if (token != _analysisToken) {
              if (accumulator.length > 0) {
                state = state.copyWith(
                  analyzedMoves: accumulator.moves,
                  fullAnalysis: accumulator.build(),
                );
              }
              return;
            }

            final refinedData = await _getCachedOrAnalyze(
              board.fen,
              depth: AppConstants.batchAnalysisDepth,
              multiPv: AppConstants.batchAnalysisMultiPv,
              isBatchAnalysis: true,
            );
            engineQueries++;

            actualEval = refinedData.eval;
            if (refinedData.lines.isNotEmpty) {
              actualIsMate = refinedData.lines.first.isMate;
            }
            carriedForward = (
              eval: refinedData.eval,
              lines: refinedData.lines,
              fen: board.fen,
            );
          } on _AnalysisCancelled {
            return;
          } catch (e) {
            // Keep depth-8 eval if depth-14 fails
          }
        }

        // ── Step C: Compute centipawn loss from player's perspective ──
        // bestEval and actualEval are white-relative PAWNS (evalInPawns).
        // For white: loss = bestEval - actualEval (positive = player lost ground)
        // For black: loss = actualEval - bestEval (positive = player lost ground)
        // If negative, player found a better move or improved position (0 loss).
        final double rawLoss =
            isWhiteMove
                ? (bestEval - actualEval) * 100.0
                : (actualEval - bestEval) * 100.0;
        final double centipawnLoss =
            isDeliveredCheckmate ? 0.0 : (rawLoss < 0.0 ? 0.0 : rawLoss);

        // The position actually reached before this ply.
        final double actualEvalBeforeMove = actualEvalSoFar ?? bestEval;
        actualEvalSoFar = actualEval;

        // Win% for display — uses the ACTUAL prior position for continuity
        final winBest = EvalConstants.centipawnsToWinPercent(
          actualEvalBeforeMove * 100,
        );
        final winActual = EvalConstants.centipawnsToWinPercent(
          actualEval * 100,
        );
        final winBefore = isWhiteMove ? winBest : (100.0 - winBest);
        final winAfter = isWhiteMove ? winActual : (100.0 - winActual);
        final rawWinDiff = winBefore - winAfter;
        final winDiff =
            isDeliveredCheckmate ? 0.0 : (rawWinDiff < 0 ? 0.0 : rawWinDiff);

        // Win%-based accuracy ensures badge and win% delta never disagree
        final moveAccuracy =
            isDeliveredCheckmate
                ? 100.0
                : computeWinPercentAccuracy(
                  evalBeforePawns: actualEvalBeforeMove,
                  evalAfterPawns: actualEval,
                  isWhiteMove: isWhiteMove,
                );

        // ── Step D: Classify using Win% Model (Lichess standards) ──
        final classification = classifyMoveCpl(
          centipawnLoss: centipawnLoss,
          bestMove: bestMoveForPlayer,
          actualMove: playedUci,
          isBookMove: isBook,
          isMateBefore: bestIsMate,
          isMateAfter: actualIsMate,
          seeCentipawns: seeCentipawns,
          secondBestCentipawnLoss: secondBestCpl,
          playerWinPercentBefore: winBefore,
          winPercentDiff: winDiff,
          isCheckmate: isDeliveredCheckmate,
        );

        // Debug logging
        debugPrint(
          '📊 Move ${i + 1}: ${move.san} | '
          'Best: ${bestEval.toStringAsFixed(2)} | '
          'Actual: ${actualEval.toStringAsFixed(2)} | '
          'CPL: ${centipawnLoss.toStringAsFixed(0)} | '
          'EarlyCutoff: $depth8Sufficient | '
          'WinDiff: ${winDiff.toStringAsFixed(1)} | '
          'Class: ${classification.name}',
        );

        accumulator.add(
          MoveAnalysis(
            moveIndex: i,
            san: move.san,
            fen: board.fen,
            evalBefore: bestEval,
            evalAfter: actualEval,
            actualEvalBeforeMove: actualEvalBeforeMove,
            winPercentBefore: winBefore,
            winPercentAfter: winAfter,
            bestMove: bestMoveForPlayer,
            classification: classification,
            engineLines: bestLines,
            isWhiteMove: isWhiteMove,
            centipawnLoss: centipawnLoss,
            accuracy: moveAccuracy,
            isMateBefore: bestIsMate,
            isMateAfter: actualIsMate,
            isBookMove: isBook,
          ),
        );

        // Update progress — emit partial fullAnalysis so the Report tab
        // renders progressively instead of showing a spinner until the end.
        // v90 stability: throttle ticks (every 5 plies or 750ms, plus the last
        // ply). Each tick rebuilds the full aggregates + notifies listeners on
        // the UI thread; unthrottled ticks were a PlatformTaskQueue ANR source
        // on long games.
        final progressElapsed = DateTime.now().difference(_lastProgressTick);
        final isLastPly = i == moves.length - 1;
        if ((i + 1) % 5 == 0 ||
            progressElapsed.inMilliseconds >= 750 ||
            isLastPly) {
          _lastProgressTick = DateTime.now();
          final isCurrentPly = state.currentMoveIndex == i;
          state = state.copyWith(
            analysisProgress: (i + 1) / moves.length,
            analyzedMoves: accumulator.moves,
            fullAnalysis: accumulator.build(),
            currentEval: isCurrentPly ? actualEval : null,
            currentEngineLines: isCurrentPly ? bestLines : null,
            bestMove: isCurrentPly ? bestMoveForPlayer : null,
          );
          stateUpdateCount++;
        }
      }

      // Searches-per-ply instrumentation. Steady state should approach 1.0:
      // every position is searched once as an "after" and then reused as the
      // next ply's "before" instead of being searched a second time.
      if (accumulator.length > 0) {
        debugPrint(
          '⏱️ PERF searches=$engineQueries plies=${accumulator.length} '
          'searchesPerPly=${(engineQueries / accumulator.length).toStringAsFixed(2)} '
          'carryForwardHits=$carryForwardHits',
        );
      }

      if (_isDisposed || token != _analysisToken) return;
      final fullAnalysis = accumulator.build();

      state = state.copyWith(
        isAnalyzing: false,
        analysisProgress: 1.0,
        analyzedMoves: accumulator.moves,
        fullAnalysis: fullAnalysis,
      );
      if (accumulator.length > 0) {
        try {
          await onAnalysisComplete?.call();
        } catch (_) {}
      }
    } finally {
      if (_analysisOwner == token) {
        await _stockfish?.setLivePlayStrength();
        _analysisOwner = null;
        _isAnalyzing = false;
        if (!_isDisposed && token == _analysisToken && state.isAnalyzing) {
          state = state.copyWith(isAnalyzing: false);
        }
      }
    }
  }

  /// Stop analysis
  void stopAnalysis() {
    if (_isDisposed) return;
    _analysisToken++;
    _positionAnalysisToken++;
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
    bool isBatchAnalysis = false,
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
        final lines =
            linesJson
                .map(
                  (l) => EngineLine(
                    rank: l['rank'] as int,
                    evaluation: (l['evaluation'] as num).toDouble(),
                    depth: l['depth'] as int,
                    moves: List<String>.from(l['moves']),
                    isMate: (l['isMate'] as bool?) ?? false,
                    mateIn: l['mateIn'] as int?,
                  ),
                )
                .toList();
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
      isBatchAnalysis: isBatchAnalysis,
    );
    if (result.wasCancelled) {
      throw const _AnalysisCancelled();
    }
    if (result.lines.isEmpty) {
      return (eval: result.evalInPawns, lines: result.lines);
    }

    // Cache the result
    try {
      final linesJson =
          result.lines
              .map(
                (l) => ({
                  'rank': l.rank,
                  'evaluation': l.evaluation,
                  'depth': l.depth,
                  'moves': l.moves,
                  'isMate': l.isMate,
                  'mateIn': l.mateIn,
                }),
              )
              .toList();

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

  /// Phase 3: Soft cache acceptance.
  /// Looks for cached results at depth >= [softCacheThreshold] (typically 10 or 12).
  /// If a cached result is found, check if its classification is mathematically
  /// stable - meaning the CPL is clearly above or below the thresholds so that
  /// a depth-14 re-evaluation wouldn't change the classification.
  ///
  /// Classification stability:
  /// - If CPL > 200 (Blunder) or CPL > 100 (Mistake): definitely stable, accept.
  /// - If CPL > 50 (Inaccuracy): stable, accept.
  /// - If CPL < 50 (Best/Excellent/Good): NOT stable enough - needs depth-14 refinement.
  /// - Exception: If the position is a terminal/mate position, always accept.
  Future<({double eval, List<EngineLine> lines})?> _getSoftCachedEvaluation(
    String fen, {
    required int softCacheThreshold,
  }) async {
    try {
      // Look for cache entries at depth >= threshold but < AppConstants.batchAnalysisDepth
      // (depth 14 is handled by regular _getCachedOrAnalyze)
      final cached = await _db.getCachedEvaluation(
        fen: fen,
        requiredDepth: softCacheThreshold,
        requiredMultiPv: 1,
      );

      if (cached == null) return null;

      final depth = cached['depth'] as int;
      // Only accept if cached depth is between threshold and batchAnalysisDepth-1
      if (depth >= AppConstants.batchAnalysisDepth) {
        // Full-depth result would be picked up by _getCachedOrAnalyze anyway
        return null;
      }

      final cachedEval = (cached['evaluation'] as num).toDouble();
      final isMate = cached['isMate'] as bool? ?? false;

      // If it's a mate position, the classification is always stable
      if (isMate) {
        final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
        final lines =
            linesJson
                .map(
                  (l) => EngineLine(
                    rank: l['rank'] as int,
                    evaluation: (l['evaluation'] as num).toDouble(),
                    depth: l['depth'] as int,
                    moves: List<String>.from(l['moves']),
                    isMate: (l['isMate'] as bool?) ?? false,
                    mateIn: l['mateIn'] as int?,
                  ),
                )
                .toList();
        return (eval: cachedEval, lines: lines);
      }

      // For non-mate positions, we need to check if the classification is stable.
      // Since we don't have the "before" eval here (that's the best move eval),
      // we can't compute CPL directly. However, the caller will compute CPL from
      // the before/after pair and make the cutoff decision.
      //
      // As a heuristic: if the cached eval is extreme (> 5.0 or < -5.0), the
      // position is likely won/lost and the classification would be stable.
      final evalAbs = cachedEval.abs();
      if (evalAbs > 5.0) {
        // Extreme position - classification is stable
        final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
        final lines =
            linesJson
                .map(
                  (l) => EngineLine(
                    rank: l['rank'] as int,
                    evaluation: (l['evaluation'] as num).toDouble(),
                    depth: l['depth'] as int,
                    moves: List<String>.from(l['moves']),
                    isMate: (l['isMate'] as bool?) ?? false,
                    mateIn: l['mateIn'] as int?,
                  ),
                )
                .toList();
        return (eval: cachedEval, lines: lines);
      }

      // For moderate evaluations, we can't determine stability without the
      // before/after pair, so let the caller handle the cutoff decision.
      // Return the cached result and let the caller decide.
      final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
      final lines =
          linesJson
              .map(
                (l) => EngineLine(
                  rank: l['rank'] as int,
                  evaluation: (l['evaluation'] as num).toDouble(),
                  depth: l['depth'] as int,
                  moves: List<String>.from(l['moves']),
                  isMate: (l['isMate'] as bool?) ?? false,
                  mateIn: l['mateIn'] as int?,
                ),
              )
              .toList();
      return (eval: cachedEval, lines: lines);
    } catch (e) {
      debugPrint('Soft cache lookup failed: $e');
      return null;
    }
  }

  /// Returns true if the move recaptures a piece on a square that was just
  /// captured by the opponent's previous move (material-restoring recaptures
  /// are almost always fine and don't need engine analysis).
  bool _isRecapture(chess.Chess board, ChessMove move) {
    final history = board.history;
    if (history.isEmpty) return false;

    final lastEntry = history.last;
    final lastMove = lastEntry.move;

    // lastMove.toAlgebraic is the square the opponent just moved to (e.g. "e4").
    // If our move captures on that same square, it's a recapture.
    return move.to == lastMove.toAlgebraic;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _analysisToken++;
    _positionAnalysisToken++;
    _analysisOwner = null;
    _stockfish?.stopAnalysis();
    super.dispose();
  }
}
