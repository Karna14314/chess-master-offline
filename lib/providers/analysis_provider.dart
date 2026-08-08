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

    // Start full game analysis if engine is ready.
    // Don't also run _analyzeCurrentPosition() here — it contends with
    // analyzeFullGame() for the single-threaded engine and one will silently
    // fail due to the _isAnalyzing guard. The full-game loop already populates
    // engine lines for every position including the starting one.
    if (_isInitialized && moves.isNotEmpty) {
      analyzeFullGame();
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
    if (_isAnalyzing) return; // Prevent concurrent analysis
    if (_stockfish == null) {
      await initialize();
    }

    if (_stockfish == null || state.originalMoves.isEmpty) return;

    final token = ++_analysisToken; // Capture cancellation token

    // Ensure engine is at maximum strength for full game analysis, and give it
    // more threads/hash than live play for the duration of the batch. Restored
    // in the finally block below, including on the cancellation path.
    _stockfish!.setMaxStrength();
    _stockfish!.setAnalysisStrength();

    // Flush the transposition table ONCE at the start of the batch so the run
    // does not inherit entries from prior live play. Per-ply flushes are
    // suppressed via isBatchAnalysis, letting the engine reuse TT work across
    // consecutive plies of this game.
    _stockfish!.newGame();

    state = state.copyWith(
      isAnalyzing: true,
      analysisProgress: 0.0,
      analyzedMoves: [],
    );

    try {
      _isAnalyzing = true;
      final moves = state.originalMoves;
      // Running aggregates. Appending is O(1), so emitting a progress tick
      // after every ply no longer costs a full re-walk of the analysed list.
      final accumulator = GameAnalysisAccumulator();
      final board = chess.Chess.fromFEN(state.startingFen);

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
      ({
        double eval,
        List<EngineLine> lines,
        String fen,
      })? carriedForward;

      // Instrumentation: proves searches-per-ply drops from ~2.0 to ~1.0.
      int engineQueries = 0;
      int carryForwardHits = 0;

      // ── Per-move analysis loop ──
      // For each position we do ONE engine analysis that gives us:
      //   1. bestEval: evaluation of the engine's top line (the best move)
      //   2. bestMove: the engine's top move in UCI format
      //   3. engineLines: top MultiPV lines for display
      // Then we play the ACTUAL move and evaluate that position.
      // Centipawn loss = bestEval - actualEval (from player's perspective).
      // This matches how Lichess/Chess.com classify moves.
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

        // ── Step A: Analyze the current position to get bestEval + bestMove ──
        double bestEval = 0.0;
        String? bestMoveForPlayer;
        List<EngineLine> bestLines = [];
        bool bestIsMate = false;

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

          // Reuse the previous ply's "after" result when it is the very same
          // position, skipping both the cache lookup and the engine search.
          final carried = carriedForward;
          final ({double eval, List<EngineLine> lines}) positionData;
          if (carried != null && carried.fen == board.fen) {
            positionData = (eval: carried.eval, lines: carried.lines);
            carryForwardHits++;
          } else {
            positionData = await _getCachedOrAnalyze(
              board.fen,
              depth: 15,
              multiPv: 3,
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
        } catch (e) {
          try {
            final basicResult =
                await BasicEvaluatorService.instance.analyze(board.fen);
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

        // How much worse the engine's second line is than its best, in
        // centipawns from the mover's perspective. Used to detect an "only
        // good move" (Great). Null when MultiPV returned a single line.
        double? secondBestCpl;
        if (bestLines.length >= 2) {
          final firstEval = bestLines[0].evaluation;
          final secondEval = bestLines[1].evaluation;
          final margin = isWhiteMove
              ? (firstEval - secondEval)
              : (secondEval - firstEval);
          secondBestCpl = (margin * 100.0).abs();
        }

        // Static exchange evaluation of the played move, computed on the
        // position BEFORE the move. Negative = material was given up.
        double? seeCentipawns;
        try {
          seeCentipawns = StaticExchangeEvaluator.evaluate(
            board,
            move.from,
            move.to,
            promotion: move.promotion,
          ).toDouble();
        } catch (_) {
          seeCentipawns = null;
        }

        // ── Step B: Play the actual move and evaluate ──
        board.move({
          'from': move.from,
          'to': move.to,
          'promotion': move.promotion,
        });

        double actualEval = bestEval;
        bool actualIsMate = false;

        try {
          final actualData = await _getCachedOrAnalyze(
            board.fen,
            depth: 15,
            multiPv: 3,
            isBatchAnalysis: true,
          );
          engineQueries++;
          actualEval = actualData.eval;
          if (actualData.lines.isNotEmpty) {
            actualIsMate = actualData.lines.first.isMate;
          }
          // Hand this result to the next iteration as its "before" data.
          carriedForward = (
            eval: actualData.eval,
            lines: actualData.lines,
            fen: board.fen,
          );
        } catch (e) {
          // The engine failed for this position — drop the carry-forward so
          // the next ply re-queries rather than inheriting degraded data.
          carriedForward = null;
          try {
            final basicResult =
                await BasicEvaluatorService.instance.analyze(board.fen);
            actualEval = basicResult.evalInPawns;
          } catch (e2) {
            actualEval = bestEval;
          }
        }

        // ── Step C: Compute centipawn loss from player's perspective ──
        // bestEval and actualEval are white-relative PAWNS (evalInPawns).
        // For white: CPL = bestEval - actualEval (positive = player did worse)
        // For black: CPL = actualEval - bestEval (positive = player did worse)
        // Multiply the pawn delta by 100: classifyMoveCpl()'s thresholds
        // (10/20/50/100/200) are expressed in CENTIPAWNS, not pawns. Without the
        // conversion every non-tactical move landed at "Best Move".
        final double centipawnLoss = isWhiteMove
            ? (bestEval - actualEval) * 100.0
            : (actualEval - bestEval) * 100.0;
        final double cplAbs = centipawnLoss.abs();

        // The position actually reached before this ply. For the first ply
        // there is no previous ply, so it is the current position's eval.
        final double actualEvalBeforeMove = actualEvalSoFar ?? bestEval;
        actualEvalSoFar = actualEval;

        // Win% for display — "before" uses the ACTUAL prior position so the
        // displayed before/after pair matches the real game continuity.
        final winBest = EvalConstants.centipawnsToWinPercent(
          actualEvalBeforeMove * 100,
        );
        final winActual = EvalConstants.centipawnsToWinPercent(actualEval * 100);
        final winBefore = isWhiteMove ? winBest : (100.0 - winBest);
        final winAfter = isWhiteMove ? winActual : (100.0 - winActual);
        final rawWinDiff = winBefore - winAfter;
        final winDiff = rawWinDiff < 0 ? 0.0 : rawWinDiff;
        // Accuracy is derived from the same before/after pair that is
        // displayed, so the badge and the win% delta never disagree.
        final moveAccuracy = computeWinPercentAccuracy(
          evalBeforePawns: actualEvalBeforeMove,
          evalAfterPawns: actualEval,
          isWhiteMove: isWhiteMove,
        );

        // ── Step D: Classify using CPL thresholds ──
        // SEE and the MultiPV second-line margin promote a sound move to
        // Brilliant/Great; the Win% pair enables the non-mate Miss case.
        final classification = classifyMoveCpl(
          centipawnLoss: cplAbs,
          bestMove: bestMoveForPlayer,
          actualMove: '${move.from}${move.to}${move.promotion ?? ''}',
          isMateBefore: bestIsMate,
          isMateAfter: actualIsMate,
          seeCentipawns: seeCentipawns,
          secondBestCentipawnLoss: secondBestCpl,
          playerWinPercentBefore: winBefore,
          winPercentDiff: winDiff,
        );

        // Debug logging — now shows CPL-based classification
        debugPrint(
          '📊 Move ${i + 1}: ${move.san} | '
          'Best: ${bestEval.toStringAsFixed(2)} | '
          'Actual: ${actualEval.toStringAsFixed(2)} | '
          'CPL: ${cplAbs.toStringAsFixed(0)} | '
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
            centipawnLoss: cplAbs,
            accuracy: moveAccuracy,
            isMateBefore: bestIsMate,
            isMateAfter: actualIsMate,
          ),
        );

        // Update progress — emit partial fullAnalysis so the Report tab
        // renders progressively instead of showing a spinner until the end.
        //
        // Emitting every 5 plies made the displayed accuracy lurch (99.5 -> 82.2
        // in a single step). Now that the accumulator makes a tick O(1), emit
        // every ply so the number moves smoothly; very long games fall back to
        // every 2 plies to keep the rebuild count sensible.
        final tickEvery = moves.length > 40 ? 2 : 1;
        if ((i + 1) % tickEvery == 0 || i == moves.length - 1) {
          state = state.copyWith(
            analysisProgress: (i + 1) / moves.length,
            analyzedMoves: accumulator.moves,
            fullAnalysis: accumulator.build(),
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

      // Final state — mark analysis complete
      final fullAnalysis = accumulator.build();

      state = state.copyWith(
        isAnalyzing: false,
        analysisProgress: 1.0,
        analyzedMoves: accumulator.moves,
        fullAnalysis: fullAnalysis,
      );
    } finally {
      _isAnalyzing = false;
      // Return the engine to its low-footprint live-play configuration. This
      // runs on every exit path: normal completion, cancellation and errors.
      _stockfish?.setLivePlayStrength();
      // Ensure state.isAnalyzing is always cleared, even on cancellation
      if (state.isAnalyzing) {
        state = state.copyWith(isAnalyzing: false);
      }
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
      isBatchAnalysis: isBatchAnalysis,
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
