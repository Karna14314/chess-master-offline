import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
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
  StreamSubscription<AnalysisInfo>? _infoSubscription;

  EngineNotifier(this._service) : super(const EngineState()) {
    _infoSubscription = _service.infoStream.listen(_onInfoUpdate);
  }

  void _onInfoUpdate(AnalysisInfo info) {
    if (!state.isThinking && !state.isAnalyzing) return;

    if (state.isThinking) {
      if (info.multiPv == 1) {
        state = state.copyWith(
          depth: info.depth,
          evaluation: info.evaluation,
          mateIn: info.mateIn,
        );
      }
    } else if (state.isAnalyzing) {
      List<EngineLine> newLines = List.from(state.lines);
      // Ensure size
      while (newLines.length < info.multiPv) {
        newLines.add(EngineLine(moves: [], depth: 0));
      }

      newLines[info.multiPv - 1] = EngineLine(
        moves: info.pv,
        evaluation: info.evaluation,
        mateIn: info.mateIn,
        depth: info.depth,
      );

      state = state.copyWith(
        lines: newLines,
        depth: info.depth,
        // If multiPv=1, update main eval
        evaluation: info.multiPv == 1 ? info.evaluation : state.evaluation,
        mateIn: info.multiPv == 1 ? info.mateIn : state.mateIn,
      );
    }
  }

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
  }) async {
    state = state.copyWith(isThinking: true);

    // Initialize if not ready
    if (!_service.isReady) {
      await _service.initialize();
      if (!_service.isReady) {
        state = state.copyWith(isThinking: false);
        debugPrint('Engine not ready, skipping move search');
        return null;
      }
    }

    // Set engine strength
    _service.setSkillLevel(difficulty.elo);

    try {
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
              debugPrint('Engine timed out');
              // Return a dummy result or throw exception
              throw TimeoutException('Engine timed out');
            },
          );

      // Ensure minimum thinking time for realism
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minDelay) {
        await Future.delayed(minDelay - elapsed);
      }

      state = state.copyWith(
        isThinking: false,
        bestMove: result.bestMove,
        evaluation: result.evaluation,
        mateIn: result.mateIn,
      );

      return result;
    } catch (e) {
      state = state.copyWith(isThinking: false);
      print('Error getting bot move: $e');
      return null;
    }
  }

  /// Get a hint for the player
  Future<BestMoveResult?> getHint({required String fen, int depth = 15}) async {
    state = state.copyWith(isThinking: true);

    try {
      final result = await _service.getBestMove(fen: fen, depth: depth);

      state = state.copyWith(isThinking: false, bestMove: result.bestMove);

      return result;
    } catch (e) {
      state = state.copyWith(isThinking: false);
      print('Error getting hint: $e');
      return null;
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

    state = state.copyWith(
      isAnalyzing: true,
      currentFen: fen,
      clearBestMove: true,
      clearEvaluation: true,
      lines: [], // Clear old lines
    );

    try {
      final result = await _service.analyzePosition(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
      );

      state = state.copyWith(
        isAnalyzing: false,
        evaluation: result.evaluation,
        mateIn: result.mateIn,
        lines: result.lines,
        depth: result.depth,
      );
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      print('Error analyzing position: $e');
    }
  }

  /// Stop ongoing analysis
  void stopAnalysis() {
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
    _infoSubscription?.cancel();
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
