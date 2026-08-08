import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// TEMPORARY config sweep.
///
/// Measures wall-clock and classification agreement for several
/// depth/MultiPV/Threads combinations against the current shipping config
/// (depth 15, MultiPV 3, Threads 1), on a real 24-ply game with the real
/// engine. Replaces the extrapolated speed/accuracy estimates with numbers.
///
///   flutter run -t lib/main_sweep.dart -d <device>
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _App());
}

class Cfg {
  final String name;
  final int depth;
  final int multiPv;
  final int threads;
  const Cfg(this.name, this.depth, this.multiPv, this.threads);
}

const _configs = <Cfg>[
  Cfg('REF  d15/mpv3/t1', 15, 3, 1), // what ships today
  Cfg('     d15/mpv1/t1', 15, 1, 1),
  Cfg('     d12/mpv1/t1', 12, 1, 1),
  Cfg('     d12/mpv1/t4', 12, 1, 4),
  Cfg('     d12/mpv2/t4', 12, 2, 4),
  Cfg('     d10/mpv1/t4', 10, 1, 4),
];

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

List<String> _positions() {
  final b = chess.Chess();
  final fens = <String>[b.fen];
  for (final u in _game) {
    b.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
    fens.add(b.fen);
  }
  return fens;
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _S();
}

class _S extends State<_App> {
  String _status = 'starting…';
  void _log(String s) => debugPrint('SWEEP $s');

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 12));
      final engine = StockfishService.instance;
      for (var i = 1; i <= 4; i++) {
        await engine.initialize();
        if (!engine.isUsingFallback) break;
        _log('init attempt $i hit fallback, retrying');
        engine.resetTestState();
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      if (engine.isUsingFallback) {
        _log('FATAL fallback engine');
        setState(() => _status = 'FATAL: fallback');
        return;
      }
      engine.setMaxStrength();

      final fens = _positions();
      _log('positions=${fens.length} plies=${_game.length}');

      List<MoveClassification>? refLabels;

      for (final cfg in _configs) {
        setState(() => _status = 'running ${cfg.name}…');
        engine.setAnalysisStrength(threadsOverride: cfg.threads);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        final evals = <double>[];
        final sw = Stopwatch()..start();
        var failed = false;

        for (final fen in fens) {
          try {
            final r = await engine.analyzePosition(
              fen: fen,
              depth: cfg.depth,
              multiPv: cfg.multiPv,
              isBatchAnalysis: true,
            );
            evals.add(r.evalInPawns);
          } catch (e) {
            _log('${cfg.name} ERROR $e');
            failed = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }
        sw.stop();
        if (failed) continue;

        // Classify each ply exactly as the pipeline does (carry-forward means
        // position i is "before" and i+1 is "after").
        final labels = <MoveClassification>[];
        for (var ply = 0; ply < _game.length; ply++) {
          final isWhite = ply.isEven;
          final cpl = ((isWhite
                      ? evals[ply] - evals[ply + 1]
                      : evals[ply + 1] - evals[ply]) *
                  100)
              .abs();
          labels.add(classifyMoveCpl(
            centipawnLoss: cpl,
            bestMove: null,
            actualMove: 'x',
          ));
        }

        refLabels ??= labels;
        var agree = 0;
        for (var i = 0; i < labels.length; i++) {
          if (labels[i] == refLabels[i]) agree++;
        }

        final total = sw.elapsedMilliseconds;
        _log('RESULT ${cfg.name} '
            'totalMs=$total '
            'perPosMs=${(total / fens.length).round()} '
            'gameSec=${(total / 1000).toStringAsFixed(1)} '
            'labelAgreement=$agree/${labels.length} '
            '(${(agree / labels.length * 100).toStringAsFixed(0)}%)');
      }

      engine.setLivePlayStrength();
      _log('===== DONE =====');
      setState(() => _status = 'done — logcat SWEEP');
    } catch (e, st) {
      _log('ERROR $e');
      _log('STACK $st');
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: Scaffold(body: Center(child: Text(_status))));
}
