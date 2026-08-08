import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/providers/analysis_provider.dart';

/// TEMPORARY verification entrypoint.
///
/// Runs the real analyzeFullGame pipeline on-device against the real Stockfish
/// engine and prints the per-move audit table to logcat. Run with:
///   flutter run -t lib/main_verify_analysis.dart -d <device>
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _VerifyApp());
}

/// Game A: quiet Italian — inaccuracies and mistakes, no outright blunder.
const _gameA = <String>[
  'e2e4', 'e7e5',
  'g1f3', 'b8c6',
  'f1c4', 'g8f6',
  'd2d3', 'f8c5',
  'e1g1', 'd7d6',
  'c2c3', 'c8g4',
  'h2h3', 'g4h5',
  'g2g4', 'h5g6',
  'g4g5', 'f6d7',
  'd3d4', 'e5d4',
  'c3d4', 'c5b6',
  'd4d5', 'c6e7',
];

/// Game B: contains a clear blunder — Black hangs the queen with 6...Qxg2,
/// and White has a knight sacrifice on f7 earlier for the Brilliant path.
const _gameB = <String>[
  'e2e4', 'e7e5',
  'g1f3', 'b8c6',
  'f1c4', 'f8c5',
  'b2b4', 'c5b4',
  'c2c3', 'b4a5',
  'd2d4', 'd8g5',
  'd4e5', 'g5g2',
  'h1g1', 'g2h3',
  'c4f7', 'e8e7',
  'f7g8', 'h8g8',
];

List<ChessMove> _buildMoves(List<String> uciMoves) {
  final board = chess.Chess();
  final result = <ChessMove>[];

  for (final uci in uciMoves) {
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : null;

    chess.Move? target;
    for (final m in board.generate_moves()) {
      if (m.fromAlgebraic == from &&
          m.toAlgebraic == to &&
          (promotion == null || m.promotion?.name == promotion)) {
        target = m;
        break;
      }
    }
    if (target == null) {
      debugPrint('VERIFY_ILLEGAL $uci');
      break;
    }

    final san = board.move_to_san(target);
    board.make_move(target);

    result.add(
      ChessMove(
        from: from,
        to: to,
        san: san,
        promotion: promotion,
        isCapture: target.captured != null,
        isCheck: board.in_check,
        isCheckmate: board.in_checkmate,
        isCastle: san.startsWith('O-O'),
        fen: board.fen,
      ),
    );
  }
  return result;
}

class _VerifyApp extends StatefulWidget {
  const _VerifyApp();

  @override
  State<_VerifyApp> createState() => _VerifyAppState();
}

class _VerifyAppState extends State<_VerifyApp> {
  String _status = 'starting…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _log(String line) {
    // Prefixed so it is easy to grep out of logcat.
    debugPrint('VERIFY $line');
  }

  Future<void> _run() async {
    try {
      final engine = StockfishService.instance;
      final initSw = Stopwatch()..start();
      await engine.initialize();
      initSw.stop();
      _log('ENGINE ready=${engine.isReady} fallback=${engine.isUsingFallback} '
          'initMs=${initSw.elapsedMilliseconds}');

      await _analyzeGame('GAME A (quiet Italian)', _gameA);

      setState(() => _status = 'done — see logcat (VERIFY)');
    } catch (e, st) {
      _log('ERROR $e');
      _log('STACK $st');
      setState(() => _status = 'error: $e');
    }
  }

  Future<void> _analyzeGame(String title, List<String> uciMoves) async {
    try {
      final container = ProviderContainer();
      final notifier = container.read(analysisProvider.notifier);

      final moves = _buildMoves(uciMoves);
      _log('MOVES ${moves.length}');
      setState(() => _status = 'analyzing $title (${moves.length} plies)…');

      // ── Observe the pipeline WITHOUT modifying it ──
      // Every state emission is timestamped so we can measure per-ply wall
      // clock and sample the accuracy number the UI would be rendering.
      final total = Stopwatch()..start();
      int lastCount = 0;
      int lastElapsed = 0;

      final sub = container.listen<AnalysisState>(
        analysisProvider,
        (prev, next) {
          final ms = total.elapsedMilliseconds;
          final count = next.analyzedMoves.length;

          if (count != lastCount) {
            final batchMs = ms - lastElapsed;
            final plies = count - lastCount;
            _log(
              'TICK t=${ms}ms progress=${(next.analysisProgress * 100).toStringAsFixed(0)}% '
              'plies=$count/${moves.length} batchMs=$batchMs '
              'perPlyMs=${plies > 0 ? (batchMs / plies).toStringAsFixed(0) : "-"} '
              'DISPLAYED_ACCURACY=${next.fullAnalysis?.averageAccuracy.toStringAsFixed(1) ?? "null"} '
              'white=${next.fullAnalysis?.whiteAccuracy.toStringAsFixed(1) ?? "null"} '
              'black=${next.fullAnalysis?.blackAccuracy.toStringAsFixed(1) ?? "null"} '
              'isAnalyzing=${next.isAnalyzing}',
            );
            lastCount = count;
            lastElapsed = ms;
          }
        },
        fireImmediately: true,
      );

      await notifier.loadGame(moves: moves);
      await notifier.analyzeFullGame();
      total.stop();
      sub.close();

      final state = container.read(analysisProvider);
      final analyzed = state.analyzedMoves;

      _log('TOTAL_ELAPSED_MS=${total.elapsedMilliseconds} '
          'plies=${analyzed.length} '
          'avgPerPlyMs=${analyzed.isEmpty ? 0 : (total.elapsedMilliseconds / analyzed.length).round()} '
          'searchesPerPly=2 '
          'totalSearches=${analyzed.length * 2}');

      _log('===== $title =====');
      _log(
        'MOVE     |SIDE|SAN     |EVAL_BEFORE(best)|EVAL_AFTER|ACTUAL_BEFORE'
        '|   CPL|  ACC%|CLASS',
      );
      for (final m in analyzed) {
        final label = '${(m.moveIndex ~/ 2) + 1}.${m.isWhiteMove ? '' : '...'}';
        _log(
          '${label.padRight(9)}|${m.isWhiteMove ? 'W' : 'B'}   |'
          '${m.san.padRight(8)}|'
          '${m.evalBefore.toStringAsFixed(2).padLeft(17)}|'
          '${m.evalAfter.toStringAsFixed(2).padLeft(10)}|'
          '${m.actualEvalBeforeMove.toStringAsFixed(2).padLeft(13)}|'
          '${m.centipawnLoss.toStringAsFixed(0).padLeft(6)}|'
          '${m.accuracy.toStringAsFixed(1).padLeft(6)}|'
          '${m.classification.name}',
        );
      }

      final full = state.fullAnalysis;
      if (full != null) {
        _log('White accuracy: ${full.whiteAccuracy.toStringAsFixed(1)}%');
        _log('Black accuracy: ${full.blackAccuracy.toStringAsFixed(1)}%');
        _log('Average CPL: ${full.averageCpl.toStringAsFixed(1)}');
        _log(
          'COUNTS best:${full.bestMoves} excellent:${full.excellentMoves} '
          'good:${full.goodMoves} inaccuracy:${full.inaccuracies} '
          'mistake:${full.mistakes} blunder:${full.blunders} '
          'miss:${full.misses} great:${full.greatMoves} '
          'brilliant:${full.brilliantMoves}',
        );
        _log(
          'EVAL_SERIES len=${full.evaluations.length} plies=${analyzed.length}',
        );
        _log(
          'DISTINCT_CLASSES '
          '${analyzed.map((m) => m.classification.name).toSet().join(",")}',
        );
      }
      _log('===== END $title =====');
      container.dispose();
    } catch (e, st) {
      _log('ERROR $title $e');
      _log('STACK $st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text(_status, textAlign: TextAlign.center)),
      ),
    );
  }
}
