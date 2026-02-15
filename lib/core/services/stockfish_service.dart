import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Service class for interacting with the Stockfish chess engine
/// Uses UCI (Universal Chess Interface) protocol
class StockfishService {
  static StockfishService? _instance;
  Stockfish? _stockfish;
  bool _isReady = false;
  bool _isBusy = false;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<AnalysisInfo> _infoController =
      StreamController<AnalysisInfo>.broadcast();
  final StreamController<AnalysisResult> _analysisStreamController =
      StreamController<AnalysisResult>.broadcast();

  /// Singleton instance
  static StockfishService get instance {
    _instance ??= StockfishService._();
    return _instance!;
  }

  StockfishService._();

  /// Stream of engine output (raw lines)
  Stream<String> get outputStream => _outputController.stream;

  /// Stream of parsed analysis info
  Stream<AnalysisInfo> get infoStream => _infoController.stream;

  /// Stream of progressive analysis results (aggregated)
  Stream<AnalysisResult> get analysisStream => _analysisStreamController.stream;

  /// Whether the engine is initialized and ready
  bool get isReady => _isReady;

  /// Initialize the Stockfish engine
  Future<void> initialize() async {
    if (_stockfish != null && _isReady) return;

    try {
      _stockfish = Stockfish();

      bool uciOkReceived = false;

      // Listen to engine output
      _stockfish!.stdout.listen((line) {
        _outputController.add(line);

        // Parse info lines centrally
        if (line.startsWith('info') && !line.contains('string')) {
          try {
            final info = StockfishParser.parse(line);
            _infoController.add(info);
          } catch (e) {
            // Ignore parse errors for malformed lines
          }
        }

        if (line.contains('uciok')) {
          uciOkReceived = true;
        }
        if (line.contains('readyok')) {
          _isReady = true;
        }
      });

      // Initialize UCI mode
      _sendCommand('uci');

      // Wait for uciok
      int attempts = 0;
      while (!uciOkReceived && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Wait for engine to be ready with timeout
      await _waitForReady();

      // Configure engine for mobile performance
      _configureEngine();
    } catch (e) {
      debugPrint('Stockfish engine initialization failed: $e');
      _isReady = false;
    }
  }

  /// Configure engine options for optimal mobile performance
  void _configureEngine() {
    _sendCommand('setoption name Threads value 2');
    _sendCommand('setoption name Hash value 64');
    _sendCommand('setoption name UCI_LimitStrength value true');
  }

  /// Wait for engine to be ready
  Future<void> _waitForReady() async {
    _isReady = false;
    _sendCommand('isready');

    int attempts = 0;
    while (!_isReady && attempts < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!_isReady) {
      throw Exception('Stockfish failed to initialize after 10 seconds');
    }
  }

  /// Send a command to the engine
  void _sendCommand(String command) {
    if (_stockfish != null) {
      _stockfish?.stdin = command;
    }
  }

  /// Get the best move for a given position
  Future<BestMoveResult> getBestMove({
    required String fen,
    required int depth,
    int? thinkTimeMs,
  }) async {
    if (!_isReady) {
      await initialize();
    }

    // Busy check
    if (_isBusy) {
      stopAnalysis();
      // Give it a moment to stop
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isBusy = true;

    _sendCommand('setoption name UCI_LimitStrength value true');

    final completer = Completer<BestMoveResult>();
    String? bestMove;
    String? ponderMove;
    int? evaluation;
    int? mateIn;

    String bestMoveSoFar = '';

    StreamSubscription<String>? outputSub;
    StreamSubscription<AnalysisInfo>? infoSub;

    void cleanup() {
      outputSub?.cancel();
      infoSub?.cancel();
      outputSub = null;
      infoSub = null;
      _isBusy = false;
    }

    // Listen to parsed info for progressive updates
    infoSub = _infoController.stream.listen((info) {
      if (info.cp != null) evaluation = info.cp;
      if (info.mate != null) mateIn = info.mate;

      // We only care about the best move from the main line (multipv 1 or null)
      if ((info.multipv == null || info.multipv == 1) &&
          info.moves.isNotEmpty) {
        bestMoveSoFar = info.moves.first;
      }
    });

    outputSub = _outputController.stream.listen(
      (line) {
        if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            bestMove = parts[1];
          }
          if (parts.length >= 4 && parts[2] == 'ponder') {
            ponderMove = parts[3];
          }

          cleanup();
          if (!completer.isCompleted) {
            completer.complete(
              BestMoveResult(
                bestMove: bestMove ?? bestMoveSoFar,
                ponderMove: ponderMove,
                evaluation: evaluation,
                mateIn: mateIn,
              ),
            );
          }
        }
      },
      onError: (e) {
        cleanup();
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    _sendCommand('position fen $fen');

    if (thinkTimeMs != null) {
      _sendCommand('go depth $depth movetime $thinkTimeMs');
    } else {
      _sendCommand('go depth $depth');
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        cleanup();
        _sendCommand('stop');
        return BestMoveResult(bestMove: bestMoveSoFar, evaluation: evaluation);
      },
    );
  }

  /// Analyze a position and get multiple lines
  Future<AnalysisResult> analyzePosition({
    required String fen,
    int depth = AppConstants.analysisDepth,
    int multiPv = AppConstants.topEngineLinesCount,
  }) async {
    if (!_isReady) {
      await initialize();
    }

    if (_isBusy) {
      stopAnalysis();
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isBusy = true;

    final completer = Completer<AnalysisResult>();
    final lines = <EngineLine>[];
    final currentLines = <int, EngineLine>{};

    int? mainEvaluation;
    int? mateIn;

    StreamSubscription<String>? outputSub;
    StreamSubscription<AnalysisInfo>? infoSub;

    void cleanup() {
      outputSub?.cancel();
      infoSub?.cancel();
      outputSub = null;
      infoSub = null;
      _isBusy = false;
    }

    _sendCommand('setoption name MultiPV value $multiPv');

    // Listen to info stream for analysis updates
    infoSub = _infoController.stream.listen((info) {
      if (info.moves.isNotEmpty) {
        final pvNumber = info.multipv ?? 1;
        final currentDepth = info.depth ?? 0;
        final eval = info.cp;
        final mate = info.mate;

        if (pvNumber == 1) {
          mainEvaluation = eval;
          mateIn = mate;
        }

        final engineLine = EngineLine(
          moves: info.moves,
          evaluation: eval,
          mateIn: mate,
          depth: currentDepth,
        );

        currentLines[pvNumber] = engineLine;

        // Reconstruct lines list from map
        lines.clear();
        final sortedKeys = currentLines.keys.toList()..sort();
        for (final key in sortedKeys) {
          lines.add(currentLines[key]!);
        }

        _analysisStreamController.add(
          AnalysisResult(
            evaluation: mainEvaluation ?? 0,
            mateIn: mateIn,
            lines: List.from(lines),
            depth: currentDepth,
          ),
        );
      }
    });

    outputSub = _outputController.stream.listen(
      (line) {
        if (line.startsWith('bestmove')) {
          cleanup();
          _sendCommand('setoption name MultiPV value 1');

          if (!completer.isCompleted) {
            completer.complete(
              AnalysisResult(
                evaluation: mainEvaluation ?? 0,
                mateIn: mateIn,
                lines: lines,
                depth: depth,
              ),
            );
          }
        }
      },
      onError: (e) {
        cleanup();
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    _sendCommand('position fen $fen');
    _sendCommand('go depth $depth');

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        cleanup();
        _sendCommand('stop');
        _sendCommand('setoption name MultiPV value 1');
        return AnalysisResult(
          evaluation: mainEvaluation ?? 0,
          lines: lines,
          depth: 0,
        );
      },
    );
  }

  void setSkillLevel(int elo) {
    _sendCommand('setoption name UCI_Elo value $elo');
  }

  void stopAnalysis() {
    if (_isBusy) {
      _sendCommand('stop');
      // We don't set _isBusy = false here immediately because engine takes time to stop
      // and emit bestmove. The command just signals it to stop.
    }
  }

  void newGame() {
    _sendCommand('ucinewgame');
    _isBusy = false;
  }

  void dispose() {
    _stockfish?.dispose();
    _stockfish = null;
    _isReady = false;
    _outputController.close();
    _infoController.close();
    _analysisStreamController.close();
  }

  // Expose parser for testing
  @visibleForTesting
  static AnalysisInfo parseInfoLine(String line) => StockfishParser.parse(line);
}

/// Helper class for parsing Stockfish output efficiently
class StockfishParser {
  /// Parse an info line into structured data
  /// [maxMoves] - Optional limit on number of PV moves to parse (optimization)
  static AnalysisInfo parse(String line, {int? maxMoves}) {
    // "info depth 20 ... pv e2e4 ..."

    // Quick check if line has relevant info
    if (!line.startsWith('info')) return AnalysisInfo.empty();

    // We can use indexOf from the start for keys, but since we scan sequentially,
    // we can optimize by only searching forward if keys are ordered.
    // But Stockfish keys order is not strictly guaranteed (though usually consistent).
    // Using simple indexOf is O(N) per key, which is fine for line length < 1000.

    // Parse numeric values
    final depth = _parseValue(line, ' depth ');
    final multipv = _parseValue(line, ' multipv ');
    final cp = _parseValue(line, ' score cp ');
    final mate = _parseValue(line, ' score mate ');

    // Parse PV moves
    List<String> moves = [];
    final pvIndex = line.indexOf(' pv ');
    if (pvIndex != -1) {
      // Moves start after " pv "
      int startIndex = pvIndex + 4;
      final length = line.length;

      // Optimization: Manual parsing to avoid creating intermediate substrings/lists
      // and to support maxMoves limit

      int movesFound = 0;
      while (startIndex < length) {
        // Skip leading spaces
        while (startIndex < length && line[startIndex] == ' ') {
          startIndex++;
        }
        if (startIndex >= length) break;

        // Find end of move
        int endIndex = line.indexOf(' ', startIndex);
        if (endIndex == -1) endIndex = length;

        // Extract move
        if (endIndex > startIndex) {
          moves.add(line.substring(startIndex, endIndex));
          movesFound++;

          if (maxMoves != null && movesFound >= maxMoves) break;
        }

        startIndex = endIndex + 1;
      }
    }

    return AnalysisInfo(
      depth: depth,
      multipv: multipv,
      cp: cp,
      mate: mate,
      moves: moves,
    );
  }

  static int? _parseValue(String text, String key) {
    final index = text.indexOf(key);
    if (index != -1) {
      final start = index + key.length;
      int end = text.indexOf(' ', start);
      if (end == -1) end = text.length;
      // Use tryParse to be safe
      return int.tryParse(text.substring(start, end));
    }
    return null;
  }
}

class AnalysisInfo {
  final int? depth;
  final int? multipv;
  final int? cp;
  final int? mate;
  final List<String> moves;

  const AnalysisInfo({
    this.depth,
    this.multipv,
    this.cp,
    this.mate,
    this.moves = const [],
  });

  factory AnalysisInfo.empty() => const AnalysisInfo();
}

class BestMoveResult {
  final String bestMove;
  final String? ponderMove;
  final int? evaluation;
  final int? mateIn;

  BestMoveResult({
    required this.bestMove,
    this.ponderMove,
    this.evaluation,
    this.mateIn,
  });

  (String from, String to, String? promotion) get parsedMove {
    if (bestMove.length < 4) return ('', '', null);
    final from = bestMove.substring(0, 2);
    final to = bestMove.substring(2, 4);
    final promotion = bestMove.length > 4 ? bestMove.substring(4, 5) : null;
    return (from, to, promotion);
  }

  bool get isValid => bestMove.isNotEmpty && bestMove.length >= 4;
}

class AnalysisResult {
  final int evaluation;
  final int? mateIn;
  final List<EngineLine> lines;
  final int depth;

  AnalysisResult({
    required this.evaluation,
    this.mateIn,
    required this.lines,
    required this.depth,
  });

  double get evalInPawns => evaluation / 100.0;
}

class EngineLine {
  final List<String> moves;
  final int? evaluation;
  final int? mateIn;
  final int depth;

  EngineLine({
    required this.moves,
    this.evaluation,
    this.mateIn,
    required this.depth,
  });

  double get evalInPawns => (evaluation ?? 0) / 100.0;
}
