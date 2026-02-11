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
  final StreamController<AnalysisInfo> _infoController =
      StreamController<AnalysisInfo>.broadcast();

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
        _parseAndEmitInfo(line);
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
      debugPrint('Stockfish engine initialization failed: $e');
      debugPrint('Games can still be played in local multiplayer mode');
      _isReady = false;
    }
  }

  /// Parse engine output line and emit AnalysisInfo if applicable
  void _parseAndEmitInfo(String line) {
    if (!line.startsWith('info') || !line.contains(' pv ')) return;

    final pvIndex = line.indexOf(' pv ');
    if (pvIndex == -1) return;

    // Optimized parsing logic
    // Extract moves (part after ' pv ')
    final movesStr = line.substring(pvIndex + 4);
    // Splitting moves is unavoidable but we limit it to the moves part
    final moves = movesStr.split(' ');

    // Parse other info (part before ' pv ')
    final infoPart = line.substring(0, pvIndex);

    final multiPv = _parseValue(infoPart, ' multipv ') ?? 1;
    final depth = _parseValue(infoPart, ' depth ') ?? 0;
    final eval = _parseValue(infoPart, ' score cp ');
    final mate = _parseValue(infoPart, ' score mate ');

    _infoController.add(
      AnalysisInfo(
        depth: depth,
        multiPv: multiPv,
        evaluation: eval,
        mateIn: mate,
        pv: moves,
      ),
    );
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

    final completer = Completer<BestMoveResult>();
    String? bestMove;
    String? ponderMove;
    int? lastEvaluation;
    int? lastMateIn;

    // Listen for info updates to get evaluation
    final infoSubscription = _infoController.stream.listen((info) {
      if (info.multiPv == 1) {
        lastEvaluation = info.evaluation;
        lastMateIn = info.mateIn;
      }
    });

    late StreamSubscription outputSubscription;
    outputSubscription = _outputController.stream.listen((line) {
      // Parse best move
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          bestMove = parts[1];
        }
        if (parts.length >= 4 && parts[2] == 'ponder') {
          ponderMove = parts[3];
        }

        infoSubscription.cancel();
        outputSubscription.cancel();
        completer.complete(
          BestMoveResult(
            bestMove: bestMove ?? '',
            ponderMove: ponderMove,
            evaluation: lastEvaluation,
            mateIn: lastMateIn,
          ),
        );
      }
    });

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
        infoSubscription.cancel();
        outputSubscription.cancel();
        _sendCommand('stop');
        return BestMoveResult(bestMove: '', evaluation: 0);
      },
    );
  }

  /// Analyze a position and get multiple lines
  /// Returns evaluation and top engine lines
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
    int? mainEvaluation;
    int? mateIn;

    // Set MultiPV for multiple lines
    _sendCommand('setoption name MultiPV value $multiPv');

    late StreamSubscription infoSubscription;
    infoSubscription = _infoController.stream.listen((info) {
      // Store the main line evaluation
      if (info.multiPv == 1) {
        mainEvaluation = info.evaluation;
        mateIn = info.mateIn;
      }

      // Update or add line
      final line = EngineLine(
        moves: info.pv,
        evaluation: info.evaluation,
        mateIn: info.mateIn,
        depth: info.depth,
      );

      if (lines.length >= info.multiPv) {
        lines[info.multiPv - 1] = line;
      } else {
        // Ensure list is large enough (fill gaps if needed, though usually sequential)
        while (lines.length < info.multiPv - 1) {
          lines.add(EngineLine(moves: [], depth: 0));
        }
        lines.add(line);
      }
    });

    late StreamSubscription outputSubscription;
    outputSubscription = _outputController.stream.listen((line) {
      if (line.startsWith('bestmove')) {
        infoSubscription.cancel();
        outputSubscription.cancel();
        // Reset MultiPV to 1
        _sendCommand('setoption name MultiPV value 1');

        completer.complete(
          AnalysisResult(
            evaluation: mainEvaluation ?? 0,
            mateIn: mateIn,
            lines: lines,
            depth: depth,
          ),
        );
      }
    });

    // Set position and analyze
    _sendCommand('position fen $fen');
    _sendCommand('go depth $depth');

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        infoSubscription.cancel();
        outputSubscription.cancel();
        _sendCommand('stop');
        _sendCommand('setoption name MultiPV value 1');
        return AnalysisResult(evaluation: 0, lines: [], depth: 0);
      },
    );
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
    _infoController.close();
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
}

/// Information parsed from engine output 'info' line
class AnalysisInfo {
  final int depth;
  final int multiPv;
  final int? evaluation;
  final int? mateIn;
  final List<String> pv;

  AnalysisInfo({
    required this.depth,
    required this.multiPv,
    this.evaluation,
    this.mateIn,
    required this.pv,
  });

  /// Get evaluation in pawns
  double get evalInPawns => (evaluation ?? 0) / 100.0;
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
