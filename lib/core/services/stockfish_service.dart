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
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<AnalysisResult> _analysisStreamController =
      StreamController<AnalysisResult>.broadcast();

  /// Singleton instance
  static StockfishService get instance {
    _instance ??= StockfishService._();
    return _instance!;
  }

  StockfishService._();

  /// Stream of engine output
  Stream<String> get outputStream => _outputController.stream;

  /// Stream of progressive analysis results
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
      // Engine initialization failed - this is acceptable for basic gameplay
      // Games can still be played without engine (local multiplayer, manual analysis)
      debugPrint('Stockfish engine initialization failed: $e');
      debugPrint('Games can still be played in local multiplayer mode');
      _isReady = false;
      // Don't rethrow - allow app to continue without engine
    }
  }

  /// Configure engine options for optimal mobile performance
  void _configureEngine() {
    // Limit threads for mobile
    _sendCommand('setoption name Threads value 2');
    // Limit hash table size
    _sendCommand('setoption name Hash value 64');
    // Enable skill level control
    _sendCommand('setoption name UCI_LimitStrength value true');
  }

  /// Wait for engine to be ready
  Future<void> _waitForReady() async {
    _isReady = false; // Reset ready state
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
  /// [fen] - Position in FEN notation
  /// [depth] - Search depth (1-22)
  /// [thinkTimeMs] - Optional think time limit in milliseconds
  Future<BestMoveResult> getBestMove({
    required String fen,
    required int depth,
    int? thinkTimeMs,
  }) async {
    if (!_isReady) {
      await initialize();
    }

    // Ensure engine settings are correct for play
    _sendCommand('setoption name UCI_LimitStrength value true');

    final completer = Completer<BestMoveResult>();
    String? bestMove;
    String? ponderMove;
    int? evaluation;
    int? mateIn;

    // Track best move found so far in case of timeout
    String bestMoveSoFar = '';

    StreamSubscription<String>? subscription;

    void cleanup() {
      subscription?.cancel();
      subscription = null;
    }

    subscription = _outputController.stream.listen(
      (line) {
        // Parse evaluation from info line
        if (line.startsWith('info') && line.contains('score')) {
          final info = parseInfoLine(line);
          if (info.cp != null) evaluation = info.cp;
          if (info.mate != null) mateIn = info.mate;

          // Capture best move from pv if available as fallback
          if (info.moves != null && info.moves!.isNotEmpty) {
            bestMoveSoFar = info.moves!.first;
          }
        }

        // Parse best move
        if (line.startsWith('bestmove')) {
          final parts = line.split(' '); // Keep split here as it's short
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

    // Set position
    _sendCommand('position fen $fen');

    // Start search
    if (thinkTimeMs != null) {
      _sendCommand('go depth $depth movetime $thinkTimeMs');
    } else {
      _sendCommand('go depth $depth');
    }

    // Timeout after 30 seconds
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
  /// Returns evaluation and top engine lines
  /// Also emits intermediate results to [analysisStream]
  Future<AnalysisResult> analyzePosition({
    required String fen,
    int depth = AppConstants.analysisDepth,
    int multiPv = AppConstants.topEngineLinesCount,
  }) async {
    if (!_isReady) {
      await initialize();
    }

    final completer = Completer<AnalysisResult>();
    final lines = <EngineLine>[];
    // Keep track of latest evaluations for each line to construct partial results
    final currentLines = <int, EngineLine>{};

    int? mainEvaluation;
    int? mateIn;

    StreamSubscription<String>? subscription;

    void cleanup() {
      subscription?.cancel();
      subscription = null;
    }

    // Set MultiPV for multiple lines
    _sendCommand('setoption name MultiPV value $multiPv');

    subscription = _outputController.stream.listen(
      (line) {
        if (line.startsWith('info') && line.contains(' pv ')) {
          final info = parseInfoLine(line);

          if (info.moves != null) {
            final pvNumber = info.multipv ?? 1;
            final currentDepth = info.depth ?? 0;
            final eval = info.cp;
            final mate = info.mate;

            // Store the main line evaluation
            if (pvNumber == 1) {
              mainEvaluation = eval;
              mateIn = mate;
            }

            final engineLine = EngineLine(
              moves: info.moves!,
              evaluation: eval,
              mateIn: mate,
              depth: currentDepth,
            );

            // Update lines map
            currentLines[pvNumber] = engineLine;

            // Update final list (for legacy compatibility)
            if (lines.length >= pvNumber) {
              lines[pvNumber - 1] = engineLine;
            } else {
              lines.add(engineLine);
            }

            // Emit progressive update
            _analysisStreamController.add(
              AnalysisResult(
                evaluation: mainEvaluation ?? 0,
                mateIn: mateIn,
                lines:
                    currentLines.values.toList()..sort((a, b) {
                      // Heuristic sort based on evaluation if available, otherwise keep order
                      // But typically multipv comes in order 1..N
                      return 0;
                    }),
                depth: currentDepth,
              ),
            );
          }
        }

        if (line.startsWith('bestmove')) {
          cleanup();
          // Reset MultiPV to 1
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

    // Set position and analyze
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

  /// Helper to parse info line efficiently using indexOf
  @visibleForTesting
  ({int? depth, int? multipv, int? cp, int? mate, List<String>? moves})
  parseInfoLine(String line) {
    int? depth;
    int? multipv;
    int? cp;
    int? mate;
    List<String>? moves;

    // Optimized parsing using indexOf and substring
    // Keys usually have spaces around them

    // Depth
    depth = _parseValue(line, ' depth ');

    // MultiPV
    multipv = _parseValue(line, ' multipv ');

    // Score
    cp = _parseValue(line, ' score cp ');
    mate = _parseValue(line, ' score mate ');

    // PV moves
    final pvIndex = line.indexOf(' pv ');
    if (pvIndex != -1) {
      final movesStr = line.substring(pvIndex + 4);
      moves = <String>[];
      int startIndex = 0;
      while (startIndex < movesStr.length) {
        int spaceIndex = movesStr.indexOf(' ', startIndex);
        if (spaceIndex == -1) {
          if (startIndex < movesStr.length) {
            moves.add(movesStr.substring(startIndex));
          }
          break;
        }
        if (spaceIndex > startIndex) {
          moves.add(movesStr.substring(startIndex, spaceIndex));
        }
        startIndex = spaceIndex + 1;
      }
    }

    return (depth: depth, multipv: multipv, cp: cp, mate: mate, moves: moves);
  }

  /// Helper to parse integer value after a key
  int? _parseValue(String text, String key) {
    final index = text.indexOf(key);
    if (index != -1) {
      final start = index + key.length;
      int end = text.indexOf(' ', start);
      if (end == -1) end = text.length;
      return int.tryParse(text.substring(start, end));
    }
    return null;
  }

  /// Set the engine skill level (affects playing strength)
  void setSkillLevel(int elo) {
    _sendCommand('setoption name UCI_Elo value $elo');
  }

  /// Stop any ongoing analysis
  void stopAnalysis() {
    _sendCommand('stop');
  }

  /// Start a new game
  void newGame() {
    _sendCommand('ucinewgame');
  }

  /// Dispose the engine
  void dispose() {
    _stockfish?.dispose();
    _stockfish = null;
    _isReady = false;
    _outputController.close();
    _analysisStreamController.close();
  }
}

/// Result of a best move search
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

  /// Parse UCI move format (e.g., "e2e4") to from/to squares
  (String from, String to, String? promotion) get parsedMove {
    if (bestMove.length < 4) return ('', '', null);

    final from = bestMove.substring(0, 2);
    final to = bestMove.substring(2, 4);
    final promotion = bestMove.length > 4 ? bestMove.substring(4, 5) : null;

    return (from, to, promotion);
  }

  bool get isValid => bestMove.isNotEmpty && bestMove.length >= 4;
}

/// Result of position analysis
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

  /// Get evaluation in pawns (centipawns / 100)
  double get evalInPawns => evaluation / 100.0;

  /// Get formatted evaluation string
  String get formattedEval {
    if (mateIn != null) {
      return mateIn! > 0 ? 'M$mateIn' : '-M${mateIn!.abs()}';
    }
    final sign = evaluation >= 0 ? '+' : '';
    return '$sign${evalInPawns.toStringAsFixed(1)}';
  }
}

/// A single engine analysis line
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

  /// Get evaluation in pawns
  double get evalInPawns => (evaluation ?? 0) / 100.0;

  /// Get formatted evaluation string
  String get formattedEval {
    if (mateIn != null) {
      return mateIn! > 0 ? 'M$mateIn' : '-M${mateIn!.abs()}';
    }
    final sign = (evaluation ?? 0) >= 0 ? '+' : '';
    return '$sign${evalInPawns.toStringAsFixed(1)}';
  }
}
