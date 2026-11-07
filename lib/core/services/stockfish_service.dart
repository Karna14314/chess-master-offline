import 'package:chess/chess.dart' as chess_lib;
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine_state.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';
import 'package:chess_master/core/services/basic_evaluator_service.dart';

/// Queued command for serial execution
class _QueuedCommand {
  final String command;

  _QueuedCommand({required this.command});
}

/// Service class for interacting with the Stockfish chess engine
/// Uses UCI (Universal Chess Interface) protocol

/// Serialized execution queue for engine operations.
/// Prevents concurrent command sequences from interleaving and causing
/// native Stockfish C++ data races or memory corruption.
class _EngineExecutionQueue {
  Future<void> _lastOperation = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lastOperation = _lastOperation
        .then((_) async {
          try {
            final result = await action();
            completer.complete(result);
          } catch (e, st) {
            completer.completeError(e, st);
          }
        })
        .catchError((_) {
          // Prevents queue stall if previous operation failed
        });
    return completer.future;
  }

  void clear() {
    _lastOperation = Future.value();
  }
}

class StockfishService {
  static final _fenSpaceRegex = RegExp(r'\s+');
  static final _fenDigitRegex = RegExp(r'[1-8]');
  static final _fenPieceRegex = RegExp(r'[prnbqkPRNBQK]');
  static StockfishService? _instance;
  bool _isReady = false;
  bool _isEngineBusy = false; // True when a search is claimed/in progress
  final List<_QueuedCommand> _commandQueue = [];
  final _EngineExecutionQueue _executionQueue = _EngineExecutionQueue();
  bool _useFallback = false;

  // Per-search identity token. A bestmove line is only accepted by the search
  // whose id matches the current value; stale lines from abandoned searches are
  // discarded. Also used to detect overlap between searches.
  int _activeSearchId = 0;

  // True only between sending "go" and receiving "bestmove" for the current
  // search. Drives _stopCurrentSearchAndWait so it never waits on a search
  // that isn't actually running.
  bool _searchInFlight = false;

  bool _isSearchCancelled(int searchId) =>
      _isDisposed || searchId != _activeSearchId;

  BestMoveResult _cancelledBestMoveResult() =>
      BestMoveResult(bestMove: '', wasCancelled: true);

  AnalysisResult _cancelledAnalysisResult() => AnalysisResult(
    evaluation: 0,
    lines: const [],
    depth: 0,
    wasCancelled: true,
  );

  @visibleForTesting
  Duration searchTimeoutForTesting = const Duration(seconds: 30);

  // Production analysis budget is adaptive (see _effectiveAnalysisTimeout).
  // Tests may pin a fixed value through analysisTimeoutForTesting; doing so
  // flips _analysisTimeoutWasSet so the adaptive path is bypassed.
  Duration _analysisTimeout = const Duration(seconds: 5);
  bool _analysisTimeoutWasSet = false;

  @visibleForTesting
  Duration get analysisTimeoutForTesting => _analysisTimeout;

  @visibleForTesting
  set analysisTimeoutForTesting(Duration value) {
    _analysisTimeout = value;
    _analysisTimeoutWasSet = true;
  }

  bool _skipReadyOkForTesting = false;

  // Counts "readyok" lines received from the engine. A waiter records the
  // count when it issues its own "isready" and only accepts a response that
  // arrived afterwards, so a stale readyok from an earlier handshake can no
  // longer release a stop/position wait early.
  int _readyokCount = 0;

  // After the native engine is torn down it must not be restarted
  // immediately. The plugin's C++ engine shares process-wide fakein/fakeout
  // stream queues (and other Stockfish globals), so a new instance that
  // starts before the old stockfish_main() loop has returned can corrupt the
  // old instance's shutdown and race on those globals. A short cooldown (and
  // a longer one when shutdown was not acknowledged) keeps engine lifetimes
  // strictly sequential.
  DateTime? _lastEngineShutdownTime;
  bool _lastEngineShutdownWasClean = true;
  static const Duration _engineRestartCooldown = Duration(milliseconds: 500);
  static const Duration _uncleanEngineRestartCooldown = Duration(seconds: 5);

  // Flag to simulate binary check failure for testing or if on unsupported platform
  bool _forceFallback = false;

  StreamController<String> _outputController =
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
  Completer<void>?
  _isolateDisposedCompleter; // Completed when isolate acknowledges dispose
  bool _isolateDisposeWasClean = false; // Native UCI loop confirmed exited

  // Phase 2: Lifecycle management
  bool _isDisposed = false;
  Future<void>? _disposeFuture;
  int _engineSessionId =
      0; // Incremented on each _startEngineIsolate to detect stale messages
  DateTime? _lastFallbackTime;
  static const Duration _fallbackRetryCooldown = Duration(seconds: 30);
  int _consecutiveCrashes = 0;
  static const int _maxConsecutiveCrashes = 2; // Circuit breaker threshold

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
    _isEngineBusy = false;
    _forceFallback = false;
    _lastFallbackTime = null;
    _engineSessionId = 0;
    _disposeFuture = null;
    _activeSearchId = 0;
    _searchInFlight = false;
    _skipReadyOkForTesting = false;
    _readyokCount = 0;
    _lastEngineShutdownTime = null;
    _lastEngineShutdownWasClean = true;
    _consecutiveCrashes = 0;
    searchTimeoutForTesting = const Duration(seconds: 30);
    _analysisTimeout = const Duration(seconds: 5);
    _analysisTimeoutWasSet = false;
    _engineIsolate = null;
    _engineCommandPort = null;
    _engineResponsePort = null;
    _engineResponseSubscription = null;
    _isolateDisposeWasClean = false;
    _commandQueue.clear();
    _executionQueue.clear();
    _outputController = StreamController<String>.broadcast();
    _initCompleter?.complete();
    _initCompleter = null;
    _engineReadyCompleter?.complete();
    _engineReadyCompleter = null;
    _isolateDisposedCompleter?.complete();
    _isolateDisposedCompleter = null;
    statusNotifier.value = EngineStatus.initializing;
  }

  /// Puts the service in a fake "ready, non-fallback" state so tests can drive
  /// the search pipeline by injecting engine output lines.
  @visibleForTesting
  void setReadyForTesting({
    bool immediateReadyOk = false,
    SendPort? commandPort,
  }) {
    _isReady = true;
    _useFallback = false;
    _forceFallback = false;
    _isEngineBusy = false;
    _searchInFlight = false;
    _skipReadyOkForTesting = immediateReadyOk;
    _readyokCount = 0;
    if (commandPort != null) _engineCommandPort = commandPort;
    statusNotifier.value = EngineStatus.ready;
  }

  /// Injects a raw engine output line as if it came from the engine isolate.
  @visibleForTesting
  void emitEngineLineForTesting(String line) => _handleEngineStdoutLine(line);

  /// Single entry point for engine stdout, shared by the real isolate listener
  /// and the fake engine used in tests. Keeping readyok accounting here (rather
  /// than inside individual waiters) is what makes request/response generations
  /// observable by [_waitForReadyOk] and [_stopCurrentSearchAndWait].
  void _handleEngineStdoutLine(String line) {
    if (line.trim().isEmpty) return;
    if (line.contains('readyok')) {
      _readyokCount++;
      _isReady = true;
      _consecutiveCrashes = 0; // Reset crash counter on successful ready
      statusNotifier.value = EngineStatus.ready;
      // Process any queued commands now that engine is fully initialized
      _processCommandQueue();
    }
    _outputController.add(line);
  }

  /// Whether any listener is currently subscribed to the output stream.
  /// Used by tests to verify subscriptions are always cleaned up.
  @visibleForTesting
  bool get hasOutputListenersForTesting => _outputController.hasListener;

  /// Whether a search currently owns the engine slot. Used by tests to verify
  /// the engine is never left wedged after timeouts/errors.
  @visibleForTesting
  bool get isEngineBusyForTesting => _isEngineBusy;

  /// Drives [_waitForReadyOk] directly so tests can verify that only a fresh
  /// readyok (one received after the request) releases the wait.
  @visibleForTesting
  Future<bool> waitForReadyOkForTesting({Duration? timeout}) =>
      _waitForReadyOk(timeout: timeout);

  /// Re-enables real readyok waits after [setReadyForTesting] short-circuited
  /// them, so protocol-ordering tests can exercise the stop handshake.
  @visibleForTesting
  void disableImmediateReadyOkForTesting() => _skipReadyOkForTesting = false;

  /// Drives [_stopCurrentSearchAndWait] directly for stop-handshake tests.
  @visibleForTesting
  Future<void> stopCurrentSearchAndWaitForTesting() =>
      _stopCurrentSearchAndWait();

  /// Exposes the production analysis budget so tests can assert that deep
  /// searches are no longer capped at the old flat 5 s timeout.
  @visibleForTesting
  Duration effectiveAnalysisTimeoutForTesting({
    required int depth,
    required int multiPv,
    int? nodes,
  }) => _effectiveAnalysisTimeout(depth: depth, multiPv: multiPv, nodes: nodes);

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
    final pendingDispose = _disposeFuture;
    if (pendingDispose != null) {
      await pendingDispose;
    }
    if (_isDisposed) {
      _isDisposed = false;
      _disposeFuture = null;
      statusNotifier.value = EngineStatus.initializing;
    }
    if (_isReady || _useFallback) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    statusNotifier.value = EngineStatus.initializing;
    debugPrint('ENGINE LIFECYCLE → Starting Stockfish initialization');

    // --- Step 0: Circuit breaker — too many crashes, stay in fallback ---
    // Only activate if we've had actual isolate crashes (not just init failures).
    // Reset counter if we've been in fallback for a while (recovery window).
    if (_consecutiveCrashes >= _maxConsecutiveCrashes) {
      final timeSinceFallback =
          _lastFallbackTime != null
              ? DateTime.now().difference(_lastFallbackTime!)
              : Duration.zero;
      if (timeSinceFallback < const Duration(minutes: 5)) {
        _enableFallback(
          'Circuit breaker: $_consecutiveCrashes consecutive crashes',
        );
        return;
      } else {
        // Recovery window elapsed — reset and try again
        _consecutiveCrashes = 0;
      }
    }

    // --- Step 1: Verify binary is not force-disabled ---
    if (_forceFallback) {
      _enableFallback('Binary verification failed (forceFallback)');
      return;
    }

    // --- Step 1: Start the engine isolate ---
    try {
      await _startEngineIsolate();
      if (_isDisposed || _engineCommandPort == null) {
        await _killEngineIfRunning();
        final initCompleter = _initCompleter;
        _initCompleter = null;
        initCompleter?.complete();
        return;
      }
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
        _sendCommandDirect(
          'setoption name Threads value $livePlayThreads',
        ); // Single thread for stability
        _sendCommandDirect(
          'setoption name Hash value $livePlayHashMb',
        ); // 32MB to reduce memory pressure
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
        final initCompleter = _initCompleter;
        _initCompleter = null;
        initCompleter?.complete();
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
      }
    }
  }

  void _enableFallback(String reason) {
    _lastFallbackTime = DateTime.now();
    _useFallback = true;
    _isReady = false;
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

  /// Wait for a *fresh* readyok response after sending isready.
  /// This ensures Stockfish has fully processed the position before we start
  /// the search and keeps a stale readyok from an earlier handshake from
  /// releasing the wait early.
  /// Returns true if readyok received, false on timeout.
  /// The output-stream subscription is guaranteed to be cancelled on every exit
  /// path (readyok, timeout, error) via `finally`.
  Future<bool> _waitForReadyOk({Duration? timeout}) async {
    if (_skipReadyOkForTesting) return true;

    final effectiveTimeout = timeout ?? const Duration(milliseconds: 500);
    // Capture the response generation before sending the request. Only a
    // readyok counted after this point can satisfy this waiter.
    final targetResponseCount = _readyokCount + 1;
    final completer = Completer<bool>();

    final subscription = _outputController.stream.listen((line) {
      if (_readyokCount >= targetResponseCount &&
          line.contains('readyok') &&
          !completer.isCompleted) {
        completer.complete(true);
      }
    });

    try {
      if (_readyokCount >= targetResponseCount) return true;

      _sendCommand('isready');

      return await completer.future.timeout(
        effectiveTimeout,
        onTimeout: () {
          if (!completer.isCompleted) completer.complete(false);
          return false;
        },
      );
    } catch (e) {
      return false;
    } finally {
      await subscription.cancel();
    }
  }

  /// Send a command to the engine (queued for serial execution)
  void _sendCommand(String command) {
    if (_isDisposed || _useFallback) return;

    _commandQueue.add(_QueuedCommand(command: command));
    _processCommandQueue();
  }

  /// Process commands serially to prevent concurrent engine access
  bool _isProcessingQueue = false;

  void _processCommandQueue() async {
    if (_isProcessingQueue || _isDisposed) return;
    if (_engineCommandPort == null) return;
    if (!_isReady) return; // Don't send until engine is fully initialized

    _isProcessingQueue = true;

    try {
      while (_commandQueue.isNotEmpty) {
        final cmd = _commandQueue.removeAt(0);
        try {
          // The plugin's stdin setter appends a newline itself. Sending one
          // here produced an extra blank UCI command on every write.
          _engineCommandPort?.send({'type': 'stdin', 'command': cmd.command});
          // Small delay between commands to prevent overwhelming the engine
          await Future.delayed(const Duration(milliseconds: 10));
        } catch (e) {
          _enableFallback('Failed to send engine command: $e');
          _commandQueue.clear();
          break;
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Send a command directly to the engine isolate, bypassing the command queue.
  /// Used ONLY during initialization to avoid the queue deadlock (the queue
  /// requires _isReady which is not set until after UCI handshake completes).
  void _sendCommandDirect(String command) {
    if (_isDisposed || _useFallback) return;
    debugPrint('ENGINE INIT: $command');
    _engineCommandPort?.send({'type': 'stdin', 'command': command});
  }

  /// Wait for a specific pattern to appear in the engine's output stream.
  /// Returns true if the pattern was found within the timeout, false otherwise.
  /// The output-stream subscription is guaranteed to be cancelled on every exit
  /// path (pattern found, timeout, error) via `finally`.
  Future<bool> _waitForOutputPattern(
    String pattern, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<bool>();
    final sub = _outputController.stream.listen((line) {
      if (line.contains(pattern) && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (!completer.isCompleted) completer.complete(false);
          debugPrint(
            'ENGINE INIT: Timeout waiting for "$pattern" after $timeout',
          );
          return false;
        },
      );
    } catch (e) {
      return false;
    } finally {
      await sub.cancel();
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
    final turn = fen.trim().split(_fenSpaceRegex);
    if (turn.length >= 2 && turn[1] == 'b') {
      return -scoreCp;
    }
    return scoreCp;
  }

  /// Convert an engine side-to-move "score mate N" into a white-relative mate
  /// count (positive = white mates, negative = black mates).
  ///
  /// For N != 0 this is just [_toWhiteRelative] (Stockfish mate scores are
  /// relative to the side to move). For N == 0 the side to move is checkmated
  /// right now and the sign is lost in [_toWhiteRelative] (negating zero is
  /// zero), so the winner must be derived from the FEN side-to-move: if black
  /// is to move, black is the mated side and white-relative is positive.
  @visibleForTesting
  int mateToWhiteRelative(int rawMate, String fen) {
    if (rawMate != 0) {
      return _toWhiteRelative(rawMate, fen);
    }
    final turn = fen.trim().split(_fenSpaceRegex);
    final blackToMove = turn.length >= 2 && turn[1] == 'b';
    return blackToMove ? 1 : -1;
  }

  /// Test-only accessor for [_isValidFen].
  @visibleForTesting
  bool isValidFenForTesting(String fen) => _isValidFen(fen);

  /// Validate that a sequence of UCI moves is legal starting from [startingFen] or [fen].
  bool _areMovesLegal(String fen, String? startingFen, List<String>? moves) {
    if (moves == null || moves.isEmpty) return true;
    try {
      final baseFen =
          (startingFen != null && startingFen.isNotEmpty) ? startingFen : fen;

      if (!_isValidFen(baseFen)) return false;

      final chess = chess_lib.Chess.fromFEN(baseFen);
      for (final moveStr in moves) {
        if (moveStr.isEmpty || moveStr.length < 4) return false;
        final from = moveStr.substring(0, 2);
        final to = moveStr.substring(2, 4);
        final promotion = moveStr.length > 4 ? moveStr[4] : null;

        final moveObj = {
          'from': from,
          'to': to,
          if (promotion != null) 'promotion': promotion,
        };

        final result = chess.move(moveObj);
        if (result == false) {
          return false; // Illegal move in sequence
        }
      }
      return true;
    } catch (e) {
      debugPrint('Move sequence validation failed: $e');
      return false;
    }
  }

  @visibleForTesting
  bool areMovesLegalForTesting(
    String fen,
    String? startingFen,
    List<String>? moves,
  ) => _areMovesLegal(fen, startingFen, moves);

  /// Compact signature (board, side to move, normalized castling rights) used
  /// to confirm that a starting FEN plus a move list really describes the
  /// current position. Clocks and the ep square are deliberately ignored:
  /// different FEN producers represent them slightly differently, and
  /// Stockfish derives both from the move list anyway.
  static String _positionSignature(String fen) {
    final parts = fen.trim().split(_fenSpaceRegex);
    if (parts.length < 3) return fen.trim();
    final castling =
        parts[2] == '-' ? '-' : (parts[2].split('')..sort()).join();
    return '${parts[0]} ${parts[1]} $castling';
  }

  /// Apply [moves] to [startingFen] and verify the resulting board matches
  /// [fen]. A mismatch means the UI position and the engine's move list have
  /// diverged; sending the list would make Stockfish analyze a different
  /// position than the one shown on screen.
  bool _movesLeadToFen(String fen, String startingFen, List<String> moves) {
    try {
      final chess = chess_lib.Chess.fromFEN(startingFen);
      for (final moveStr in moves) {
        if (moveStr.length < 4) return false;
        final moveObj = {
          'from': moveStr.substring(0, 2),
          'to': moveStr.substring(2, 4),
          if (moveStr.length > 4) 'promotion': moveStr[4],
        };
        if (chess.move(moveObj) == false) return false;
      }
      return _positionSignature(chess.fen) == _positionSignature(fen);
    } catch (e) {
      debugPrint('Move sequence / FEN consistency check failed: $e');
      return false;
    }
  }

  /// Expand a FEN rank (e.g. `r1bqkbnr`) into 8 square chars
  /// (empty squares as `' '`) for home-square checks.
  static List<String> _expandRank(String rank) {
    final squares = <String>[];
    for (int i = 0; i < rank.length && squares.length < 8; i++) {
      final char = rank[i];
      final empty = int.tryParse(char);
      if (empty != null) {
        for (int j = 0; j < empty; j++) {
          squares.add(' ');
        }
      } else {
        squares.add(char);
      }
    }
    while (squares.length < 8) {
      squares.add(' ');
    }
    return squares;
  }

  /// Internal FEN validation to prevent native Stockfish C++ engine crashes (SIGSEGV).
  /// Enforces board structure, piece counts, valid kings, castling, move numbers,
  /// pawn placement, and king adjacency.
  bool _isValidFen(String fen) {
    if (fen.isEmpty) return false;
    final parts = fen.trim().split(_fenSpaceRegex);
    if (parts.length < 4) return false; // At least board, color, castling, ep

    // Basic regex for the board part
    final boardPart = parts[0];
    final rows = boardPart.split('/');
    if (rows.length != 8) return false;

    int whiteKingCount = 0;
    int blackKingCount = 0;
    int whitePawnCount = 0;
    int blackPawnCount = 0;
    int whiteNonPawnCount = 0;
    int blackNonPawnCount = 0;

    // Track king positions for adjacency check (row, col)
    int? whiteKingRow, whiteKingCol, blackKingRow, blackKingCol;

    for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
      final row = rows[rowIdx];
      int count = 0;
      for (int i = 0; i < row.length; i++) {
        final char = row[i];
        if (char == 'K') {
          whiteKingCount++;
          whiteKingRow = rowIdx;
          whiteKingCol = count;
        }
        if (char == 'k') {
          blackKingCount++;
          blackKingRow = rowIdx;
          blackKingCol = count;
        }
        if (char == 'P') whitePawnCount++;
        if (char == 'p') blackPawnCount++;

        if (_fenPieceRegex.hasMatch(char)) {
          count += 1;
          // Count non-pawn, non-king pieces for promotion sanity check
          if (char != 'K' && char != 'k' && char != 'P' && char != 'p') {
            if (char == char.toUpperCase()) {
              whiteNonPawnCount++;
            } else {
              blackNonPawnCount++;
            }
          }
        } else if (_fenDigitRegex.hasMatch(char)) {
          count += int.parse(char);
        } else {
          return false; // Invalid character
        }
      }
      if (count != 8) return false;
    }

    // Must have exactly one White King and one Black King for valid Stockfish state
    if (whiteKingCount != 1 || blackKingCount != 1) return false;

    // Kings must not be adjacent (would mean illegal position with both kings in check)
    if (whiteKingRow != null &&
        blackKingRow != null &&
        whiteKingCol != null &&
        blackKingCol != null) {
      final rowDiff = (whiteKingRow - blackKingRow).abs();
      final colDiff = (whiteKingCol - blackKingCol).abs();
      if (rowDiff <= 1 && colDiff <= 1) return false;
    }

    // No pawns on rank 1 or 8 (they must have promoted)
    if (rows[0].contains('P') || rows[0].contains('p')) return false;
    if (rows[7].contains('P') || rows[7].contains('p')) return false;

    // Pawn count sanity (max 8 per side)
    if (whitePawnCount > 8 || blackPawnCount > 8) return false;

    // Promotion sanity: a side starts with 8 non-pawn pieces (including the
    // king). Every additional queen/rook/bishop/knight must have come from a
    // promotion, and a promoted pawn is no longer a pawn, so the total men per
    // side is capped at 16. The non-pawn count alone can therefore reach 15
    // (king + 15 promoted pieces) in a legal position — the old cap of 8
    // rejected legal promoted-piece positions and pushed them to fallback.
    if (whiteNonPawnCount > 15 || blackNonPawnCount > 15) return false;

    // Color check
    final color = parts[1];
    if (color != 'w' && color != 'b') return false;

    // Castling check — must not have duplicate flags and must be consistent with king/rook positions
    final castling = parts[2];
    if (castling != '-') {
      final validCastling = RegExp(r'^[KQkq]+$');
      if (!validCastling.hasMatch(castling)) return false;
      // Check for duplicate characters
      if (castling.length != castling.split('').toSet().length) return false;
      // If castling rights exist, king must be on e1/e8
      if (castling.contains('K') && !rows[7].contains('K')) return false;
      // White king on e1 for any white castling
      if ((castling.contains('K') || castling.contains('Q')) &&
          whiteKingRow != 7) {
        return false;
      }
      if ((castling.contains('k') || castling.contains('q')) &&
          blackKingRow != 0) {
        return false;
      }
    }

    // En passant check
    final ep = parts[3];
    if (ep != '-') {
      final validEp = RegExp(r'^[a-h][36]$');
      if (!validEp.hasMatch(ep)) return false;
      // The ep square is the skipped square of the last double push, so its
      // rank must match the side to move: rank 6 (black just pushed... i.e.
      // white to move) or rank 3 (white just pushed, black to move).
      // A stale ep square from a custom position setup is a known trigger
      // for native Position::is_draw crashes — reject it to fallback.
      final epRank = ep[1];
      if (epRank == '6' && color != 'w') {
        return false;
      }
      if (epRank == '3' && color != 'b') {
        return false;
      }

      // Beyond the rank check, the ep square only makes sense if the target
      // is empty and the double-pushed pawn's origin is empty. Do NOT require
      // an adjacent capturing pawn: FEN producers commonly record the skipped
      // square even when no capture is available (e.g. after 1.e4), and
      // Stockfish clears an unusable ep square internally anyway.
      final epFile = ep.codeUnitAt(0) - 0x61; // 'a'
      if (epRank == '6') {
        final target = _expandRank(rows[2]); // rank 6
        final origin = _expandRank(rows[1]); // rank 7
        if (target[epFile] != ' ') return false;
        if (origin[epFile] != ' ') return false;
      } else {
        final target = _expandRank(rows[5]); // rank 3
        final origin = _expandRank(rows[6]); // rank 2
        if (target[epFile] != ' ') return false;
        if (origin[epFile] != ' ') return false;
      }
    }

    // Total material cap: a side can never own more than its initial 16 men
    // (promotions don't change the count, captures only reduce it).
    final whiteTotal = whitePawnCount + whiteNonPawnCount + whiteKingCount;
    final blackTotal = blackPawnCount + blackNonPawnCount + blackKingCount;
    if (whiteTotal > 16 || blackTotal > 16) return false;

    // Castling consistency: rights require the king on its home square AND
    // the corresponding rook on its home square. Missing pieces with rights
    // set describe an impossible position the native parser chokes on.
    if (castling != '-') {
      final rank1 = _expandRank(rows[7]);
      final rank8 = _expandRank(rows[0]);
      if (castling.contains('K') && (rank1[4] != 'K' || rank1[7] != 'R')) {
        return false;
      }
      if (castling.contains('Q') && (rank1[4] != 'K' || rank1[0] != 'R')) {
        return false;
      }
      if (castling.contains('k') && (rank8[4] != 'k' || rank8[7] != 'r')) {
        return false;
      }
      if (castling.contains('q') && (rank8[4] != 'k' || rank8[0] != 'r')) {
        return false;
      }
    }

    // Halfmove and fullmove checks if provided
    if (parts.length >= 5) {
      final halfmove = int.tryParse(parts[4]);
      if (halfmove == null || halfmove < 0) return false;
    }
    if (parts.length >= 6) {
      final fullmove = int.tryParse(parts[5]);
      if (fullmove == null || fullmove <= 0) return false;
    }

    return true;
  }

  /// Sanitize FEN string to prevent Stockfish C++ parser edge case crashes.
  /// Clamps halfmove clock (rule50) to 0..100 and fullmove to 1..999.
  static String sanitizeFen(String fen) {
    final parts = fen.trim().split(_fenSpaceRegex);
    if (parts.length < 4) return fen.trim();
    var halfmove = '0';
    var fullmove = '1';
    if (parts.length >= 5) {
      final hm = int.tryParse(parts[4]) ?? 0;
      halfmove = hm.clamp(0, 100).toString();
    }
    if (parts.length >= 6) {
      final fm = int.tryParse(parts[5]) ?? 1;
      fullmove = fm.clamp(1, 999).toString();
    }
    return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]} $halfmove $fullmove';
  }

  /// Build the UCI "position" command for a given position.
  /// When [startingFen] and [moves] are provided, emits the full move list so
  /// Stockfish can detect repetition draws (threefold, fifty-move rule).
  @visibleForTesting
  String buildPositionCommand({
    required String fen,
    String? startingFen,
    List<String>? moves,
  }) {
    final cleanFen = sanitizeFen(fen);
    if (startingFen == null ||
        startingFen.isEmpty ||
        moves == null ||
        moves.isEmpty) {
      return 'position fen $cleanFen';
    }
    // Verify move sequence is strictly legal to prevent Stockfish C++ do_move SIGSEGV
    if (!_areMovesLegal(fen, startingFen, moves)) {
      debugPrint(
        'Moves sequence not legal for position command; falling back to current FEN',
      );
      return 'position fen $cleanFen';
    }
    // A legal move list that ends somewhere other than the displayed position
    // is just as dangerous: the engine would analyze a different board than
    // the UI. Fall back to the single current FEN in that case.
    if (!_movesLeadToFen(fen, startingFen, moves)) {
      debugPrint(
        'Moves sequence does not reproduce the current FEN; falling back to current FEN',
      );
      return 'position fen $cleanFen';
    }
    final cleanStartingFen = sanitizeFen(startingFen);
    final movesPart = ' moves ${moves.join(' ')}';
    return 'position fen $cleanStartingFen$movesPart';
  }

  /// Get the best move for a given position
  /// [fen] - Position in FEN notation
  /// [depth] - Search depth (1-22)
  /// [thinkTimeMs] - Optional think time limit in milliseconds
  /// [startingFen] - Optional starting FEN to emit with the full move list so
  ///   the engine can detect repetition draws.
  /// [moves] - Optional UCI move list to send with [startingFen].
  ///
  /// Playing strength is configured once per game via `setSkillLevel()` /
  /// `resetForNewGame()` — it is NOT re-sent here on every move (P3-a).
  Future<BestMoveResult> getBestMove({
    required String fen,
    required int depth,
    int? thinkTimeMs,
    String? startingFen,
    List<String>? moves,
  }) async {
    // Validate FEN to prevent SIGSEGV in Stockfish::Position::is_draw
    if (!_isValidFen(fen) || !_areMovesLegal(fen, startingFen, moves)) {
      debugPrint('Invalid FEN detected: $fen. Using fallback.');
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    // Guard: If disposed, return fallback
    if (_isDisposed) {
      return _getSimpleBotMove(fen, depth, thinkTimeMs);
    }

    final searchId = ++_activeSearchId;

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

    return _executionQueue.run(() async {
      if (_isSearchCancelled(searchId)) {
        return _cancelledBestMoveResult();
      }
      if (_useFallback && _shouldRetryInit()) {
        await _tryFallbackRecovery();
      }
      if (!_isReady && !_useFallback) {
        await initialize();
      }
      if (_isSearchCancelled(searchId)) {
        return _cancelledBestMoveResult();
      }
      if (_useFallback || !_isReady) {
        return _getSimpleBotMove(fen, depth, thinkTimeMs);
      }

      if (_isEngineBusy) {
        debugPrint('Engine is busy, using fallback for FEN: $fen');
        return _getSimpleBotMove(fen, depth, thinkTimeMs);
      }
      _isEngineBusy = true;
      StreamSubscription<String>? subscription;

      try {
        // Stop any lingering search from a previous call BEFORE attaching our
        // listener, so a stale bestmove line cannot be consumed by this search.
        await _stopCurrentSearchAndWait();
        if (_isSearchCancelled(searchId)) {
          return _cancelledBestMoveResult();
        }

        final completer = Completer<BestMoveResult>();
        String? bestMove;
        String? ponderMove;
        int? evaluation;
        int? mateIn;
        var goSent = false;

        subscription = _outputController.stream.listen((line) {
          final trimmedLine = line.trim();
          if (_isSearchCancelled(searchId)) {
            if (goSent && trimmedLine.startsWith('bestmove')) {
              _searchInFlight = false;
              subscription?.cancel();
              if (!completer.isCompleted) {
                completer.complete(_cancelledBestMoveResult());
              }
            }
            return;
          }

          // Parse evaluation from info line.
          // Stockfish's "score cp" is from the side-to-move's perspective.
          // Convert to white-relative for consistent storage.
          if (trimmedLine.startsWith('info') && trimmedLine.contains('score')) {
            final scoreMatch = _scoreCpRegex.firstMatch(trimmedLine);
            if (scoreMatch != null) {
              evaluation = _toWhiteRelative(
                int.parse(scoreMatch.group(1)!),
                fen,
              );
            }

            final mateMatch = _scoreMateRegex.firstMatch(trimmedLine);
            if (mateMatch != null) {
              final rawMate = mateToWhiteRelative(
                int.parse(mateMatch.group(1)!),
                fen,
              );
              mateIn = rawMate;
              // Convert mate to centipawn value for consistent evaluation
              evaluation =
                  rawMate > 0
                      ? (10000 - rawMate * 10)
                      : (-10000 + rawMate.abs() * 10);
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

            if (!goSent) return;
            _searchInFlight = false;
            subscription?.cancel();
            if (!completer.isCompleted) {
              completer.complete(
                BestMoveResult(
                  bestMove: bestMove ?? '',
                  ponderMove: ponderMove,
                  evaluation: evaluation,
                  mateIn: mateIn,
                ),
              );
            }
          }
        });

        // Set position for bot search. Emit the full move list (starting FEN +
        // UCI moves) when available so Stockfish can detect repetition draws;
        // otherwise fall back to a clean sanitized current FEN. A clean FEN
        // creates a single root StateInfo in Stockfish C++, preventing dangling
        // pointer traversal in Position::is_draw.
        _sendCommand(
          buildPositionCommand(
            fen: fen,
            startingFen: startingFen,
            moves: moves,
          ),
        );

        // Wait for engine to confirm position is processed before starting search
        // This prevents SIGSEGV in Stockfish::Position::is_draw by ensuring position is valid
        final positionReady = await _waitForReadyOk(
          timeout: const Duration(milliseconds: 1500),
        );
        if (!positionReady) {
          debugPrint('Position ready timeout for FEN: $fen. Using fallback.');
          return await _getSimpleBotMove(fen, depth, thinkTimeMs);
        }
        if (_isSearchCancelled(searchId)) {
          return _cancelledBestMoveResult();
        }

        // UCI search command strategy:
        //   Bot play  → "go movetime <ms>" — time-bounded search (no depth limit)
        //   Analysis  → "go depth <depth>" — depth-bounded search (no time limit)
        //
        // Never combine depth and movetime in one "go" command (ISSUE-006).
        goSent = true;
        if (thinkTimeMs != null) {
          _searchInFlight = true;
          _sendCommand('go movetime $thinkTimeMs');
        } else {
          _searchInFlight = true;
          _sendCommand('go depth $depth');
        }

        // Failsafe timeout for Stockfish response: dynamic based on thinkTimeMs
        final effectiveTimeout =
            searchTimeoutForTesting != const Duration(seconds: 30)
                ? searchTimeoutForTesting
                : (thinkTimeMs != null
                    ? Duration(milliseconds: thinkTimeMs * 2 + 2500)
                    : searchTimeoutForTesting);
        return await completer.future.timeout(
          effectiveTimeout,
          onTimeout: () async {
            debugPrint(
              'ENGINE RECOVERY → Search timeout for FEN: $fen, using fallback for this move',
            );
            _sendCommand('stop');
            await _stopCurrentSearchAndWait();
            if (_isSearchCancelled(searchId)) {
              return _cancelledBestMoveResult();
            }
            return _getSimpleBotMove(fen, depth, thinkTimeMs);
          },
        );
      } finally {
        await subscription?.cancel();
        if (_searchInFlight) {
          await _stopCurrentSearchAndWait();
        }
        _isEngineBusy = false;
      }
    });
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
    return 3;
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
      timeLimitMs: _fallbackTimeLimit(thinkTimeMs),
    );
    return BestMoveResult(
      bestMove: result.bestMove,
      evaluation: result.evaluation,
    );
  }

  int _fallbackTimeLimit(int? thinkTimeMs) {
    if (thinkTimeMs == null) return 900;
    return thinkTimeMs.clamp(500, 1200);
  }

  /// Search budget for [analyzePosition].
  ///
  /// Production used a flat 5 s budget (the test-named field had leaked into
  /// the production path). A depth-12 / MultiPV-3 search routinely exceeds
  /// that on low-end devices, so every analysis ended in stop + fallback,
  /// producing repeated engine churn while the user was trying to interact
  /// with the app. The budget now scales with requested depth and MultiPV,
  /// clamped to a range that still guarantees a bounded wait.
  ///
  /// Tests that need a deterministic short timeout set
  /// [analysisTimeoutForTesting], which bypasses this calculation.
  Duration _effectiveAnalysisTimeout({
    required int depth,
    required int multiPv,
    int? nodes,
  }) {
    if (_analysisTimeoutWasSet) return _analysisTimeout;
    if (nodes != null) {
      // Node-bounded searches are deterministic; allow a fixed generous
      // budget that does not depend on device speed.
      return const Duration(seconds: 10);
    }
    final depthBudgetMs = 2000 + depth * 750;
    final multiPvBudgetMs = 1500 + multiPv * 1000;
    final requested =
        depthBudgetMs > multiPvBudgetMs ? depthBudgetMs : multiPvBudgetMs;
    final budgetMs =
        requested < 6000 ? 6000 : (requested > 20000 ? 20000 : requested);
    return Duration(milliseconds: budgetMs);
  }

  /// Analyze a position and get multiple lines
  /// Returns evaluation and top engine lines
  /// [startingFen] and [moves] are optional; when provided the engine is told
  /// the full move list so it can detect repetition draws.
  ///
  /// [nodes], when set, bounds the search by node count (`go nodes N`) instead
  /// of by depth, and [depth] is ignored. This is both much faster and
  /// deterministic — the engine stops after exactly N nodes, so the same
  /// position always yields the same score on any device.
  ///
  /// [isBatchAnalysis] marks this call as part of a sequential full-game pass.
  /// Consecutive plies of one game are closely related positions, so the
  /// transposition table is deliberately NOT flushed between them — see the
  /// `ucinewgame` guard below. Leave false for live play, new analysis
  /// sessions and non-sequential position jumps.
  Future<AnalysisResult> analyzePosition({
    required String fen,
    int depth = AppConstants.analysisDepth,
    int multiPv = AppConstants.topEngineLinesCount,
    void Function(AnalysisResult)? onUpdate,
    String? startingFen,
    List<String>? moves,
    bool isBatchAnalysis = false,
    int? nodes,
  }) async {
    // Validate FEN to prevent SIGSEGV
    if (!_isValidFen(fen) || !_areMovesLegal(fen, startingFen, moves)) {
      debugPrint('Invalid FEN detected for analysis: $fen');
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Fast-path: If position is already terminal (checkmate/stalemate/draw), return immediately
    // with correct evaluation rather than running search on a position with no legal moves.
    try {
      final chessObj = chess_lib.Chess.fromFEN(fen);
      if (chessObj.in_checkmate) {
        final whiteMated = chessObj.turn == chess_lib.Color.WHITE;
        final mateScoreCp = whiteMated ? -10000 : 10000;
        final mateScorePawns = whiteMated ? -100.0 : 100.0;
        final mateIn = whiteMated ? -1 : 1;
        return AnalysisResult(
          evaluation: mateScoreCp,
          mateIn: mateIn,
          lines: [
            EngineLine(
              rank: 1,
              evaluation: mateScorePawns,
              depth: 0,
              moves: const [],
              isMate: true,
              mateIn: mateIn,
            ),
          ],
          depth: 0,
        );
      }
      if (chessObj.in_stalemate || chessObj.in_draw) {
        return AnalysisResult(
          evaluation: 0,
          lines: [
            EngineLine(
              rank: 1,
              evaluation: 0.0,
              depth: 0,
              moves: const [],
              isMate: false,
            ),
          ],
          depth: 0,
        );
      }
    } catch (_) {}

    final searchId = ++_activeSearchId;

    // Guard: If disposed, return fallback
    if (_isDisposed) {
      return BasicEvaluatorService.instance.analyze(fen);
    }

    // Attempt fallback recovery if cooldown has elapsed
    if (_useFallback && _shouldRetryInit()) {
      await _tryFallbackRecovery();
    }

    if (!_isReady && !_useFallback) {
      await initialize();
    }

    if (_isSearchCancelled(searchId)) {
      return _cancelledAnalysisResult();
    }

    // If using fallback, use basic evaluator
    if (_useFallback) {
      debugPrint('Engine not ready for analysis, using fallback for FEN: $fen');
      return BasicEvaluatorService.instance.analyze(fen);
    }

    return _executionQueue.run(() async {
      if (_isSearchCancelled(searchId)) {
        return _cancelledAnalysisResult();
      }
      if (_useFallback && _shouldRetryInit()) {
        await _tryFallbackRecovery();
      }
      if (!_isReady && !_useFallback) {
        await initialize();
      }
      if (_isSearchCancelled(searchId)) {
        return _cancelledAnalysisResult();
      }
      if (_useFallback || !_isReady) {
        debugPrint(
          'Engine not ready for analysis, using fallback for FEN: $fen',
        );
        return BasicEvaluatorService.instance.analyze(fen);
      }

      if (_isEngineBusy || _searchInFlight) {
        await _stopCurrentSearchAndWait();
      }
      if (_isSearchCancelled(searchId)) {
        return _cancelledAnalysisResult();
      }
      _isEngineBusy = true;

      final analysisCompleter = Completer<AnalysisResult>();
      final callStarted = DateTime.now();
      StreamSubscription<String>? subscription;

      try {
        // Stop any lingering search from a previous call BEFORE attaching our
        // listener, so a stale bestmove line cannot be consumed by this analysis.
        final wasStopped = _searchInFlight;
        await _stopCurrentSearchAndWait();
        if (_isSearchCancelled(searchId)) {
          return _cancelledAnalysisResult();
        }

        // Reset engine state before new analysis to prevent SIGSEGV from stale TT entries.
        // Only send ucinewgame when we actually stopped a previous search, to avoid
        // unnecessary engine overhead on the common first-call path.
        //
        // During a sequential full-game pass this is suppressed: each ply issues
        // back-to-back searches, so ucinewgame fired every ply and wiped the
        // transposition table between positions that differ by a single move.
        // Keeping the TT lets the engine reuse that work.
        if (wasStopped && !isBatchAnalysis) {
          _sendCommand('ucinewgame');
        }

        // Set MultiPV for multiple lines
        _sendCommand('setoption name MultiPv value $multiPv');

        final completer = analysisCompleter;
        final lines = <EngineLine>[];
        int? mainEvaluation;
        int? mateIn;
        var goSent = false;

        // Per-depth accumulation so the final result can be taken from the
        // deepest COMPLETED iteration rather than whatever was mid-flight when
        // `bestmove` arrived. Keyed by depth, then by MultiPV rank.
        final linesByDepth = <int, Map<int, EngineLine>>{};
        final evalByDepth = <int, int?>{};
        final mateByDepth = <int, int?>{};
        DateTime lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
        int lastUiDepth = -1;

        subscription = _outputController.stream.listen((line) {
          final trimmedLine = line.trim();
          if (_isSearchCancelled(searchId)) {
            if (goSent && trimmedLine.startsWith('bestmove')) {
              _searchInFlight = false;
              subscription?.cancel();
              if (!completer.isCompleted) {
                completer.complete(_cancelledAnalysisResult());
              }
            }
            return;
          }

          if (trimmedLine.startsWith('info') && trimmedLine.contains('pv')) {
            final pvMatch = _multiPvRegex.firstMatch(trimmedLine);
            final depthMatch = _depthRegex.firstMatch(trimmedLine);
            final scoreMatch = _scoreCpRegex.firstMatch(trimmedLine);
            final mateMatch = _scoreMateRegex.firstMatch(trimmedLine);
            final pvMovesMatch = _pvMovesRegex.firstMatch(trimmedLine);

            if (pvMovesMatch != null) {
              final pvNumber =
                  pvMatch != null ? int.parse(pvMatch.group(1)!) : 1;
              final currentDepth =
                  depthMatch != null ? int.parse(depthMatch.group(1)!) : 0;
              int? eval;
              int? mate;

              if (scoreMatch != null) {
                eval = _toWhiteRelative(int.parse(scoreMatch.group(1)!), fen);
              }
              if (mateMatch != null) {
                mate = mateToWhiteRelative(int.parse(mateMatch.group(1)!), fen);
              }

              final moves = pvMovesMatch.group(1)!.split(' ');

              // Convert mate score to centipawns for consistent handling.
              // Mate in N → large centipawn value so classifyMate() works.
              // White-relative: positive = white mates, negative = black mates.
              int? effectiveEval = eval;
              if (mate != null) {
                // Mate in N moves: use a large value that decreases as mate gets farther.
                // 10000 - mate*10 ensures mate-in-1 >> mate-in-2 >> ... >> best non-mate.
                effectiveEval =
                    mate > 0 ? (10000 - mate * 10) : (-10000 + mate.abs() * 10);
              }

              final engineLine = EngineLine(
                rank: pvNumber,
                evaluation: (effectiveEval ?? 0) / 100.0,
                depth: currentDepth,
                moves: moves,
                isMate: mate != null,
                mateIn: mate,
              );

              // ── Deterministic result capture ──
              // Stockfish emits a full set of MultiPV lines for depth 1, then 2,
              // and so on. Overwriting a single flat list meant the captured
              // result depended on exactly which iteration was in flight when
              // `bestmove` arrived — the same position could resolve at a
              // different depth, or with lines from two different depths mixed,
              // on every run. Group lines by the depth that produced them and
              // only publish a completed iteration (see `bestmove` below).
              final bucket = linesByDepth.putIfAbsent(currentDepth, () => {});
              bucket[pvNumber] = engineLine;

              if (pvNumber == 1) {
                evalByDepth[currentDepth] = effectiveEval;
                mateByDepth[currentDepth] = mate;

                // Progressive UI updates may use the in-flight iteration; only
                // the final committed result has to be deterministic.
                mainEvaluation = effectiveEval;
                mateIn = mate;
              }

              // Keep the live view in sync for onUpdate consumers.
              if (lines.length >= pvNumber) {
                lines[pvNumber - 1] = engineLine;
              } else {
                lines.add(engineLine);
              }

              final now = DateTime.now();
              // Throttle progressive UI updates to ~5/sec (200ms) so a long
              // analysis does not flood the UI isolate with setState work
              // (PlatformTaskQueue / input-dispatching ANR source). Keep only
              // the latest line; consumers recompute from it.
              final shouldNotify =
                  currentDepth > lastUiDepth ||
                  now.difference(lastUiUpdate).inMilliseconds >= 200;
              if (onUpdate != null && mainEvaluation != null && shouldNotify) {
                lastUiUpdate = now;
                lastUiDepth = currentDepth;
                try {
                  onUpdate(
                    AnalysisResult(
                      evaluation: mainEvaluation!,
                      mateIn: mateIn,
                      lines: List.from(lines),
                      depth: currentDepth,
                    ),
                  );
                } catch (e) {
                  debugPrint('Analysis update callback failed: $e');
                }
              }
            }
          }

          if (trimmedLine.startsWith('bestmove')) {
            if (!goSent) return;
            _searchInFlight = false;
            subscription?.cancel();
            // Reset MultiPV to 1
            _sendCommand('setoption name MultiPV value 1');

            if (!completer.isCompleted) {
              // Publish the deepest iteration that produced a COMPLETE set of
              // MultiPV lines. A partially-emitted deeper iteration is discarded,
              // so the same position always resolves to the same eval instead of
              // depending on when `bestmove` happened to interrupt the search.
              int? bestDepth;
              for (final entry in linesByDepth.entries) {
                final complete = entry.value.length >= multiPv;
                if (!complete) continue;
                if (bestDepth == null || entry.key > bestDepth) {
                  bestDepth = entry.key;
                }
              }
              // If no iteration completed (very short search), fall back to the
              // deepest partial one so a result is still returned.
              bestDepth ??=
                  linesByDepth.keys.isEmpty
                      ? null
                      : linesByDepth.keys.reduce((a, b) => a > b ? a : b);

              final committedLines =
                  bestDepth == null
                      ? lines
                      : (linesByDepth[bestDepth]!.entries.toList()
                            ..sort((a, b) => a.key.compareTo(b.key)))
                          .map((e) => e.value)
                          .toList();

              completer.complete(
                AnalysisResult(
                  evaluation:
                      bestDepth == null
                          ? (mainEvaluation ?? 0)
                          : (evalByDepth[bestDepth] ?? mainEvaluation ?? 0),
                  mateIn: bestDepth == null ? mateIn : mateByDepth[bestDepth],
                  lines: committedLines,
                  depth: bestDepth ?? depth,
                ),
              );
            }
          }
        });

        // Ensure engine is at max strength for analysis (after stop, before position).
        // Already inside the serialized execution slot, so send directly via
        // the command queue: calling setMaxStrength() here would enqueue a new
        // execution-queue task that cannot run until THIS search completes,
        // applying the option after the search instead of before it.
        if (!_useFallback) {
          _sendCommand('setoption name UCI_LimitStrength value false');
        }

        // Set position and analyze
        _sendCommand(
          buildPositionCommand(
            fen: fen,
            startingFen: startingFen,
            moves: moves,
          ),
        );

        // Wait for engine to confirm position is processed before starting search
        final positionReady = await _waitForReadyOk(
          timeout: const Duration(milliseconds: 500),
        );
        if (!positionReady) {
          debugPrint(
            'Position ready timeout for analysis FEN: $fen. Using fallback.',
          );
          return await BasicEvaluatorService.instance.analyze(fen);
        }
        if (_isSearchCancelled(searchId)) {
          return _cancelledAnalysisResult();
        }

        goSent = true;
        _searchInFlight = true;
        // Node-bounded search caps total work regardless of device speed.
        // (Reproducibility comes from the completed-iteration capture in the
        // bestmove handler, not from the search bound itself.)
        _sendCommand(nodes != null ? 'go nodes $nodes' : 'go depth $depth');
        final searchStarted = DateTime.now();
        final analysisBudget = _effectiveAnalysisTimeout(
          depth: depth,
          multiPv: multiPv,
          nodes: nodes,
        );

        final searchResult = await completer.future.timeout(
          analysisBudget,
          onTimeout: () async {
            debugPrint(
              'ENGINE RECOVERY → Analysis timeout after ${analysisBudget.inMilliseconds}ms '
              'for FEN: $fen, using fallback',
            );
            _sendCommand('stop');
            await _stopCurrentSearchAndWait();
            _sendCommand('setoption name MultiPV value 1');
            if (_isSearchCancelled(searchId)) {
              return _cancelledAnalysisResult();
            }
            return BasicEvaluatorService.instance.analyze(fen);
          },
        );

        // Overhead accounting: how much of this call was actual searching versus
        // the surrounding stop/position/isready/MultiPV round trips.
        final searchMs =
            DateTime.now().difference(searchStarted).inMilliseconds;
        final totalMs = DateTime.now().difference(callStarted).inMilliseconds;
        debugPrint(
          '⏱️ SEARCH totalMs=$totalMs searchMs=$searchMs '
          'overheadMs=${totalMs - searchMs}',
        );

        return searchResult;
      } finally {
        await subscription?.cancel();
        if (_searchInFlight) {
          await _stopCurrentSearchAndWait();
        }
        _isEngineBusy = false;
      }
    });
  }

  /// Set the engine skill level (affects playing strength).
  /// Uses Stockfish's UCI_Elo with UCI_LimitStrength=true for strength control.
  /// Do NOT set Skill Level simultaneously — Stockfish ignores it when UCI_LimitStrength is active.
  ///
  /// Returns a Future that completes when the options have been handed to the
  /// command queue. Await it whenever ordering vs. a subsequent search matters
  /// (new game, batch setup, difficulty change) — otherwise a later `go` could
  /// be delivered before the options on slow devices.
  Future<void> setSkillLevel(int elo) {
    if (_isDisposed || _useFallback) return Future.value();

    final clampedElo = elo.clamp(1320, 3190);
    return _executionQueue.run(() async {
      if (_isDisposed || _useFallback) return;
      _sendCommand('setoption name UCI_LimitStrength value true');
      _sendCommand('setoption name UCI_Elo value $clampedElo');
      debugPrint('ENGINE CONFIG: UCI_Elo=$clampedElo (requested=$elo)');
    });
  }

  /// Set the engine to maximum strength.
  /// See [setSkillLevel] for why this returns an awaitable Future.
  Future<void> setMaxStrength() {
    if (_isDisposed || _useFallback) return Future.value();
    return _executionQueue.run(() async {
      if (_isDisposed || _useFallback) return;
      _sendCommand('setoption name UCI_LimitStrength value false');
    });
  }

  /// Threads/Hash used for live play. Chosen for stability and low memory
  /// pressure on the widest range of devices; see initialize().
  static const int livePlayThreads = 1;
  static const int livePlayHashMb = 16;

  /// Upper bound on threads for batch analysis.
  ///
  /// Deliberately pinned to 1. Multi-threaded Stockfish (Lazy SMP) is
  /// non-deterministic: helper threads race to fill the shared transposition
  /// table, so the same position at the same depth can return a different
  /// score between runs. Post-game review must be reproducible — a user
  /// re-opening the same game has to see the same classifications — and a
  /// measured Threads=3 run shifted evaluations enough to change per-move
  /// labels (blunders 0 -> 2) on an identical game.
  ///
  /// Hash is still raised, which is a pure win: a larger table cannot change
  /// the result of a deterministic single-threaded search, it only avoids
  /// re-searching positions already visited.
  static const int maxAnalysisThreads = 1;
  static const int analysisHashMb = 64;

  /// Threads to use for batch analysis. See [maxAnalysisThreads] for why this
  /// defaults to 1 regardless of how many cores the device has.
  int get _analysisThreads => maxAnalysisThreads;

  /// Raise Threads/Hash for a full-game batch analysis pass.
  /// Must be paired with [setLivePlayStrength] when the pass finishes or is
  /// cancelled, so live play returns to its low-footprint configuration.
  /// Returns an awaitable Future — see [setSkillLevel].
  ///
  /// [threadsOverride] raises the thread count above the reproducibility-safe
  /// default. Only safe when the completed analysis is persisted and replayed
  /// from storage, so a user never re-runs the same game and sees different
  /// numbers. Used by the config sweep harness for measurement.
  Future<void> setAnalysisStrength({
    int? threadsOverride,
    int? hashMbOverride,
  }) {
    if (_isDisposed || _useFallback) return Future.value();
    return _executionQueue.run(() async {
      if (_isDisposed || _useFallback) return;
      final threads = threadsOverride ?? _analysisThreads;
      final hash = hashMbOverride ?? analysisHashMb;
      _sendCommand('setoption name Threads value $threads');
      _sendCommand('setoption name Hash value $hash');
      debugPrint(
        'ENGINE CONFIG: batch analysis Threads=$threads Hash=${hash}MB '
        '(cores=${Platform.numberOfProcessors})',
      );
    });
  }

  /// Restore the live-play Threads/Hash configuration.
  /// Returns an awaitable Future — see [setSkillLevel].
  Future<void> setLivePlayStrength() {
    if (_isDisposed || _useFallback) return Future.value();
    return _executionQueue.run(() async {
      if (_isDisposed || _useFallback) return;
      _sendCommand('setoption name Threads value $livePlayThreads');
      _sendCommand('setoption name Hash value $livePlayHashMb');
      debugPrint(
        'ENGINE CONFIG: live play Threads=$livePlayThreads '
        'Hash=${livePlayHashMb}MB',
      );
    });
  }

  /// Stop any ongoing analysis.
  ///
  /// Stays synchronous (safe to call from dispose/lifecycle callbacks): it
  /// invalidates the active search id FIRST so an in-flight search completes
  /// with a partial result on the next engine line instead of hanging on its
  /// full timeout while holding the execution-queue slot, then asks the
  /// engine to stop.
  ///
  /// The stop/isready pair is written directly to the isolate (bypassing the
  /// serialized command queue) so a lifecycle pause interrupts the native
  /// search immediately. It is intentionally NOT also enqueued: the
  /// duplicate pair used to race the direct write and deliver `stop` to the
  /// next search's `go`.
  void stopAnalysis() {
    if (_isDisposed) return;
    _activeSearchId++;
    if (_useFallback) return;
    try {
      _engineCommandPort?.send({'type': 'stdin', 'command': 'stop'});
      _engineCommandPort?.send({'type': 'stdin', 'command': 'isready'});
    } catch (_) {}
  }

  /// Stop current search and wait for it to finish (for intentional search replacement).
  /// Guarantees that Stockfish worker threads are no longer searching before continuing.
  /// A stop is only considered complete once the engine has emitted `bestmove`
  /// for the in-flight search AND a readyok that arrived after the isready sent
  /// below. If the engine fails to acknowledge within 3.0 seconds, the isolate
  /// is killed and cleanly restarted to prevent sending commands to an active
  /// C++ search thread (which causes SIGSEGV).
  Future<void> _stopCurrentSearchAndWait() async {
    if (_skipReadyOkForTesting) {
      _searchInFlight = false;
      return;
    }

    final searchWasInFlight = _searchInFlight;
    if (!searchWasInFlight && !_isEngineBusy) return;

    // Only a readyok produced after this isready may release the wait, and
    // only once the in-flight search has actually reported bestmove.
    final targetResponseCount = _readyokCount + 1;
    var sawBestmove = !searchWasInFlight;
    final completer = Completer<void>();

    final subscription = _outputController.stream.listen((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('bestmove')) {
        sawBestmove = true;
        _searchInFlight = false;
      }
      if (trimmed == 'readyok' &&
          _readyokCount >= targetResponseCount &&
          sawBestmove &&
          !completer.isCompleted) {
        completer.complete();
      }
    });

    _sendCommand('stop');
    _sendCommand('isready');

    try {
      await completer.future.timeout(const Duration(milliseconds: 3000));
    } catch (_) {
      debugPrint('ENGINE RECOVERY → Engine stalled on stop; disabling engine');
      await _killEngineIfRunning();
      _enableFallback('Engine did not acknowledge stop');
    } finally {
      await subscription.cancel();
      _searchInFlight = false;
    }
  }

  /// Start a new game.
  /// Returns an awaitable Future — see [setSkillLevel].
  Future<void> newGame() {
    if (_isDisposed || _useFallback) return Future.value();
    return _executionQueue.run(() async {
      if (_isDisposed || _useFallback) return;
      // Stop any in-flight search and await its bestmove before resetting the
      // position, so `ucinewgame` is never delivered to an active C++ search
      // thread (a SIGSEGV trigger in Position::is_draw / search<NonPV>).
      if (_searchInFlight) await _stopCurrentSearchAndWait();
      if (_isDisposed || _useFallback) return;
      _sendCommand('ucinewgame');
    });
  }

  /// Dispose the engine, killing the isolate and freeing resources.
  /// The service can be re-initialized later via initialize().
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    if (_isDisposed) return Future.value();

    _isDisposed = true;
    debugPrint('ENGINE LIFECYCLE → Disposing engine');

    final future = () async {
      await _killEngineIfRunning();
      _commandQueue.clear();
      _executionQueue.clear();
      await _outputController.close();
      _outputController = StreamController<String>.broadcast();

      _initCompleter?.complete();
      _initCompleter = null;
      _engineReadyCompleter?.complete();
      _engineReadyCompleter = null;

      statusNotifier.value = EngineStatus.disposed;
    }();
    _disposeFuture = future;
    return future;
  }

  /// Wait until it is safe to spawn a new native engine after the previous
  /// one was shut down. A clean shutdown (native UCI loop actually exited)
  /// only needs a short settling delay; an unacknowledged shutdown waits
  /// longer so a still-running `stockfish_main()` cannot overlap the new one.
  Future<void> _awaitEngineRestartCooldown() async {
    final lastShutdown = _lastEngineShutdownTime;
    if (lastShutdown == null) return;
    final cooldown =
        _lastEngineShutdownWasClean
            ? _engineRestartCooldown
            : _uncleanEngineRestartCooldown;
    final elapsed = DateTime.now().difference(lastShutdown);
    if (elapsed < cooldown) {
      await Future<void>.delayed(cooldown - elapsed);
    }
  }

  Future<void> _startEngineIsolate() async {
    if (_isDisposed) throw Exception('Cannot start engine after dispose');
    if (_engineIsolate != null) return;

    await _awaitEngineRestartCooldown();
    if (_isDisposed) throw Exception('Cannot start engine after dispose');

    _engineSessionId++;
    final sessionId = _engineSessionId;

    final responsePort = ReceivePort();
    late final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _stockfishIsolateEntryPoint,
        responsePort.sendPort,
      );
    } catch (_) {
      responsePort.close();
      rethrow;
    }

    if (_isDisposed || _engineSessionId != sessionId) {
      isolate.kill(priority: Isolate.beforeNextEvent);
      responsePort.close();
      return;
    }

    _engineResponsePort = responsePort;
    _engineIsolate = isolate;

    // Track consecutive isolate crashes for circuit breaker
    _consecutiveCrashes++;

    // Set up a death and exit detection port
    final deathPort = ReceivePort();
    isolate.addErrorListener(deathPort.sendPort);
    deathPort.listen((message) {
      if (_engineSessionId != sessionId) {
        deathPort.close();
        return;
      }
      debugPrint('ENGINE CRASH: Isolate died with error: $message');
      _isReady = false;
      _isEngineBusy = false;
      _engineCommandPort = null;
      _engineIsolate = null;
      _lastEngineShutdownTime = DateTime.now();
      _lastEngineShutdownWasClean = false;
      _enableFallback('Isolate error: $message');
      deathPort.close();
    });

    final exitPort = ReceivePort();
    isolate.addOnExitListener(exitPort.sendPort);
    exitPort.listen((_) {
      if (!_isDisposed && _engineSessionId == sessionId && !_useFallback) {
        debugPrint('ENGINE CRASH: Isolate exited unexpectedly');
        _isReady = false;
        _isEngineBusy = false;
        _engineCommandPort = null;
        _engineIsolate = null;
        _lastEngineShutdownTime = DateTime.now();
        _lastEngineShutdownWasClean = false;
        _enableFallback('Isolate exited unexpectedly');
      }
      exitPort.close();
    });

    // Listen for the command port and stdout from the isolate
    final completer = Completer<void>();
    _engineResponseSubscription = _engineResponsePort!.listen((message) {
      // Ignore stale messages from previous sessions
      if (_engineSessionId != sessionId) return;

      if (message is SendPort) {
        _engineCommandPort = message;
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (message is Map<String, dynamic>) {
        final type = message['type'] as String;
        if (type == 'stdout') {
          final line = message['line'] as String;
          _handleEngineStdoutLine(line);
        } else if (type == 'engine_ready') {
          // Engine isolate reports the binary loaded and is accepting commands
          _engineReadyCompleter?.complete();
          _engineReadyCompleter = null;
        } else if (type == 'disposed') {
          _isolateDisposeWasClean = message['clean'] as bool? ?? false;
          _isolateDisposedCompleter?.complete();
          _isolateDisposedCompleter = null;
        } else if (type == 'error') {
          // Error reported from the engine isolate
          final msg = message['message'] as String? ?? 'Unknown error';
          debugPrint('ENGINE INIT: Isolate error: $msg');
          if (msg.contains('StockfishState.error') ||
              msg.contains('constructor failed') ||
              msg.contains('Engine reached')) {
            _enableFallback('Engine isolate reported error: $msg');
          }
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

  /// Kill the engine isolate if it exists. Does NOT enable fallback or dispose.
  /// Safe to call multiple times. Idempotent.
  Future<void> _killEngineIfRunning() async {
    if (_engineIsolate == null && _engineCommandPort == null) return;
    debugPrint('ENGINE LIFECYCLE → Killing engine isolate');
    _commandQueue.clear();
    _isolateDisposeWasClean = false;

    var cleanShutdown = false;
    final commandPort = _engineCommandPort;
    if (commandPort != null) {
      _isolateDisposedCompleter = Completer<void>();
      try {
        // The isolate's dispose handler sends "quit" to the native UCI loop
        // and waits for stockfish_main() to return before acknowledging. A
        // clean ack therefore guarantees the process-wide fakein/fakeout
        // queues are closed and safe to reopen by the next engine instance.
        commandPort.send({'type': 'dispose'});
        cleanShutdown = await _isolateDisposedCompleter!.future
            .then((_) => true)
            .timeout(
              const Duration(milliseconds: 3000),
              onTimeout: () => false,
            );
        cleanShutdown = cleanShutdown && _isolateDisposeWasClean;
      } catch (_) {}
      _isolateDisposedCompleter = null;
    }

    _engineSessionId++;
    await _engineResponseSubscription?.cancel();
    _engineResponseSubscription = null;

    try {
      _engineIsolate?.kill(priority: Isolate.beforeNextEvent);
    } catch (_) {}
    _engineIsolate = null;
    _engineCommandPort = null;
    _engineResponsePort?.close();
    _engineResponsePort = null;
    _isReady = false;
    _isEngineBusy = false;
    _searchInFlight = false;

    _lastEngineShutdownTime = DateTime.now();
    _lastEngineShutdownWasClean = cleanShutdown;

    _engineReadyCompleter?.complete();
    _engineReadyCompleter = null;
  }
}

/// Entry point for the Stockfish engine isolate
void _stockfishIsolateEntryPoint(SendPort sendPort) {
  final commandPort = ReceivePort();
  sendPort.send(commandPort.sendPort);

  Stockfish? stockfish;
  // Commands are processed strictly in order. In particular, an `init` must
  // not construct a new native engine while a previous one is still shutting
  // down, and a `dispose` ack must be sent only after the native UCI loop has
  // actually exited.
  var pending = Future<void>.value();

  Future<void> handleCommand(Map<String, dynamic> message) async {
    final type = message['type'] as String;

    switch (type) {
      case 'init':
        final previous = stockfish;
        stockfish = null;
        if (previous != null) {
          await _disposeStockfishSafely(previous);
        }
        try {
          final engine = Stockfish();
          stockfish = engine;
          engine.stdout.listen((line) {
            sendPort.send({'type': 'stdout', 'line': line});
          });

          // Signal readiness only once the engine actually reaches the
          // ready state. Announcing right after the constructor meant the
          // main thread sent "uci" while the engine was still starting;
          // the write was rejected with "Bad state: Stockfish is not
          // ready", and initialize() then waited the full 5s for a uciok
          // that could never arrive — every attempt failed and the service
          // latched to the fallback evaluator on cold start.
          if (engine.state.value == StockfishState.ready) {
            sendPort.send({'type': 'engine_ready'});
          } else {
            late final VoidCallback listener;
            listener = () {
              final st = engine.state.value;
              if (st == StockfishState.ready) {
                engine.state.removeListener(listener);
                sendPort.send({'type': 'engine_ready'});
              } else if (st == StockfishState.error ||
                  st == StockfishState.disposed) {
                engine.state.removeListener(listener);
                sendPort.send({
                  'type': 'error',
                  'message': 'Engine reached $st before becoming ready',
                });
              }
            };
            engine.state.addListener(listener);
          }
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
        final engine = stockfish;
        stockfish = null;
        var clean = false;
        try {
          if (engine != null) {
            clean = await _disposeStockfishSafely(engine);
          }
        } catch (_) {
          clean = false;
        } finally {
          try {
            sendPort.send({'type': 'disposed', 'clean': clean});
          } catch (_) {}
        }
        break;
    }
  }

  commandPort.listen((message) {
    if (message is! Map<String, dynamic>) return;
    pending = pending.then((_) => handleCommand(message)).catchError((
      Object error,
      StackTrace _,
    ) {
      try {
        sendPort.send({
          'type': 'error',
          'message': 'Isolate command failed: $error',
        });
      } catch (_) {}
    });
  });
}

/// Ask the native UCI loop to exit and wait for `stockfish_main()` to return.
///
/// The plugin's own `dispose()` writes `quit` and immediately closes its
/// ports without waiting. The process-global `fakein`/`fakeout` queues are
/// only reopened/closed by `stockfish_main()` itself, so constructing the next
/// engine while the previous loop is still winding down can interleave both
/// engines on the same queues. Waiting for the plugin's state to become
/// `disposed` is the only externally observable confirmation that the native
/// loop returned (the plugin marks it from its main-port exit message).
///
/// Returns true when the native loop was observed exiting cleanly.
Future<bool> _disposeStockfishSafely(Stockfish stockfish) async {
  var nativeExited = stockfish.state.value == StockfishState.disposed;

  if (stockfish.state.value == StockfishState.ready) {
    try {
      // The plugin's stdin setter appends the trailing newline.
      stockfish.stdin = 'quit';
    } catch (_) {}

    if (stockfish.state.value != StockfishState.disposed) {
      final completer = Completer<void>();
      void onStateChanged() {
        if (stockfish.state.value == StockfishState.disposed &&
            !completer.isCompleted) {
          completer.complete();
        }
      }

      stockfish.state.addListener(onStateChanged);
      try {
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint(
              'ENGINE LIFECYCLE → Native quit ack timed out; forcing dispose',
            );
          },
        );
      } catch (_) {
        // dispose() below still tears down the Dart-side wrapper.
      } finally {
        stockfish.state.removeListener(onStateChanged);
      }
      nativeExited = stockfish.state.value == StockfishState.disposed;
    }
  }

  try {
    stockfish.dispose();
  } catch (_) {}
  return nativeExited;
}
