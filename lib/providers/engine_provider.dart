import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Provider for the Stockfish engine service
final stockfishServiceProvider = Provider<StockfishService>((ref) {
  return StockfishService.instance;
});

/// Provider for engine initialization state
final engineInitializedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(stockfishServiceProvider);
  await service.initialize();
  return service.isReady;
});

/// State for engine analysis
class EngineState {
  final bool isAnalyzing;
  final bool isThinking;
  final String? bestMove;
  final int? evaluation;
  final int? mateIn;
  final List<EngineLine> lines;
  final int depth;
  final String? currentFen;

  const EngineState({
    this.isAnalyzing = false,
    this.isThinking = false,
    this.bestMove,
    this.evaluation,
    this.mateIn,
    this.lines = const [],
    this.depth = 0,
    this.currentFen,
  });

  EngineState copyWith({
    bool? isAnalyzing,
    bool? isThinking,
    String? bestMove,
    int? evaluation,
    int? mateIn,
    List<EngineLine>? lines,
    int? depth,
    String? currentFen,
    bool clearBestMove = false,
    bool clearEvaluation = false,
  }) {
    return EngineState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isThinking: isThinking ?? this.isThinking,
      bestMove: clearBestMove ? null : (bestMove ?? this.bestMove),
      evaluation: clearEvaluation ? null : (evaluation ?? this.evaluation),
      mateIn: clearEvaluation ? null : (mateIn ?? this.mateIn),
      lines: lines ?? this.lines,
      depth: depth ?? this.depth,
      currentFen: currentFen ?? this.currentFen,
    );
  }

  /// Get evaluation in pawns
  double get evalInPawns => (evaluation ?? 0) / 100.0;

  /// Get formatted evaluation string
  String get formattedEval {
    if (mateIn != null) {
      return mateIn! > 0 ? 'M$mateIn' : '-M${mateIn!.abs()}';
    }
    if (evaluation == null) return '0.0';
    final sign = evaluation! >= 0 ? '+' : '';
    return '$sign${evalInPawns.toStringAsFixed(1)}';
  }
}

/// Notifier for engine operations
class EngineNotifier extends StateNotifier<EngineState> {
  final StockfishService _service;
  Timer? _thinkingTimer;
  int _searchId = 0;

  EngineNotifier(this._service) : super(const EngineState());

  /// Initialize the engine
  Future<void> initialize() async {
    try {
      await _service.initialize();
    } catch (e) {
      // Engine initialization failed - continue without engine
      debugPrint('Engine initialization failed: $e');
    }
  }

  /// Get best move for bot to play
  Future<BestMoveResult?> getBotMove({
    required String fen,
    required DifficultyLevel difficulty,
    BotType botType = BotType.stockfish, // Added param to match usage
  }) async {
    // Increment search ID to invalidate previous requests
    _searchId++;
    final currentSearchId = _searchId;

    state = state.copyWith(isThinking: true, currentFen: fen);

    try {
      // Initialize if not ready
      if (!_service.isReady) {
        try {
          await _service.initialize();
        } catch (e) {
          debugPrint('Stockfish init failed: $e. Using lightweight engine.');
        }
      }

      // Check for race condition before heavy operation
      if (currentSearchId != _searchId) return null;

      // If Stockfish failed to init or is not ready, use fallback
      if (!_service.isReady) {
        final fallbackResult = await SimpleBotService.instance.getBestMove(
          fen: fen,
          depth: difficulty.depth,
        );

        if (currentSearchId != _searchId) return null;

        state = state.copyWith(
          isThinking: false,
          bestMove: fallbackResult.bestMove,
          evaluation: fallbackResult.evaluation,
        );
        return BestMoveResult(
          bestMove: fallbackResult.bestMove,
          evaluation: fallbackResult.evaluation,
        );
      }

      // Set engine strength
      _service.setSkillLevel(difficulty.elo);

      // Add artificial delay for more human-like feel
      final minDelay = Duration(milliseconds: difficulty.thinkTimeMs ~/ 2);
      final startTime = DateTime.now();

      final result = await _service
          .getBestMove(
            fen: fen,
            depth: difficulty.depth,
            thinkTimeMs: difficulty.thinkTimeMs,
          )
          .timeout(
            Duration(milliseconds: difficulty.thinkTimeMs + 2000),
            onTimeout: () {
              throw TimeoutException('Engine timed out');
            },
          );

      if (currentSearchId != _searchId) return null;

      // Ensure minimum thinking time for realism
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minDelay) {
        await Future.delayed(minDelay - elapsed);
      }

      if (currentSearchId != _searchId) return null;

      state = state.copyWith(
        isThinking: false,
        bestMove: result.bestMove,
        evaluation: result.evaluation,
        mateIn: result.mateIn,
      );

      return result;
    } catch (e) {
      if (currentSearchId != _searchId) return null;

      debugPrint('Error with Stockfish: $e. Switching to lightweight engine.');

      try {
        final fallbackResult = await SimpleBotService.instance.getBestMove(
          fen: fen,
          depth: difficulty.depth,
        );

        if (currentSearchId != _searchId) return null;

        state = state.copyWith(
          isThinking: false,
          bestMove: fallbackResult.bestMove,
          evaluation: fallbackResult.evaluation,
        );
        return BestMoveResult(
          bestMove: fallbackResult.bestMove,
          evaluation: fallbackResult.evaluation,
        );
      } catch (fallbackError) {
        debugPrint('Fallback engine also failed: $fallbackError');
        state = state.copyWith(isThinking: false);
        return null;
      }
    }
  }

  /// Get a hint for the player
  Future<BestMoveResult?> getHint({required String fen, int depth = 15}) async {
    _searchId++;
    final currentSearchId = _searchId;

    state = state.copyWith(isThinking: true);

    try {
      if (!_service.isReady) {
        try {
          await _service.initialize();
        } catch (e) {
          debugPrint('Stockfish init failed for hint: $e');
        }
      }

      if (currentSearchId != _searchId) return null;

      if (_service.isReady) {
        final result = await _service.getBestMove(fen: fen, depth: depth);

        if (currentSearchId != _searchId) return null;

        state = state.copyWith(isThinking: false, bestMove: result.bestMove);
        return result;
      } else {
        throw Exception('Stockfish not ready');
      }
    } catch (e) {
      if (currentSearchId != _searchId) return null;

      debugPrint('Error getting hint from Stockfish: $e. Using fallback.');
      try {
        final result = await SimpleBotService.instance.getBestMove(
          fen: fen,
          depth: depth,
        );

        if (currentSearchId != _searchId) return null;

        state = state.copyWith(isThinking: false, bestMove: result.bestMove);
        return BestMoveResult(
          bestMove: result.bestMove,
          evaluation: result.evaluation,
        );
      } catch (fallbackError) {
        state = state.copyWith(isThinking: false);
        return null;
      }
    }
  }

  /// Start continuous analysis of a position
  Future<void> analyzePosition({
    required String fen,
    int depth = AppConstants.analysisDepth,
    int multiPv = AppConstants.topEngineLinesCount,
  }) async {
    // Stop any existing analysis
    stopAnalysis();

    _searchId++;
    final currentSearchId = _searchId;

    state = state.copyWith(
      isAnalyzing: true,
      currentFen: fen,
      clearBestMove: true,
      clearEvaluation: true,
    );

    try {
      if (!_service.isReady) {
        try {
          await _service.initialize();
        } catch (e) {
          debugPrint('Stockfish init failed for analysis: $e');
          state = state.copyWith(isAnalyzing: false);
          return;
        }
      }

      if (currentSearchId != _searchId) return;

      final result = await _service.analyzePosition(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
      );

      if (currentSearchId != _searchId) return;

      state = state.copyWith(
        isAnalyzing: false,
        evaluation: result.evaluation,
        mateIn: result.mateIn,
        lines: result.lines,
        depth: result.depth,
      );
    } catch (e) {
      if (currentSearchId != _searchId) return;

      state = state.copyWith(isAnalyzing: false);
      debugPrint('Error analyzing position: $e');
    }
  }

  /// Stop ongoing analysis
  void stopAnalysis() {
    _searchId++; // Invalidate pending searches
    _service.stopAnalysis();
    _thinkingTimer?.cancel();
    state = state.copyWith(isAnalyzing: false, isThinking: false);
  }

  /// Reset for new game
  void resetForNewGame() {
    stopAnalysis();
    _service.newGame();
    state = const EngineState();
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _searchId++;
    super.dispose();
  }
}

/// Provider for engine state and operations
final engineProvider = StateNotifierProvider<EngineNotifier, EngineState>((
  ref,
) {
  final service = ref.watch(stockfishServiceProvider);
  return EngineNotifier(service);
});

/// Provider for getting a hint
final hintProvider = FutureProvider.family<BestMoveResult?, String>((
  ref,
  fen,
) async {
  final engineNotifier = ref.read(engineProvider.notifier);
  return engineNotifier.getHint(fen: fen);
});
