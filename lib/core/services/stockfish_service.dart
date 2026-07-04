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
  StreamSubscription<dynamic>? _engineResponseSubscription;

  // Initialization lifecycle
  Completer<void>?
  _engineReadyCompleter; // Completed when isolate reports engine binary loaded
  bool _isEngineBinaryReady =
      false; // Set by engine_ready from isolate (binary loaded, accepts commands)

  // Phase 2: Lifecycle management
  bool _isDisposed = false;
  int _engineSessionId =
      0; // Incremented on each _startEngineIsolate to detect stale messages
  DateTime? _lastFallbackTime;
  static const Duration _fallbackRetryCooldown = Duration(seconds: 30);

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

  /// Whether the engine is initialized and ready (or in fallback mode)
  bool get isReady => _isReady || _useFallback;

  /// Whether using fallback engine
  bool get isUsingFallback => _useFallback;

  /// Set force fallback for testing
  @visibleForTesting
  set forceFallback(bool value) => _forceFallback = value;

  /// Reset the singleton's test state so the next test starts fresh.
  /// Call this in setUp() after any test that used dispose().
  @visibleForTesting
  void resetTestState() {
    _isDisposed = false;
    _useFallback = false;
    _isReady = false;
    _isEngineBinaryReady = false;
    _isEngineBusy = false;
    _forceFallback = false;
    _lastFallbackTime = null;
    _engineSessionId = 0;
    _engineIsolate = null;
    _engineCommandPort = null;
    _engineResponsePort = null;
    _engineResponseSubscription = null;
    _commandQueue.clear();
    _initCompleter?.complete();
    _initCompleter = null;
    _engineReadyCompleter?.complete();
    _engineReadyCompleter = null;
    statusNotifier.value = EngineStatus.initializing;
  }

  /// Initialize the Stockfish engine via proper UCI protocol handshake.
  ///
  /// Handshake sequence:
  ///   1. Start engine isolate, wait for engine binary to load
  ///   2. Send "uci", wait for "uciok"
  ///   3. Apply engine options (Threads, Hash, UCI_LimitStrength)
  ///   4. Send "isready", wait for "readyok"
  ///   5. Mark engine as fully initialized
  ///
  /// Initialization commands bypass the normal command queue to avoid circular
  /// dependency: the queue requires _isReady which is not set until step 5.
  Future<void> initialize() async {
    if (_isDisposed) {
      _isDisposed = false;
      statusNotifier.value = EngineStatus.initializing;
    }
    if (_isReady || _useFallback) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    statusNotifier.value = EngineStatus.initializing;
    debugPrint('ENGINE LIFECYCLE → Starting Stockfish initialization');

    // --- Step 0: Verify binary is not force-disabled ---
    if (_forceFallback) {
      _enableFallback('Binary verification failed (forceFallback)');
      return;
    }

    // --- Step 1: Start the engine isolate ---
    try {
      await _startEngineIsolate();
    } catch (e) {
      debugPrint('ENGINE INIT: Isolate start failed: $e');
      _enableFallback('Isolate start failed: $e');
      return;
    }

    // Retry loop for the UCI handshake (isolate is alive after step 1)
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount < maxRetries) {
      try {
        // --- Step 2: Send "init" to the isolate, wait for engine binary to load ---
        _engineReadyCompleter = Completer<void>();
        _engineCommandPort?.send({'type': 'init'});
        debugPrint(
          'ENGINE INIT: Sent init, waiting for engine binary (attempt ${retryCount + 1})',
        );

        await _engineReadyCompleter!.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            _engineReadyCompleter = null;
            throw Exception('Engine binary load timeout');
          },
        );
        debugPrint('ENGINE INIT: Engine binary loaded');

        // --- Step 3: Send "uci", wait for "uciok" ---
        debugPrint('ENGINE INIT: Sending "uci"');
        final uciok = await _sendDirectAndWait(
          command: 'uci',
          pattern: 'uciok',
          timeout: const Duration(seconds: 5),
        );
        if (!uciok) {
          throw Exception('UCI handshake timeout (no uciok received)');
        }
        debugPrint('ENGINE INIT: Received uciok');

        // --- Step 4: Send engine options ---
        debugPrint('ENGINE INIT: Applying engine options');
        _sendCommandDirect('setoption name Threads value 2');
        _sendCommandDirect('setoption name Hash value 64');
        _sendCommandDirect('setoption name UCI_LimitStrength value true');

        // --- Step 5: Send "isready", wait for "readyok" ---
        debugPrint('ENGINE INIT: Sending "isready"');
        final ready = await _sendDirectAndWait(
          command: 'isready',
          pattern: 'readyok',
          timeout: const Duration(seconds: 5),
        );
        if (!ready) {
          throw Exception('Engine ready timeout (no readyok received)');
        }
        // _isReady is also set by the permanent stdout listener in _startEngineIsolate

        debugPrint('ENGINE INIT: Engine fully initialized');
        _initCompleter?.complete();
        return;
      } catch (e) {
        retryCount++;
        debugPrint('ENGINE INIT: Attempt $retryCount failed: $e');
        if (retryCount >= maxRetries) {
          _enableFallback(
            'Initialization failed after $maxRetries attempts: $e',
          );
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
        // Reset engine state for retry while keeping the isolate alive
        _isReady = false;
        _isEngineBinaryReady = false;
      }
    }
  }

  void _enableFallback(String reason) {
    _lastFallbackTime = DateTime.now();
    _useFallback = true;
    _isReady = false;
    _isEngineBinaryReady = false;
    _isEngineBusy = false;
    _engineReadyCompleter?.complete();
    _engineReadyCompleter = null;
    statusNotifier.value = EngineStatus.usingFallback;
    _initCompleter?.complete();
    _initCompleter = null;
    debugPrint('ENGINE LIFECYCLE → Fallback enabled: $reason');
  }

  /// Returns true if enough time has passed since the last fallback to attempt a retry.
  bool _shouldRetryInit() {
    if (!_useFallback || _lastFallbackTime == null) return false;
    return DateTime.now().difference(_lastFallbackTime!) >=
        _fallbackRetryCooldown;
  }

  /// Reset the fallback state and attempt re-initialization.
  /// Call this to recover from transient engine failures.
  Future<bool> resetFallback() async {
    if (!_useFallback) return true;
    if (_isDisposed) return false;

    _useFallback = false;
    _lastFallbackTime = null;
    _isEngineBusy = false;
    _isReady = false;
    _isEngineBinaryReady = false;
    _initCompleter = null;

    try {
      await _killEngineIfRunning();
      await initialize();
      if (_isReady && !_useFallback) {
        debugPrint('ENGINE LIFECYCLE → Fallback recovery successful');
        return true;
      }
    } catch (e) {
      debugPrint('ENGINE LIFECYCLE → Fallback recovery failed: $e');
    }

    // Recovery failed — remain in fallback
    if (!_useFallback) {
      _enableFallback('resetFallback recovery failed');
    }
    return false;
  }

  /// Attempt periodic retry from fallback state.
  /// Call this before getBestMove/analyzePosition when useFallback is true.
  Future<void> _tryFallbackRecovery() async {
    if (_isDisposed) return;
    if (!_useFallback) return;
    if (!_shouldRetryInit()) return;

    debugPrint(
      'ENGINE LIFECYCLE → Attempting fallback recovery (cooldown elapsed)',
    );
    // Reset state for re-init
    _useFallback = false;
    _isReady = false;
    _isEngineBinaryReady = false;
    _lastFallbackTime = null;
    _initCompleter = null;

    try {
      await initialize();
      if (_isReady && !_useFallback) {
        debugPrint('ENGINE LIFECYCLE → Fallback recovery successful');
      }
    } catch (e) {
      debugPrint('ENGINE LIFECYCLE → Fallback recovery failed: $e');
      if (!_useFallback) {
        _enableFallback('Retry recovery failed: $e');
      }
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
    if (_isDisposed || _useFallback) return;

    final completer = Completer<void>();
    _commandQueue.add(_QueuedCommand(command: command, completer: completer));
    _processCommandQueue();
  }

  /// Process commands serially to prevent concurrent engine access
  bool _isProcessingQueue = false;

  void _processCommandQueue() async {
    if (_isProcessingQueue || _isDisposed) return;
    if (_engineCommandPort == null) return;
    if (!_isReady) return; // Don't send until engine is fully initialized

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

  /// Send a command directly to the engine isolate, bypassing the command queue.
  /// Used ONLY during initialization to avoid the queue deadlock (the queue
  /// requires _isReady which is not set until after UCI handshake completes).
  void _sendCommandDirect(String command) {
    if (_isDisposed || _useFallback) return;
    debugPrint('ENGINE INIT: $command');
    _engineCommandPort?.send({'type': 'stdin', 'command': '$command\n'});
  }

  /// Wait for a specific pattern to appear in the engine's output stream.
  /// Returns true if the pattern was found within the timeout, false otherwise.
  Future<bool> _waitForOutputPattern(
    String pattern, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<bool>();
    StreamSubscription<String>? sub;
    sub = _outputController.stream.listen((line) {
      if (line.contains(pattern)) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(true);
      }
    });
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          sub?.cancel();
          debugPrint(
            'ENGINE INIT: Timeout waiting for "$pattern" after $timeout',
          );
          return false;
        },
      );
    } catch (e) {
      sub?.cancel();
      return false;
    }
  }

  /// Attach the output listener before sending the command so very fast UCI
  /// responses cannot be missed during initialization.
  Future<bool> _sendDirectAndWait({
    required String command,
    required String pattern,
    Duration timeout = const Duration(seconds: 5),
  }) {
    final waitFuture = _waitForOutputPattern(pattern, timeout: timeout);
    _sendCommandDirect(command);
    return waitFuture;
  }

  /// Convert a Stockfish side-to-move score to white-relative.
  /// Stockfish's "score cp" is from the side-to-move's perspective.
  /// Our convention stores all evaluations as white-relative
  /// (positive = good for white, negative = good for black).
  /// See: docs/ENGINE_REFACTOR_ROADMAP.md § Phase 6
  int _toWhiteRelative(int scoreCp, String fen) {
    final turn = fen.trim().split(RegExp(r'\s+'));
    if (turn.length >= 2 && turn[1] == 'b') {
      return -scoreCp;
    }
    return scoreCp;
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

    // Guard: If disposed, return fallback
    if (_isDisposed) {
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Guard: If engine is busy, return fallback immediately
    if (_isEngineBusy) {
      debugPrint('Engine is busy, using fallback for FEN: $fen');
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Attempt fallback recovery if cooldown has elapsed
    if (_useFallback && _shouldRetryInit()) {
      await _tryFallbackRecovery();
    }

    // Guard: If engine not ready, try to initialize
    if (!_isReady && !_useFallback) {
      await initialize();
    }

    // If using fallback (SimpleBot)
    if (_useFallback) {
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Guard: Double-check engine is ready after initialization
    if (!_isReady) {
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

      // Parse evaluation from info line.
      // Stockfish's "score cp" is from the side-to-move's perspective.
      // Convert to white-relative for consistent storage.
      if (trimmedLine.startsWith('info') && trimmedLine.contains('score')) {
        final scoreMatch = _scoreCpRegex.firstMatch(trimmedLine);
        if (scoreMatch != null) {
          evaluation = _toWhiteRelative(int.parse(scoreMatch.group(1)!), fen);
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

    // Position must be set before search.
    // Strength options (UCI_Elo / UCI_LimitStrength) are configured via setSkillLevel()
    // before calling getBestMove() and should NOT be set here on every move.
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
      // UCI search command strategy:
      //   Bot play  → "go movetime <ms>" — time-bounded search (no depth limit)
      //   Analysis  → "go depth <depth>" — depth-bounded search (no time limit)
      //
      // Never combine depth and movetime in one "go" command (ISSUE-006).
      // Stockfish's internal time management works best when given a single
      // constraint. Combining them is redundant and can cause confusing behavior.
      if (thinkTimeMs != null) {
        _sendCommand('go movetime $thinkTimeMs');
      } else {
        _sendCommand('go depth $depth');
      }

      // 30-second timeout for Stockfish response (failsafe)
      return completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          debugPrint(
            'ENGINE RECOVERY → Search timeout for FEN: $fen, using fallback for this move',
          );
          _sendCommand('stop');
          // Don't kill isolate or enable permanent fallback — engine may recover
          _isEngineBusy = false;
          return _getSimpleBotMove(fen, depth, thinkTimeMs);
        },
      );
    } finally {
      // Always mark engine as not busy when done
      _isEngineBusy = false;
    }
  }

  /// Map the requested depth to a safe fallback depth based on difficulty.
  /// Fallback (SimpleBot) uses pure-Dart negamax with Phase 10 improvements.
  /// 10 difficulty levels → 4 distinct fallback tiers:
  ///   depth 1     → 1  (Beginner)
  ///   depth 2-3   → 2  (Novice)
  ///   depth 4-8   → 3  (Casual, Intermediate)
  ///   depth 9+    → 4  (Club Player and above)
  static int _fallbackDepth(int requestedDepth) {
    if (requestedDepth <= 1) return 1;
    if (requestedDepth <= 3) return 2;
    if (requestedDepth <= 8) return 3;
    return 4;
  }

  Future<BestMoveResult> _getSimpleBotMove(
    String fen,
    int depth,
    int? thinkTimeMs,
  ) async {
    final safeDepth = _fallbackDepth(depth);
    debugPrint(
      'FALLBACK: depth=$depth → safeDepth=$safeDepth, thinkTimeMs=$thinkTimeMs',
    );

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

    // Guard: If disposed, return fallback
    if (_isDisposed) {
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Guard: If engine is busy, return fallback immediately
    if (_isEngineBusy) {
      debugPrint('Engine is busy, using fallback for analysis FEN: $fen');
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Attempt fallback recovery if cooldown has elapsed
    if (_useFallback && _shouldRetryInit()) {
      await _tryFallbackRecovery();
    }

    if (!_isReady && !_useFallback) {
      await initialize();
    }

    // If using fallback, use basic evaluator
    if (_useFallback) {
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
            eval = _toWhiteRelative(int.parse(scoreMatch.group(1)!), fen);
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
          debugPrint(
            'ENGINE RECOVERY → Analysis timeout for FEN: $fen, using fallback',
          );
          _sendCommand('stop');
          _sendCommand('setoption name MultiPV value 1');
          // Don't kill isolate or enable permanent fallback — engine may recover
          _isEngineBusy = false;
          return BasicEvaluatorService.instance.analyze(fen);
        },
      );
    } finally {
      // Always mark engine as not busy when done
      _isEngineBusy = false;
    }
  }

  /// Set the engine skill level (affects playing strength).
  /// Uses Stockfish's UCI_Elo with UCI_LimitStrength=true for strength control.
  /// Do NOT set Skill Level simultaneously — Stockfish ignores it when UCI_LimitStrength is active.
  void setSkillLevel(int elo) {
    if (_isDisposed || _useFallback) return;

    final clampedElo = elo.clamp(1320, 3190);
    _sendCommand('setoption name UCI_LimitStrength value true');
    _sendCommand('setoption name UCI_Elo value $clampedElo');
    debugPrint('ENGINE CONFIG: UCI_Elo=$clampedElo (requested=$elo)');
  }

  /// Set the engine to maximum strength
  void setMaxStrength() {
    if (_isDisposed || _useFallback) return;
    _sendCommand('setoption name UCI_LimitStrength value false');
  }

  /// Stop any ongoing analysis
  void stopAnalysis() {
    if (_isDisposed || _useFallback) return;
    _sendCommand('stop');
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
    if (_isDisposed || _useFallback) return;
    _sendCommand('ucinewgame');
  }

  /// Dispose the engine, killing the isolate and freeing resources.
  /// The service can be re-initialized later via initialize().
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('ENGINE LIFECYCLE → Disposing engine');

    await _killEngineIfRunning();
    _commandQueue.clear();

    // Cancel any pending completers to unblock waiters
    _initCompleter?.complete();
    _initCompleter = null;
    _engineReadyCompleter?.complete();
    _engineReadyCompleter = null;

    statusNotifier.value = EngineStatus.disposed;
    // Do NOT close _outputController — it's a singleton stream that lives
    // for the app lifetime. Closing it would permanently break the service.
  }

  Future<void> _startEngineIsolate() async {
    if (_isDisposed) throw Exception('Cannot start engine after dispose');
    if (_engineIsolate != null) return;

    _engineSessionId++;
    final sessionId = _engineSessionId;

    _engineResponsePort = ReceivePort();
    _engineIsolate = await Isolate.spawn(
      _stockfishIsolateEntryPoint,
      _engineResponsePort!.sendPort,
    );

    // Listen for the command port and stdout from the isolate
    final completer = Completer<void>();
    _engineResponseSubscription = _engineResponsePort!.listen((message) {
      // Ignore stale messages from previous sessions
      if (_engineSessionId != sessionId) return;

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
              statusNotifier.value = EngineStatus.ready;
              // Process any queued commands now that engine is fully initialized
              _processCommandQueue();
            }
          }
        } else if (type == 'engine_ready') {
          // Engine isolate reports the binary loaded and is accepting commands
          _isEngineBinaryReady = true;
          _engineReadyCompleter?.complete();
          _engineReadyCompleter = null;
        } else if (type == 'error') {
          // Error reported from the engine isolate
          final msg = message['message'] as String? ?? 'Unknown error';
          debugPrint('ENGINE INIT: Isolate error: $msg');
        }
      }
    });

    // Timeout for isolate spawn (SendPort must arrive within 10 seconds)
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('Isolate spawn timeout (SendPort not received)');
    }
  }

  void _stopEngineIsolate() {
    _killEngineGracefully();
  }

  /// Kill the engine isolate if it exists. Does NOT enable fallback or dispose.
  /// Safe to call multiple times. Idempotent.
  Future<void> _killEngineIfRunning() async {
    if (_engineIsolate == null && _engineCommandPort == null) return;
    debugPrint('ENGINE LIFECYCLE → Killing engine isolate');

    // Cancel response port subscription first
    await _engineResponseSubscription?.cancel();
    _engineResponseSubscription = null;

    try {
      _engineCommandPort?.send({'type': 'stdin', 'command': 'stop\n'});
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {}
    try {
      _engineIsolate?.kill(priority: Isolate.beforeNextEvent);
    } catch (_) {}
    _engineIsolate = null;
    _engineCommandPort = null;
    _engineResponsePort?.close();
    _engineResponsePort = null;
    _isReady = false;
    _isEngineBinaryReady = false;
    _isEngineBusy = false;

    // Cancel any pending init
    _engineReadyCompleter?.complete();
    _engineReadyCompleter = null;
  }

  /// Gracefully kill the engine and enable fallback.
  /// Use this when the engine has encountered a terminal error.
  Future<void> _killEngineGracefully() async {
    await _killEngineIfRunning();
    _commandQueue.clear();
    _isDisposed = false; // Don't set disposed — allow re-init
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
            // Signal to the main thread that the engine binary loaded successfully.
            // The main thread awaits this before starting the UCI handshake.
            sendPort.send({'type': 'engine_ready'});
          } catch (e) {
            sendPort.send({
              'type': 'error',
              'message': 'Stockfish() constructor failed: $e',
            });
          }
          break;
        case 'stdin':
          final command = message['command'] as String;
          try {
            stockfish?.stdin = command;
          } catch (e) {
            sendPort.send({
              'type': 'error',
              'message': 'stdin command failed: $e (command: $command)',
            });
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
