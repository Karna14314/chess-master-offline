import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';
import 'package:chess_master/core/services/basic_evaluator_service.dart';

/// Service class for interacting with the Stockfish chess engine
/// Uses UCI (Universal Chess Interface) protocol
class StockfishService {
  static StockfishService? _instance;
  Stockfish? _stockfish;
  bool _isReady = false;
  bool _useFallback = false;

  // Flag to simulate binary check failure for testing or if on unsupported platform
  bool _forceFallback = false;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final ValueNotifier<EngineStatus> statusNotifier = ValueNotifier(
    EngineStatus.initializing,
  );

  Completer<void>? _initCompleter;

  // RegExps for parsing engine output
  static final RegExp _scoreCpRegex = RegExp(r'score cp (-?\d+)');
  static final RegExp _scoreMateRegex = RegExp(r'score mate (-?\d+)');
  static final RegExp _multiPvRegex = RegExp(r'multipv (\d+)');
  static final RegExp _depthRegex = RegExp(r'depth (\d+)');
  static final RegExp _pvMovesRegex = RegExp(r'pv (.+)$');

  /// Singleton instance
  static StockfishService get instance {
    _instance ??= StockfishService._();
    return _instance!;
  }

  StockfishService._();

  /// Stream of engine output
  Stream<String> get outputStream => _outputController.stream;

  /// Whether the engine is initialized and ready
  bool get isReady => _isReady || _useFallback;

  /// Whether using fallback engine
  bool get isUsingFallback => _useFallback;

  /// Set force fallback for testing
  @visibleForTesting
  set forceFallback(bool value) => _forceFallback = value;

  /// Initialize the Stockfish engine
  Future<void> initialize() async {
    if (_isReady || _useFallback) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    statusNotifier.value = EngineStatus.initializing;

    // 1. Verify binary exists (Mock check as plugin handles it)
    bool binaryExists = true;
    try {
      // In a real scenario, we might check file existence if we bundled it manually.
      // Since we use a plugin, we assume it exists unless init fails.
      if (_forceFallback) binaryExists = false;
    } catch (e) {
      binaryExists = false;
    }

    if (!binaryExists) {
      _enableFallback('Binary verification failed');
      return;
    }

    // 2. Try to init Stockfish
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount < maxRetries) {
      try {
        _stockfish?.dispose();
        debugPrint('Stockfish instance created');
        _stockfish = Stockfish();

        // Wait for the Stockfish instance to be ready before sending commands
        // The package needs time to initialize the native binary
        int initAttempts = 0;
        while (initAttempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          // Try to check if we can send commands by attempting to access stdin
          try {
            // If this doesn't throw, the engine is ready
            if (_stockfish != null) {
              break;
            }
          } catch (e) {
            // Engine not ready yet
          }
          initAttempts++;
        }

        debugPrint('Stockfish initialization wait complete');

        bool uciOkReceived = false;

        // Listen to engine output
        final sub = _stockfish!.stdout.listen((line) {
          if (line.trim().isNotEmpty) {
            _outputController.add(line);
            if (line.contains('uciok')) {
              uciOkReceived = true;
            }
            if (line.contains('readyok')) {
              _isReady = true;
              statusNotifier.value = EngineStatus.ready;
            }
          }
        });

        // Give a bit more time for the stream to be set up
        await Future.delayed(const Duration(milliseconds: 200));

        // Initialize UCI mode
        debugPrint('Sending UCI command');
        _sendCommand('uci');

        // Wait for uciok
        int attempts = 0;
        while (!uciOkReceived && attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (!uciOkReceived) {
          throw Exception('Stockfish failed to respond with uciok');
        }

        // Wait for engine to be ready with timeout
        await _waitForReady();

        // Configure engine for mobile performance
        _configureEngine();

        _initCompleter?.complete();
        return;
      } catch (e) {
        retryCount++;
        debugPrint(
          'Stockfish engine initialization failed (attempt $retryCount): $e',
        );

        // Dispose only the engine instance, keep the controller open
        _stockfish?.dispose();
        _stockfish = null;
        _isReady = false;

        if (retryCount >= maxRetries) {
          _enableFallback('Initialization failed after retries: $e');
          return;
        }

        // Small delay before retry
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  void _enableFallback(String reason) {
    debugPrint('Switching to fallback engine: $reason');
    _useFallback = true;
    _isReady = false;
    statusNotifier.value = EngineStatus.usingFallback;
    _initCompleter?.complete();
    _initCompleter = null;
  }

  /// Configure engine options for optimal mobile performance
  void _configureEngine() {
    _sendCommand('setoption name Threads value 2');
    _sendCommand('setoption name Hash value 64');
    _sendCommand('setoption name UCI_LimitStrength value true');
  }

  /// Wait for engine to be ready
  Future<void> _waitForReady() async {
    _isReady = false; // Reset ready state
    _sendCommand('isready');

    int attempts = 0;
    // Timeout after 3 seconds (30 * 100ms)
    while (!_isReady && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!_isReady) {
      throw Exception('Stockfish failed to initialize (isready timeout)');
    }
  }

  /// Send a command to the engine
  void _sendCommand(String command) {
    if (_stockfish != null && !_useFallback) {
      _stockfish?.stdin = '$command\n';
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
    if (!_isReady && !_useFallback) {
      await initialize();
    }

    // If using fallback (SimpleBot)
    if (_useFallback) {
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    final completer = Completer<BestMoveResult>();
    String? bestMove;
    String? ponderMove;
    int? evaluation;
    int? mateIn;

    late StreamSubscription subscription;
    subscription = _outputController.stream.listen((line) {
      final trimmedLine = line.trim();

      // Parse evaluation from info line
      if (trimmedLine.startsWith('info') && trimmedLine.contains('score')) {
        final scoreMatch = _scoreCpRegex.firstMatch(trimmedLine);
        if (scoreMatch != null) {
          evaluation = int.parse(scoreMatch.group(1)!);
        }

        final mateMatch = _scoreMateRegex.firstMatch(trimmedLine);
        if (mateMatch != null) {
          mateIn = int.parse(mateMatch.group(1)!);
        }
      }

      // Parse best move
      if (trimmedLine.startsWith('bestmove')) {
        final parts = trimmedLine.split(' ');
        if (parts.length >= 2) {
          bestMove = parts[1];
        }
        if (parts.length >= 4 && parts[2] == 'ponder') {
          ponderMove = parts[3];
        }

        subscription.cancel();
        completer.complete(
          BestMoveResult(
            bestMove: bestMove ?? '',
            ponderMove: ponderMove,
            evaluation: evaluation,
            mateIn: mateIn,
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

    // 5-second timeout for Stockfish response
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription.cancel();
        _sendCommand('stop');

        // Reset engine state on timeout so it re-initializes next time
        // But mark as fallback now
        _stockfish?.dispose();
        _stockfish = null;
        _enableFallback('Engine timeout');

        // Fallback immediate
        return _getSimpleBotMove(fen, depth, thinkTimeMs);
      },
    );
  }

  Future<BestMoveResult> _getSimpleBotMove(
    String fen,
    int depth,
    int? thinkTimeMs,
  ) async {
    // Small artificial delay to simulate thinking if needed
    if (thinkTimeMs != null && thinkTimeMs > 500) {
      final delay = thinkTimeMs ~/ 2;
      await Future.delayed(Duration(milliseconds: delay));
    }

    final result = await SimpleBotService.instance.getBestMove(
      fen: fen,
      depth: depth,
    );
    return BestMoveResult(
      bestMove: result.bestMove,
      evaluation: result.evaluation,
    );
  }

  /// Analyze a position and get multiple lines
  /// Returns evaluation and top engine lines
  Future<AnalysisResult> analyzePosition({
    required String fen,
    int depth = AppConstants.analysisDepth,
    int multiPv = AppConstants.topEngineLinesCount,
  }) async {
    if (!_isReady && !_useFallback) {
      await initialize();
    }

    // Fallback doesn't support full analysis yet
    // Throw error to let AnalysisProvider handle it with BasicEvaluator
    if (_useFallback) {
      // Use BasicEvaluatorService instead of throwing raw exception for smoother UX
      return BasicEvaluatorService.instance.analyze(fen);
    }

    final completer = Completer<AnalysisResult>();
    final lines = <EngineLine>[];
    int? mainEvaluation;
    int? mateIn;

    // Set MultiPV for multiple lines
    _sendCommand('setoption name MultiPV value $multiPv');

    late StreamSubscription subscription;
    subscription = _outputController.stream.listen((line) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('info') && trimmedLine.contains('pv')) {
        final pvMatch = _multiPvRegex.firstMatch(trimmedLine);
        final depthMatch = _depthRegex.firstMatch(trimmedLine);
        final scoreMatch = _scoreCpRegex.firstMatch(trimmedLine);
        final mateMatch = _scoreMateRegex.firstMatch(trimmedLine);
        final pvMovesMatch = _pvMovesRegex.firstMatch(trimmedLine);

        if (pvMovesMatch != null) {
          final pvNumber = pvMatch != null ? int.parse(pvMatch.group(1)!) : 1;
          final currentDepth =
              depthMatch != null ? int.parse(depthMatch.group(1)!) : 0;
          int? eval;
          int? mate;

          if (scoreMatch != null) {
            eval = int.parse(scoreMatch.group(1)!);
          }
          if (mateMatch != null) {
            mate = int.parse(mateMatch.group(1)!);
          }

          final moves = pvMovesMatch.group(1)!.split(' ');

          // Store the main line evaluation
          if (pvNumber == 1) {
            mainEvaluation = eval;
            mateIn = mate;
          }

          final engineLine = EngineLine(
            rank: pvNumber,
            evaluation: (eval ?? 0) / 100.0,
            depth: currentDepth,
            moves: moves,
            isMate: mate != null,
            mateIn: mate,
          );

          // Update or add line
          if (lines.length >= pvNumber) {
            lines[pvNumber - 1] = engineLine;
          } else {
            lines.add(engineLine);
          }
        }
      }

      if (trimmedLine.startsWith('bestmove')) {
        subscription.cancel();
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
      const Duration(
        seconds: 10,
      ), // Short timeout for analysis to switch to basic if stuck
      onTimeout: () {
        subscription.cancel();
        _sendCommand('stop');
        _sendCommand('setoption name MultiPV value 1');

        // Reset engine state on timeout
        _stockfish?.dispose();
        _stockfish = null;
        _enableFallback('Analysis timeout');

        return BasicEvaluatorService.instance.analyze(fen);
      },
    );
  }

  /// Set the engine skill level (affects playing strength)
  void setSkillLevel(int elo) {
    if (_useFallback) return;
    _sendCommand('setoption name UCI_Elo value $elo');
  }

  /// Stop any ongoing analysis
  void stopAnalysis() {
    if (!_useFallback) {
      _sendCommand('stop');
    }
  }

  /// Start a new game
  void newGame() {
    if (!_useFallback) {
      _sendCommand('ucinewgame');
    }
  }

  /// Dispose the engine
  void dispose() {
    _stockfish?.dispose();
    _stockfish = null;
    _isReady = false;
    _useFallback = false;
    statusNotifier.value = EngineStatus.disposed;
    _outputController.close();
  }
}
