import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

/// TEMPORARY measurement harness for the `go nodes` prototype.
///
/// For every position of a real game it runs, back to back:
///   1. CHEAP    — `go nodes N`, MultiPV 1
///   2. REFERENCE— `go depth 15`, MultiPV 3   (what ships today)
/// and logs both evals side by side so the agreement rate and the width of the
/// gray zone can be measured rather than guessed.
///
/// Also re-runs the cheap pass a second time to prove determinism.
///
///   flutter run -t lib/main_verify_nodes.dart -d <device>
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _App());
}

/// Node budgets to compare. Lower = faster, noisier.
const _budgets = <int>[50000];

const _game = <String>[
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

/// Every position of the game: start plus the position after each ply.
List<String> _positions() {
  final board = chess.Chess();
  final fens = <String>[board.fen];
  for (final uci in _game) {
    board.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
    });
    fens.add(board.fen);
  }
  return fens;
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String _status = 'starting…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _log(String s) => debugPrint('NODES $s');

  Future<void> _run() async {
    try {
      // Let the platform settle before touching the native engine: calling
      // initialize() in the first frame races the Stockfish binary's own
      // startup and loses the uciok handshake.
      await Future<void>.delayed(const Duration(seconds: 12));

      final engine = StockfishService.instance;
      // Retry the handshake: on a cold start the native binary can still be
      // coming up when initialize() runs, and the service latches to fallback.
      for (var attempt = 1; attempt <= 4; attempt++) {
        await engine.initialize();
        if (!engine.isUsingFallback) break;
        _log('ENGINE attempt $attempt hit fallback, retrying…');
        engine.resetTestState();
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      _log('ENGINE ready=${engine.isReady} fallback=${engine.isUsingFallback}');
      if (engine.isUsingFallback) {
        setState(() => _status = 'ERROR: fallback engine');
        return;
      }

      engine.setMaxStrength();
      engine.setAnalysisStrength();

      final fens = _positions();
      _log('POSITIONS ${fens.length}');

      // ── Reference pass: what ships today ──
      setState(() => _status = 'reference pass (depth 15, MultiPV 3)…');
      final refEval = <double>[];
      final refMs = <int>[];
      final refTotal = Stopwatch()..start();
      for (final fen in fens) {
        final sw = Stopwatch()..start();
        final r = await engine.analyzePosition(
          fen: fen,
          depth: 15,
          multiPv: 3,
          isBatchAnalysis: true,
        );
        sw.stop();
        refEval.add(r.evalInPawns);
        refMs.add(sw.elapsedMilliseconds);
      }
      refTotal.stop();
      _log('REFERENCE totalMs=${refTotal.elapsedMilliseconds} '
          'avgMs=${(refTotal.elapsedMilliseconds / fens.length).round()}');

      // ── Cheap passes at each node budget ──
      final cheapEval = <int, List<double>>{};
      for (final budget in _budgets) {
        setState(() => _status = 'cheap pass nodes=$budget…');
        final evals = <double>[];
        final total = Stopwatch()..start();
        for (final fen in fens) {
          final r = await engine.analyzePosition(
            fen: fen,
            nodes: budget,
            multiPv: 1,
            isBatchAnalysis: true,
          );
          evals.add(r.evalInPawns);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        total.stop();
        cheapEval[budget] = evals;

        final avg = total.elapsedMilliseconds / fens.length;
        // Projected full-game cost: 1 new position per ply (carry-forward).
        _log('CHEAP nodes=$budget totalMs=${total.elapsedMilliseconds} '
            'avgMsPerPos=${avg.round()} '
            'projected24PlyMs=${(avg * (fens.length)).round()}');
      }

      // ── Determinism: repeat the middle budget ──
      const detBudget = 150000;
      setState(() => _status = 'determinism check…');
      final second = <double>[];
      for (final fen in fens) {
        final r = await engine.analyzePosition(
          fen: fen,
          nodes: detBudget,
          multiPv: 1,
          isBatchAnalysis: true,
        );
        second.add(r.evalInPawns);
      }
      final first = cheapEval[detBudget]!;
      int mismatches = 0;
      for (int i = 0; i < first.length; i++) {
        if (first[i] != second[i]) {
          mismatches++;
          _log('DETERMINISM_MISMATCH pos=$i a=${first[i]} b=${second[i]}');
        }
      }
      _log('DETERMINISM nodes=$detBudget mismatches=$mismatches/${first.length}');

      // ── Per-position comparison table ──
      for (final budget in _budgets) {
        final evals = cheapEval[budget]!;
        _log('===== BUDGET $budget =====');
        _log('POS | REF(d15) | CHEAP    | DIFF(cp)');
        double worst = 0;
        double sumAbs = 0;
        for (int i = 0; i < evals.length; i++) {
          final diffCp = (evals[i] - refEval[i]).abs() * 100;
          sumAbs += diffCp;
          if (diffCp > worst) worst = diffCp;
          _log('${i.toString().padLeft(3)} | '
              '${refEval[i].toStringAsFixed(2).padLeft(8)} | '
              '${evals[i].toStringAsFixed(2).padLeft(8)} | '
              '${diffCp.toStringAsFixed(0).padLeft(8)}');
        }
        _log('BUDGET $budget meanAbsDiffCp=${(sumAbs / evals.length).toStringAsFixed(1)} '
            'worstAbsDiffCp=${worst.toStringAsFixed(0)}');
      }

      // ── CPL agreement: does the cheap pass pick the same verdict? ──
      // CPL for ply i uses position i (before) and i+1 (after), which is
      // exactly how the real pipeline computes it after carry-forward.
      for (final budget in _budgets) {
        final evals = cheapEval[budget]!;
        int agree = 0;
        int grayZone = 0;
        int wrongSide = 0;
        for (int ply = 0; ply < _game.length; ply++) {
          final isWhite = ply.isEven;
          double cpl(List<double> e) {
            final d = isWhite
                ? (e[ply] - e[ply + 1])
                : (e[ply + 1] - e[ply]);
            return (d * 100).abs();
          }

          final refCpl = cpl(refEval);
          final cheapCpl = cpl(evals);

          // Confident band: cheap pass is far from any boundary.
          final confident = cheapCpl < 5 || cheapCpl > 400;
          if (!confident) {
            grayZone++;
            continue;
          }
          // Did the confident call actually hold up against depth 15?
          final refConfidentSame =
              (cheapCpl < 5 && refCpl < 20) || (cheapCpl > 400 && refCpl > 200);
          if (refConfidentSame) {
            agree++;
          } else {
            wrongSide++;
            _log('CONFIDENT_BUT_WRONG budget=$budget ply=$ply '
                'cheapCpl=${cheapCpl.toStringAsFixed(0)} '
                'refCpl=${refCpl.toStringAsFixed(0)}');
          }
        }
        _log('TRIAGE budget=$budget plies=${_game.length} '
            'confidentCorrect=$agree confidentWrong=$wrongSide '
            'grayZoneNeedsEscalation=$grayZone '
            'escalationRate=${(grayZone / _game.length * 100).toStringAsFixed(0)}%');
      }

      engine.setLivePlayStrength();
      _log('===== DONE =====');
      setState(() => _status = 'done — see logcat (NODES)');
    } catch (e, st) {
      _log('ERROR $e');
      _log('STACK $st');
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(body: Center(child: Text(_status))),
      );
}
