import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';
import 'package:chess_master/core/services/basic_evaluator_service.dart';

/// Queued command for serial execution
class _QueuedCommand {
  final String command;
  final Completer<void>? completer;

  _QueuedCommand({required this.command, this.completer});
}

/// Service class for interacting with the Stockfish chess engine
/// Uses UCI (Universal Chess Interface) protocol
class StockfishService {
  static StockfishService? _instance;
  Stockfish? _stockfish;
  bool _isReady = false;
  bool _isEngineReady = false; // Set only after "readyok" received
  bool _isEngineBusy = false; // True when search is in progress
  final List<_QueuedCommand> _commandQueue = [];
  bool _useFallback = false;

  // Flag to simulate binary check failure for testing or if on unsupported platform
  bool _forceFallback = false;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final ValueNotifier<EngineStatus> statusNotifier = ValueNotifier(
    EngineStatus.initializing,
  );

  Completer<void>? _initCompleter;
  Isolate? _engineIsolate;
  SendPort? _engineCommandPort;
  ReceivePort? _engineResponsePort;

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

    try {
      await _startEngineIsolate();
    } catch (e) {
      debugPrint('Failed to start engine isolate: $e');
      _enableFallback('Isolate start failed');
      return;
    }

    // 2. Try to init Stockfish
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount < maxRetries) {
      try {
        _engineCommandPort?.send({'type': 'init'});
        _isReady = false;

        // Give a bit of time for isolate to start the engine
        await Future.delayed(const Duration(milliseconds: 500));

        // Initialize UCI mode
        debugPrint('Sending UCI command');
        _sendCommand('uci');
        _sendCommand('isready');

        // Wait for readiness via the stream (which is already being fed by isolate)
        int attempts = 0;
        while (!_isReady && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (statusNotifier.value == EngineStatus.ready) break;
          attempts++;
        }

        if (!_isReady) {
          throw Exception('Stockfish failed to reach ready state (timeout)');
        }

        // Configure engine for mobile performance
        _configureEngine();

        _initCompleter?.complete();
        return;
      } catch (e) {
        retryCount++;
        debugPrint(
          'Stockfish engine initialization failed (attempt $retryCount): $e',
        );

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
    _isEngineReady = false; // Reset engine ready flag
    _isEngineBusy = false; // Reset busy flag
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

  /// Wait for readyok response after sending position or other commands.
  /// This ensures Stockfish has fully processed the position before we start search.
  /// Returns true if readyok received, false on timeout.
  Future<bool> _waitForReadyOk({Duration? timeout}) async {
    final effectiveTimeout = timeout ?? const Duration(milliseconds: 500);
    final stopwatch = Stopwatch()..start();

    final completer = Completer<bool>();
    StreamSubscription? subscription;

    subscription = _outputController.stream.listen((line) {
      if (line.contains('readyok')) {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    // Send isready command
    _sendCommand('isready');

    try {
      // Wait for readyok or timeout
      final result = await completer.future.timeout(
        effectiveTimeout,
        onTimeout: () {
          subscription?.cancel();
          return false;
        },
      );

      stopwatch.stop();
      return result;
    } catch (e) {
      subscription?.cancel();
      return false;
    }
  }

  /// Send a command to the engine (queued for serial execution)
  void _sendCommand(String command) {
    if (_useFallback) return;

    final completer = Completer<void>();
    _commandQueue.add(_QueuedCommand(command: command, completer: completer));
    _processCommandQueue();
  }

  /// Process commands serially to prevent concurrent engine access
  bool _isProcessingQueue = false;

  void _processCommandQueue() async {
    if (_isProcessingQueue) return;
    if (_engineCommandPort == null) return;
    if (!_isEngineReady) return; // Don't send until engine is ready

    _isProcessingQueue = true;

    while (_commandQueue.isNotEmpty) {
      final cmd = _commandQueue.removeAt(0);
      try {
        _engineCommandPort?.send({
          'type': 'stdin',
          'command': '${cmd.command}\n',
        });
        cmd.completer?.complete();
        // Small delay between commands to prevent overwhelming the engine
        await Future.delayed(const Duration(milliseconds: 10));
      } catch (e) {
        cmd.completer?.completeError(e);
      }
    }

    _isProcessingQueue = false;
  }

  /// Internal FEN validation to prevent engine crashes
  bool _isValidFen(String fen) {
    if (fen.isEmpty) return false;
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) return false; // At least board, color, castling, ep

    // Basic regex for the board part
    final boardPart = parts[0];
    final rows = boardPart.split('/');
    if (rows.length != 8) return false;

    for (final row in rows) {
      int count = 0;
      for (int i = 0; i < row.length; i++) {
        final char = row[i];
        if (RegExp(r'[1-8]').hasMatch(char)) {
          count += int.parse(char);
        } else if (RegExp(r'[prnbqkPRNBQK]').hasMatch(char)) {
          count += 1;
        } else {
          return false; // Invalid character
        }
      }
      if (count != 8) return false;
    }

    // Color check
    final color = parts[1];
    if (color != 'w' && color != 'b') return false;

    return true;
  }

  /// Get the best move for a given position
  /// [fen] - Position in FEN notation
  /// [depth] - Search depth (1-22)
  /// [thinkTimeMs] - Optional think time limit in milliseconds
  Future<BestMoveResult> getBestMove({
    required String fen,
    required int depth,
    int? elo,
    int? thinkTimeMs,
  }) async {
    // Validate FEN to prevent SIGSEGV in Stockfish::Position::is_draw
    if (!_isValidFen(fen)) {
      debugPrint('Invalid FEN detected: $fen. Using fallback.');
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Guard: If engine is busy, return fallback immediately
    if (_isEngineBusy) {
      debugPrint('Engine is busy, using fallback for FEN: $fen');
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Guard: If engine not ready, try to initialize or use fallback
    if (!_isReady && !_useFallback) {
      await initialize();
    }

    // If using fallback (SimpleBot)
    if (_useFallback) {
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Guard: Double-check engine is ready after initialization
    if (!_isEngineReady || !_isReady) {
      debugPrint('Engine not ready after init, using fallback for FEN: $fen');
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Setup search listener BEFORE setting position (must be ready before go)
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

    // Set position and options
    if (elo != null) {
      _sendCommand('setoption name UCI_LimitStrength value true');
      _sendCommand('setoption name UCI_Elo value $elo');
    } else {
      _sendCommand('setoption name UCI_LimitStrength value false');
    }

    _sendCommand('position fen $fen');

    // Wait for engine to confirm position is processed before starting search
    // This prevents SIGSEGV in Stockfish::Position::is_draw by ensuring position is valid
    final positionReady = await _waitForReadyOk(
      timeout: const Duration(milliseconds: 500),
    );
    if (!positionReady) {
      subscription.cancel();
      debugPrint('Position ready timeout for FEN: $fen. Using fallback.');
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Mark engine as busy ONLY after readyok confirmed
    _isEngineBusy = true;

    try {
      // Start search
      if (thinkTimeMs != null) {
        _sendCommand('go depth $depth movetime $thinkTimeMs');
      } else {
        _sendCommand('go depth $depth');
      }

      // 30-second timeout for Stockfish response (failsafe)
      return completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          _sendCommand('stop');

          // Reset engine state on timeout so it re-initializes next time
          // But mark as fallback now
          _stopEngineIsolate();
          _enableFallback('Engine timeout');

          // Fallback immediate
          return _getSimpleBotMove(fen, depth, thinkTimeMs);
        },
      );
    } finally {
      // Always mark engine as not busy when done
      _isEngineBusy = false;
    }
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

    // Cap depth to prevent ANR when fallback is used
    final safeDepth = depth > 4 ? 4 : depth;

    final result = await SimpleBotService.instance.getBestMove(
      fen: fen,
      depth: safeDepth,
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
    void Function(AnalysisResult)? onUpdate,
  }) async {
    // Validate FEN to prevent SIGSEGV
    if (!_isValidFen(fen)) {
      debugPrint('Invalid FEN detected for analysis: $fen');
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Guard: If engine is busy, return fallback immediately
    if (_isEngineBusy) {
      debugPrint('Engine is busy, using fallback for analysis FEN: $fen');
      return BasicEvaluatorService.instance.analyze(fen);
    }

    if (!_isReady && !_useFallback) {
      await initialize();
    }

    // Guard: Check engine is ready after init
    if (!_isEngineReady || !_isReady) {
      debugPrint('Engine not ready for analysis, using fallback for FEN: $fen');
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Setup analysis listener BEFORE any commands
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

          if (onUpdate != null && mainEvaluation != null) {
            onUpdate(
              AnalysisResult(
                evaluation: mainEvaluation!,
                mateIn: mateIn,
                lines: List.from(lines),
                depth: currentDepth,
              ),
            );
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

    // Stop any ongoing search before setting new position (intentional replacement)
    // This must be called BEFORE _isEngineBusy is set to true
    await _stopCurrentSearchAndWait();

    // Ensure engine is at max strength for analysis (after stop, before position)
    if (!_useFallback) {
      setMaxStrength();
    }

    // Set position and analyze
    _sendCommand('position fen $fen');

    // Wait for engine to confirm position is processed before starting search
    final positionReady = await _waitForReadyOk(
      timeout: const Duration(milliseconds: 500),
    );
    if (!positionReady) {
      subscription.cancel();
      debugPrint(
        'Position ready timeout for analysis FEN: $fen. Using fallback.',
      );
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Mark engine as busy ONLY after readyok confirmed
    // (re-set to true because _stopCurrentSearch() cleared it)
    _isEngineBusy = true;

    try {
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
          _stopEngineIsolate();
          _enableFallback('Analysis timeout');

          return BasicEvaluatorService.instance.analyze(fen);
        },
      );
    } finally {
      // Always mark engine as not busy when done
      _isEngineBusy = false;
    }
  }

  /// Set the engine skill level (affects playing strength)
  void setSkillLevel(int elo) {
    if (_useFallback) return;

    // Map Elo to Skill Level (0-20)
    // 800 -> 0, 1200 -> 4, 1600 -> 8, 2000 -> 12, 2400 -> 16, 2800+ -> 20
    int skillLevel = ((elo - 800) / 100).round().clamp(0, 20);

    _sendCommand('setoption name UCI_LimitStrength value true');
    _sendCommand('setoption name UCI_Elo value $elo');
    _sendCommand('setoption name Skill Level value $skillLevel');
  }

  /// Set the engine to maximum strength
  void setMaxStrength() {
    if (_useFallback) return;
    _sendCommand('setoption name UCI_LimitStrength value false');
  }

  /// Stop any ongoing analysis
  void stopAnalysis() {
    if (!_useFallback) {
      _sendCommand('stop');
    }
  }

  /// Stop current search and wait for it to finish (for intentional search replacement)
  Future<void> _stopCurrentSearchAndWait() async {
    if (_isEngineBusy) {
      final completer = Completer<void>();
      late StreamSubscription subscription;

      subscription = _outputController.stream.listen((line) {
        if (line.trim().startsWith('bestmove')) {
          subscription.cancel();
          if (!completer.isCompleted) completer.complete();
        }
      });

      _sendCommand('stop');

      try {
        await completer.future.timeout(const Duration(seconds: 2));
      } catch (_) {
        subscription.cancel();
      } finally {
        _isEngineBusy = false;
      }
    }
  }

  /// Start a new game
  void newGame() {
    if (!_useFallback) {
      _sendCommand('ucinewgame');
    }
  }

  /// Dispose the engine
  Future<void> dispose() async {
    await _killEngineGracefully();
    statusNotifier.value = EngineStatus.disposed;
    _outputController.close();
  }

  Future<void> _startEngineIsolate() async {
    if (_engineIsolate != null) return;

    _engineResponsePort = ReceivePort();
    _engineIsolate = await Isolate.spawn(
      _stockfishIsolateEntryPoint,
      _engineResponsePort!.sendPort,
    );

    // Listen for the command port and stdout from the isolate
    final completer = Completer<void>();
    _engineResponsePort!.listen((message) {
      if (message is SendPort) {
        _engineCommandPort = message;
        completer.complete();
      } else if (message is Map<String, dynamic>) {
        final type = message['type'] as String;
        if (type == 'stdout') {
          final line = message['line'] as String;
          if (line.trim().isNotEmpty) {
            _outputController.add(line);
            if (line.contains('readyok')) {
              _isReady = true;
              _isEngineReady = true; // Set engine ready flag
              statusNotifier.value = EngineStatus.ready;
              // Process any queued commands now that engine is ready
              _processCommandQueue();
            }
          }
        } else if (type == 'engine_ready') {
          // Engine isolate reports it's initialized and ready for commands
          _isEngineReady = true;
        }
      }
    });

    return completer.future;
  }

  void _stopEngineIsolate() {
    _killEngineGracefully();
  }

  Future<void> _killEngineGracefully() async {
    try {
      _engineCommandPort?.send({'type': 'stdin', 'command': 'stop\n'});
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (_) {}
    try {
      _engineIsolate?.kill(priority: Isolate.beforeNextEvent);
      _engineIsolate = null;
    } catch (_) {}
    _engineCommandPort = null;
    _engineResponsePort?.close();
    _engineResponsePort = null;
    _isReady = false;
    _isEngineReady = false; // Reset engine ready flag
    _isEngineBusy = false; // Reset busy flag
  }
}

/// Entry point for the Stockfish engine isolate
void _stockfishIsolateEntryPoint(SendPort sendPort) {
  final commandPort = ReceivePort();
  sendPort.send(commandPort.sendPort);

  Stockfish? stockfish;

  commandPort.listen((message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'] as String;

      switch (type) {
        case 'init':
          stockfish?.dispose();
          try {
            stockfish = Stockfish();
            stockfish!.stdout.listen((line) {
              sendPort.send({'type': 'stdout', 'line': line});
            });
          } catch (e) {
            // Log error or ignore
          }
          break;
        case 'stdin':
          final command = message['command'] as String;
          try {
            stockfish?.stdin = command;
          } catch (e) {
            // Log error
          }
          break;
        case 'dispose':
          stockfish?.dispose();
          stockfish = null;
          break;
      }
    }
  });
}
