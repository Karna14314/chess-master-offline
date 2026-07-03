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
  int _searchId = 0;
  DifficultyLevel? _currentDifficulty;

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
          depth: difficulty.fallbackDepth,
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

      // Ensure the engine is using the correct skill level for this specific move.
      // This protects against the strength being left at max by a prior analysis run.
      _service.setSkillLevel(difficulty.elo);

      // Minimum think time: a fixed floor (not additive) to prevent
      // instant replies that feel robotic. If the engine finishes faster
      // than this threshold, we wait the remaining time. If it finishes
      // later, we move immediately — no additional delay is added.
      const minThinkTime = Duration(milliseconds: 300);
      final searchStartTime = DateTime.now();

      final result = await _service
          .getBestMove(
            fen: fen,
            depth: difficulty.depth,
            multiPv: difficulty.multiPv,
            evalThresholdCp: difficulty.evalThresholdCp,
            difficultyLevel: difficulty.level,
            thinkTimeMs: difficulty.thinkTimeMs,
          )
          .timeout(
            Duration(milliseconds: difficulty.thinkTimeMs * 2 + 2000),
            onTimeout: () {
              throw TimeoutException('Engine timed out');
            },
          );

      if (currentSearchId != _searchId) return null;

      // Apply minimum think time floor (not additive — only waits if
      // the search completed faster than the minimum threshold).
      final elapsed = DateTime.now().difference(searchStartTime);
      if (elapsed < minThinkTime) {
        await Future.delayed(minThinkTime - elapsed);
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
          depth: difficulty.fallbackDepth,
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
  Future<HintResult?> getHint({required String fen, int depth = 15}) async {
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
        _service.setMaxStrength();
        try {
          final result = await _service.analyzePosition(
            fen: fen,
            depth: depth,
            multiPv: 2,
          );

          if (currentSearchId != _searchId) return null;

          if (result.lines.isEmpty) return null;

          final mainLine = result.lines[0];
          final bestMove = mainLine.moves.isNotEmpty ? mainLine.moves[0] : '';

          String? alternativeMove;
          if (result.lines.length > 1 && result.lines[1].moves.isNotEmpty) {
            alternativeMove = result.lines[1].moves[0];
          }

          final bestMoveResult = BestMoveResult(
            bestMove: bestMove,
            evaluation: (mainLine.evaluation * 100).round(),
            mateIn: mainLine.mateIn,
          );

          state = state.copyWith(isThinking: false, bestMove: bestMove);

          String explanation = "This is the strongest move in the position.";
          String? motif;

          if (mainLine.isMate) {
            explanation = "Forces checkmate.";
            motif = "Mating threat";
          } else if (mainLine.evaluation > 2.0) {
            explanation = "Capitalizes on a significant advantage.";
          } else if (mainLine.evaluation < -2.0) {
            explanation = "Best defensive resource in a difficult position.";
          } else {
            explanation = "Maintains a balanced position.";
          }

          return HintResult(
            mainResult: bestMoveResult,
            alternativeMove: alternativeMove,
            explanation: explanation,
            tacticalMotif: motif,
            principalVariation: mainLine.moves,
          );
        } finally {
          if (_currentDifficulty != null) {
            _service.setSkillLevel(_currentDifficulty!.elo);
          }
        }
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

        return HintResult(
          mainResult: BestMoveResult(
            bestMove: result.bestMove,
            evaluation: result.evaluation,
          ),
          explanation: "Fallback engine suggestion.",
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
    } finally {
      // Always restore the engine to the current difficulty's skill level
      // so we don't accidentally leave it at max strength for the next bot move.
      if (_currentDifficulty != null) {
        _service.setSkillLevel(_currentDifficulty!.elo);
      }
    }
  }

  /// Analyze a full game move-by-move for accuracy calculation
  Future<List<int?>> analyzeGame(List<String> fens, {int depth = 12}) async {
    List<int?> evaluations = [];
    _service.setMaxStrength();

    for (final fen in fens) {
      if (!_service.isReady) break;
      final result = await _service.getBestMove(fen: fen, depth: depth);
      evaluations.add(result.evaluation);
    }

    return evaluations;
  }

  /// Stop ongoing analysis
  void stopAnalysis() {
    _searchId++; // Invalidate pending searches
    _service.stopAnalysis();
    state = state.copyWith(isAnalyzing: false, isThinking: false);
  }

  /// Reset for new game. If [difficulty] is provided, configure the engine's
  /// strength for that difficulty level once (not on every move).
  void resetForNewGame({DifficultyLevel? difficulty}) {
    stopAnalysis();
    _currentDifficulty = difficulty;
    if (difficulty != null) {
      _service.setSkillLevel(difficulty.elo);
    }
    _service.newGame();
    state = const EngineState();
  }

  @override
  void dispose() {
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
final hintProvider = FutureProvider.family<HintResult?, String>((
  ref,
  fen,
) async {
  final engineNotifier = ref.read(engineProvider.notifier);
  return engineNotifier.getHint(fen: fen);
});
