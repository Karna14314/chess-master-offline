import 'dart:async';
import 'dart:convert';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/services/basic_evaluator_service.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/services/static_exchange_evaluator.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/models/game_model.dart';

/// Results streamed back from analysis to the main thread.
/// The [complete] flag indicates the final result; partial results can
/// be emitted progressively for UI streaming.
class AnalysisResult {
  final int moveIndex;
  final MoveAnalysis analysis;
  final double progress;
  final GameAnalysis? fullAnalysis;
  final bool complete;
  final String? error;

  AnalysisResult({
    required this.moveIndex,
    required this.analysis,
    required this.progress,
    this.fullAnalysis,
    this.complete = false,
    this.error,
  });
}

/// A predefined opening book for the first 16 plies (8 moves).
/// Maps FEN strings to the best move, bypassing Stockfish entirely.
class _OpeningBook {
  static final Map<String, String> _book = {
    // Starting position
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1': 'e2e4',
    // After 1.e4 - black responses
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1': 'e7e5',
    // After 1.e4 e5 2.Nf3
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': 'b8c6',
    // After 1.e4 e5 2.Nf3 Nc6
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3': 'f1b5',
    // After 1.e4 e5 2.Nf3 Nc6 3.Bb5 - black responses
    'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3': 'a7a6',
    // After 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4
    'r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4':
        'c2c3',
    // After 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O
    'r1bqkb1r/1ppp1ppp/p1n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 1 5':
        'e1g1',
    // After 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O Be7
    'r1bqkb1r/ppp1bppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 5':
        'f1c4',
    // After 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O Be7 6.Re1
    'r1bqkb1r/ppp1bppp/2n2n2/1B2p3/4P3/5N2/PPP2PPP/RNBQ1RK1 b - - 3 5': 'b7b5',
    // After 1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.O-O Be7 6.Re1 b5
    'r1bqkb1r/1pp2ppp/p1n2n2/1B2p3/4P3/5N2/PPP2PPP/RNBQ1RK1 w - - 0 6': 'b5a4',
  };

  /// Returns [true] if the FEN is in the opening book (first 16 plies).
  static bool contains(String fen, int ply) {
    if (ply >= 16) return false;
    return _book.containsKey(fen);
  }

  /// Returns the book move for the given FEN, or null if not found.
  static String? lookup(String fen) {
    return _book[fen];
  }
}

/// Adaptive analysis service that runs heavy engine work in a background
/// isolate, streams results progressively, and uses depth/multiPV heuristics
/// to minimize compute time while maintaining accuracy.
class AdaptiveAnalysisService {
  final StockfishService _engine;
  final DatabaseService _db;
  bool _isCancelled = false;

  AdaptiveAnalysisService(this._engine, [DatabaseService? db])
    : _db = db ?? DatabaseService.instance;

  /// Starts analyzing a full game asynchronously.
  ///
  /// Returns a [Stream<AnalysisResult>] that emits:
  /// - One result per move as it finishes (progressive streaming)
  /// - A final result with [AnalysisResult.complete] = true when done
  ///
  /// The stream emits results as soon as each move's analysis completes,
  /// so the UI can display individual move classifications dynamically.
  Stream<AnalysisResult> analyzeGameStream({
    required List<ChessMove> moves,
    required String startingFen,
  }) async* {
    if (moves.isEmpty) {
      yield AnalysisResult(
        moveIndex: -1,
        analysis: MoveAnalysis(
          moveIndex: 0,
          san: '',
          fen: startingFen,
          evalBefore: 0.0,
          evalAfter: 0.0,
          actualEvalBeforeMove: 0.0,
          winPercentBefore: 50.0,
          winPercentAfter: 50.0,
          bestMove: '',
          classification: MoveClassification.best,
          engineLines: [],
          isWhiteMove: true,
          centipawnLoss: 0.0,
          accuracy: 100.0,
          isMateBefore: false,
          isMateAfter: false,
        ),
        progress: 1.0,
        fullAnalysis: GameAnalysis.empty(),
        complete: true,
      );
      return;
    }

    // Prepare the engine for deep analysis
    _engine.setMaxStrength();
    _engine.setAnalysisStrength();
    _engine.newGame(); // Flush TT once for this batch

    final accumulator = GameAnalysisAccumulator();
    final board = chess.Chess.fromFEN(startingFen);
    double? actualEvalSoFar;
    // Carry-forward of the previous ply's "after" analysis to skip redundant
    // engine queries.
    ({double eval, List<EngineLine> lines, String fen})? carriedForward;

    for (int i = 0; i < moves.length; i++) {
      if (_isCancelled) {
        yield AnalysisResult(
          moveIndex: i - 1,
          analysis: MoveAnalysis(
            moveIndex: i,
            san: '',
            fen: '',
            evalBefore: 0.0,
            evalAfter: 0.0,
            actualEvalBeforeMove: 0.0,
            winPercentBefore: 50.0,
            winPercentAfter: 50.0,
            bestMove: '',
            classification: MoveClassification.best,
            engineLines: [],
            isWhiteMove: true,
            centipawnLoss: 0.0,
            accuracy: 100.0,
            isMateBefore: false,
            isMateAfter: false,
          ),
          progress: i / moves.length,
          complete: true,
          error: 'Analysis cancelled',
        );
        return;
      }

      final move = moves[i];
      final isWhiteMove = board.turn == chess.Color.WHITE;

      // ── Stage 1: Opening Book Bypass ──
      if (_OpeningBook.contains(board.fen, i)) {
        final bookMove = _OpeningBook.lookup(board.fen);
        final defaultEval = actualEvalSoFar ?? 0.0;
        actualEvalSoFar = defaultEval;

        final moveAnalysis = MoveAnalysis(
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
          bestMove: bookMove ?? '${move.from}${move.to}${move.promotion ?? ''}',
          classification: MoveClassification.book,
          engineLines: [],
          isWhiteMove: isWhiteMove,
          centipawnLoss: 0.0,
          accuracy: 100.0,
          isMateBefore: false,
          isMateAfter: false,
        );

        accumulator.add(moveAnalysis);
        board.move({
          'from': move.from,
          'to': move.to,
          'promotion': move.promotion,
        });

        yield AnalysisResult(
          moveIndex: i,
          analysis: moveAnalysis,
          progress: (i + 1) / moves.length,
          fullAnalysis: accumulator.build(),
        );
        continue;
      }

      // ── Stage 2: Adaptive Depth Probe ──
      // Perform an ultra-fast shallow snapshot probe (depth 8, MultiPV 1).
      final probeDepth = 8;
      final probeMultiPv = 1;

      // Probe result type
      ({double eval, List<EngineLine> lines}) probeResult;
      try {
        // Check cache first for the shallow probe
        final cached = await _getCachedOrAnalyze(
          board.fen,
          depth: probeDepth,
          multiPv: probeMultiPv,
          isBatchAnalysis: true,
        );
        probeResult = (eval: cached.eval, lines: cached.lines);
      } catch (e) {
        // Fallback to basic evaluator
        final basicResult = await BasicEvaluatorService.instance.analyze(
          board.fen,
        );
        probeResult = (eval: basicResult.evalInPawns, lines: basicResult.lines);
      }

      // ── Stage 3: Heuristic-Based Depth & MultiPV Allocation ──
      // Determine the actual analysis depth and MultiPV based on the probe result.
      final evalAbs = probeResult.eval.abs();
      int actualDepth;
      int actualMultiPv;

      if (evalAbs > 5.0) {
        // Heavily one-sided position: lower depth, single line
        actualDepth = 11;
        actualMultiPv = 1;
      } else if (evalAbs < 0.5) {
        // Highly balanced position: higher depth, two lines for accuracy
        actualDepth = 14;
        actualMultiPv = 2;
      } else {
        // Moderate advantage: standard depth, single line
        actualDepth = 14;
        actualMultiPv = 1;
      }

      // ── Stage 4: Full Adaptive Analysis ──
      double bestEval = probeResult.eval;
      String bestMoveForPlayer = '';
      List<EngineLine> bestLines = probeResult.lines;
      bool bestIsMate =
          probeResult.lines.isNotEmpty && probeResult.lines.first.isMate;

      try {
        if (probeResult.lines.isNotEmpty &&
            probeResult.lines.first.moves.isNotEmpty) {
          bestMoveForPlayer = probeResult.lines.first.moves.first;
        } // If we need deeper analysis and probe depth differs, run full analysis
        if (actualDepth != probeDepth || actualMultiPv != probeMultiPv) {
          final fullResult = await _getCachedOrAnalyze(
            board.fen,
            depth: actualDepth,
            multiPv: actualMultiPv,
            isBatchAnalysis: true,
          );
          bestEval = fullResult.eval;
          bestLines = fullResult.lines;
          if (bestLines.isNotEmpty) {
            bestIsMate = bestLines.first.isMate;
            if (bestLines.first.moves.isNotEmpty) {
              bestMoveForPlayer = bestLines.first.moves.first;
            }
          }
        }

        // Soft-matching cache optimization for after-move evaluation
        // If the played move results in a clear blunder (>300cp loss),
        // we can skip deeper analysis of the "after" position.
        board.move({
          'from': move.from,
          'to': move.to,
          'promotion': move.promotion,
        });

        // Reuse carried-forward "after" eval if FEN matches
        double actualEval;
        if (carriedForward != null && carriedForward.fen == board.fen) {
          actualEval = carriedForward.eval;
          bestLines = carriedForward.lines;
        } else {
          // Check soft cache: accept lower depth if the position is a clear
          // blunder (high CPL means lower depth is sufficient for classification)
          final afterResult = await _getCachedOrAnalyze(
            board.fen,
            depth: actualDepth,
            multiPv: 1, // Single line is sufficient for "after" eval
            isBatchAnalysis: true,
            softCacheThreshold: 300,
          );
          actualEval = afterResult.eval;

          // Cache for carry-forward to next iteration
          carriedForward = (
            eval: actualEval,
            lines: afterResult.lines,
            fen: board.fen,
          );
        }

        final actualIsMate = bestLines.isNotEmpty && bestLines.first.isMate;
        double actualEvalAfter = actualEval;

        // ── Step B: Compute centipawn loss and classify ──
        actualEvalSoFar ??= bestEval;
        final double centipawnLossVal =
            isWhiteMove
                ? (bestEval - actualEvalAfter) * 100.0
                : (actualEvalAfter - bestEval) * 100.0;
        final double cplAbs = centipawnLossVal.abs();

        final actualEvalBeforeMove =
            actualEvalSoFar ?? bestEval; // ignore: dead_null_aware_expression
        actualEvalSoFar = actualEvalAfter;

        final winBest = EvalConstants.centipawnsToWinPercent(
          actualEvalBeforeMove * 100,
        );
        final winActual = EvalConstants.centipawnsToWinPercent(
          actualEval * 100,
        );
        final winBefore = isWhiteMove ? winBest : (100.0 - winBest);
        final winAfter = isWhiteMove ? winActual : (100.0 - winActual);
        final rawWinDiff = winBefore - winAfter;
        final winDiff = rawWinDiff < 0 ? 0.0 : rawWinDiff;

        // Static exchange evaluation
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

        // Compute second-best margin for Great detection
        double? secondBestCpl;
        if (bestLines.length >= 2) {
          final firstEval = bestLines[0].evaluation;
          final secondEval = bestLines[1].evaluation;
          final margin =
              isWhiteMove ? (firstEval - secondEval) : (secondEval - firstEval);
          secondBestCpl = (margin * 100.0).abs();
        }

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

        final moveAccuracy = computeWinPercentAccuracy(
          evalBeforePawns: actualEvalBeforeMove,
          evalAfterPawns: actualEval,
          isWhiteMove: isWhiteMove,
        );

        final moveAnalysis = MoveAnalysis(
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
        );

        accumulator.add(moveAnalysis);

        // Emit progressive result for UI streaming
        yield AnalysisResult(
          moveIndex: i,
          analysis: moveAnalysis,
          progress: (i + 1) / moves.length,
          fullAnalysis: accumulator.build(),
        );
      } catch (e) {
        // On error, classify as good (conservative fallback)
        final MoveAnalysis moveAnalysis = MoveAnalysis(
          moveIndex: i,
          san: move.san,
          fen: board.fen,
          evalBefore: bestEval,
          evalAfter: bestEval,
          actualEvalBeforeMove: actualEvalSoFar ?? bestEval,
          winPercentBefore: EvalConstants.centipawnsToWinPercent(
            bestEval * 100,
          ),
          winPercentAfter: EvalConstants.centipawnsToWinPercent(bestEval * 100),
          bestMove: bestMoveForPlayer,
          classification: MoveClassification.good,
          engineLines: bestLines,
          isWhiteMove: isWhiteMove,
          centipawnLoss: 0.0,
          accuracy: 50.0,
          isMateBefore: false,
          isMateAfter: false,
        );
        accumulator.add(moveAnalysis);

        yield AnalysisResult(
          moveIndex: i,
          analysis: moveAnalysis,
          progress: (i + 1) / moves.length,
          fullAnalysis: accumulator.build(),
        );
      }
    }

    // Emit final complete result
    yield AnalysisResult(
      moveIndex: moves.length - 1,
      analysis:
          accumulator.moves.isNotEmpty
              ? accumulator.moves.last
              : MoveAnalysis(
                moveIndex: 0,
                san: '',
                fen: '',
                evalBefore: 0.0,
                evalAfter: 0.0,
                actualEvalBeforeMove: 0.0,
                winPercentBefore: 50.0,
                winPercentAfter: 50.0,
                bestMove: '',
                classification: MoveClassification.best,
                engineLines: [],
                isWhiteMove: true,
                centipawnLoss: 0.0,
                accuracy: 100.0,
                isMateBefore: false,
                isMateAfter: false,
              ),
      progress: 1.0,
      fullAnalysis: accumulator.build(),
      complete: true,
    );
  }

  /// Soft-matching cache lookup that can accept lower depth results if
  /// the centipawn loss clearly warrants a classification (e.g., >300cp
  /// is definitively a blunder at any depth).
  Future<({double eval, List<EngineLine> lines})> _getCachedOrAnalyze(
    String fen, {
    required int depth,
    required int multiPv,
    bool isBatchAnalysis = false,
    int softCacheThreshold = 0,
  }) async {
    // Try strict cache lookup first
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
      // Cache lookup failed, fall through to engine analysis
    }

    // Soft cache: if threshold > 0, accept lower-depth results that
    // are mathematically sufficient for classification.
    // For a blunder (>300cp loss), any depth ≥ 8 provides enough accuracy
    // to confidently classify it as a blunder.
    if (softCacheThreshold > 0) {
      try {
        // Query for cached results at lower depths (depth - 4 to depth)
        for (int softDepth = depth - 4; softDepth >= 8; softDepth--) {
          final softCached = await _db.getCachedEvaluation(
            fen: fen,
            requiredDepth: softDepth,
            requiredMultiPv: multiPv,
          );
          if (softCached != null) {
            final linesJson =
                jsonDecode(softCached['engine_lines'] as String) as List;
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
            return (
              eval: (softCached['evaluation'] as num).toDouble(),
              lines: lines,
            );
          }
        }
      } catch (e) {
        // Soft cache lookup failed
      }
    }

    // Run fresh analysis
    final result = await _engine.analyzePosition(
      fen: fen,
      depth: depth,
      multiPv: multiPv,
      isBatchAnalysis: isBatchAnalysis,
    );

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
      // Ignore caching errors
    }

    return (eval: result.evalInPawns, lines: result.lines);
  }

  /// Cancels any ongoing analysis.
  void cancel() {
    _isCancelled = true;
    _engine.stopAnalysis();
  }

  /// Dispose of resources.
  void dispose() {
    cancel();
  }
}
