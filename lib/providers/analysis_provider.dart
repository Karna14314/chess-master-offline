import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/services/stockfish_service.dart' as stockfish;
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/engine_provider.dart' as package_engine_provider;

/// Provider for analysis state
final analysisProvider = StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  // Use the service from the provider (which can be overridden in tests)
  // Instead of direct singleton access
  // We use read here to avoid rebuilding notifier when service changes (it shouldn't generally)
  // But strictly speaking watch is safer for overrides.
  // However, stockfishServiceProvider is a simple Provider returning instance.
  // In tests, we override it.
  final service = ref.watch(package_engine_provider.stockfishServiceProvider);
  return AnalysisNotifier(service);
});

/// Analysis state
class AnalysisState {
  final bool isAnalyzing;
  final int currentMoveIndex;
  final List<MoveAnalysis> analyzedMoves;
  final GameAnalysis? fullAnalysis;
  final chess.Chess? board;
  final List<ChessMove> originalMoves;
  final String? selectedSquare;
  final List<String> legalMoves;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final double currentEval;
  final List<EngineLine> currentEngineLines;
  final String? bestMove;
  final String? errorMessage;
  final double analysisProgress;
  final bool isLiveAnalysis;
  final String startingFen;
  final String? gameId;

  const AnalysisState({
    this.isAnalyzing = false,
    this.currentMoveIndex = -1,
    this.analyzedMoves = const [],
    this.fullAnalysis,
    this.board,
    this.originalMoves = const [],
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.currentEval = 0.0,
    this.currentEngineLines = const [],
    this.bestMove,
    this.errorMessage,
    this.analysisProgress = 0.0,
    this.isLiveAnalysis = false,
    this.startingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.gameId,
  });

  AnalysisState copyWith({
    bool? isAnalyzing,
    int? currentMoveIndex,
    List<MoveAnalysis>? analyzedMoves,
    GameAnalysis? fullAnalysis,
    chess.Chess? board,
    List<ChessMove>? originalMoves,
    String? selectedSquare,
    List<String>? legalMoves,
    String? lastMoveFrom,
    String? lastMoveTo,
    double? currentEval,
    List<EngineLine>? currentEngineLines,
    String? bestMove,
    String? errorMessage,
    double? analysisProgress,
    bool? isLiveAnalysis,
    String? startingFen,
    String? gameId,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return AnalysisState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      analyzedMoves: analyzedMoves ?? this.analyzedMoves,
      fullAnalysis: fullAnalysis ?? this.fullAnalysis,
      board: board ?? this.board,
      originalMoves: originalMoves ?? this.originalMoves,
      selectedSquare: clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? [] : (legalMoves ?? this.legalMoves),
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      currentEval: currentEval ?? this.currentEval,
      currentEngineLines: currentEngineLines ?? this.currentEngineLines,
      bestMove: bestMove ?? this.bestMove,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      analysisProgress: analysisProgress ?? this.analysisProgress,
      isLiveAnalysis: isLiveAnalysis ?? this.isLiveAnalysis,
      startingFen: startingFen ?? this.startingFen,
      gameId: gameId ?? this.gameId,
    );
  }

  /// Current FEN position
  String get fen => board?.fen ?? startingFen;

  /// Is white's turn
  bool get isWhiteTurn => board?.turn == chess.Color.WHITE;

  /// Total moves count
  int get totalMoves => originalMoves.length;

  /// Can go to previous move
  bool get canGoPrevious => currentMoveIndex >= 0;

  /// Can go to next move
  bool get canGoNext => currentMoveIndex < originalMoves.length - 1;

  /// Current move if any
  ChessMove? get currentMove {
    if (currentMoveIndex < 0 || currentMoveIndex >= originalMoves.length) return null;
    return originalMoves[currentMoveIndex];
  }

  /// Current move analysis if available
  MoveAnalysis? get currentMoveAnalysis {
    if (currentMoveIndex < 0 || currentMoveIndex >= analyzedMoves.length) return null;
    return analyzedMoves[currentMoveIndex];
  }

  /// Get piece at square
  String? getPieceAt(String square) {
    if (board == null) return null;
    final piece = board!.get(square);
    if (piece == null) return null;
    
    final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final pieceChar = piece.type.name.toUpperCase();
    return '$colorPrefix$pieceChar';
  }

  /// Get all evaluations for graphing
  List<double> get evaluations {
    if (analyzedMoves.isEmpty) return [0.0];
    List<double> evals = [analyzedMoves.first.evalBefore];
    for (final move in analyzedMoves) {
      evals.add(move.evalAfter);
    }
    return evals;
  }
}

/// Analysis notifier managing game analysis
class AnalysisNotifier extends StateNotifier<AnalysisState> {
  stockfish.StockfishService? _stockfish;
  bool _isInitialized = false;

  @visibleForTesting
  int stateUpdateCount = 0;

  AnalysisNotifier([this._stockfish]) : super(const AnalysisState());

  /// Initialize engine for analysis
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _stockfish ??= stockfish.StockfishService.instance;
      await _stockfish!.initialize();
      _isInitialized = true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to initialize analysis engine: $e',
      );
    }
  }

  /// Load a game for analysis
  Future<void> loadGame({
    required List<ChessMove> moves,
    String startingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  }) async {
    final board = chess.Chess.fromFEN(startingFen);
    
    state = state.copyWith(
      originalMoves: moves,
      board: board,
      currentMoveIndex: -1,
      analyzedMoves: [],
      fullAnalysis: null,
      startingFen: startingFen,
      currentEval: 0.0,
      currentEngineLines: [],
      bestMove: null,
      clearSelection: true,
      clearError: true,
    );

    // Start live analysis if engine is ready
    if (_isInitialized) {
      await _analyzeCurrentPosition();
    }
  }

  /// Navigate to a specific move index
  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

    // Rebuild board from start
    final board = chess.Chess.fromFEN(state.startingFen);
    
    String? lastFrom;
    String? lastTo;

    // Apply moves up to the target index
    for (int i = 0; i <= moveIndex && i < state.originalMoves.length; i++) {
      final move = state.originalMoves[i];
      board.move({'from': move.from, 'to': move.to, 'promotion': move.promotion});
      lastFrom = move.from;
      lastTo = move.to;
    }

    state = state.copyWith(
      currentMoveIndex: moveIndex,
      board: board,
      lastMoveFrom: moveIndex >= 0 ? lastFrom : null,
      lastMoveTo: moveIndex >= 0 ? lastTo : null,
      clearSelection: true,
    );

    // Analyze new position
    if (_isInitialized && state.isLiveAnalysis) {
      await _analyzeCurrentPosition();
    }
  }

  /// Go to next move
  Future<void> nextMove() async {
    if (!state.canGoNext) return;
    await goToMove(state.currentMoveIndex + 1);
  }

  /// Go to previous move
  Future<void> previousMove() async {
    if (!state.canGoPrevious) return;
    await goToMove(state.currentMoveIndex - 1);
  }

  /// Go to first move
  Future<void> firstMove() async {
    await goToMove(-1);
  }

  /// Go to last move
  Future<void> lastMove() async {
    await goToMove(state.originalMoves.length - 1);
  }

  /// Toggle live analysis
  void toggleLiveAnalysis() {
    state = state.copyWith(isLiveAnalysis: !state.isLiveAnalysis);
    if (state.isLiveAnalysis) {
      _analyzeCurrentPosition();
    }
  }

  /// Analyze current position
  Future<void> _analyzeCurrentPosition() async {
    if (_stockfish == null || !_isInitialized) return;

    try {
      final result = await _stockfish!.analyzePosition(
        fen: state.fen,
        depth: AppConstants.analysisDepth,
        multiPv: AppConstants.topEngineLinesCount,
      );

      final engineLines = result.lines.asMap().entries.map((entry) => EngineLine(
        rank: entry.key + 1,
        evaluation: (entry.value.evaluation ?? 0) / 100.0,  // Convert centipawns to pawns
        depth: entry.value.depth,
        moves: entry.value.moves,
        isMate: entry.value.mateIn != null,
        mateIn: entry.value.mateIn,
      )).toList();

      state = state.copyWith(
        currentEval: result.evaluation / 100.0,  // Convert centipawns to pawns
        currentEngineLines: engineLines,
        bestMove: result.lines.isNotEmpty ? result.lines.first.moves.first : null,
      );
    } catch (e) {
      // Silently fail for live analysis
    }
  }

  /// Run full game analysis
  Future<void> analyzeFullGame() async {
    if (_stockfish == null) {
      await initialize();
    }
    
    if (_stockfish == null || state.originalMoves.isEmpty) return;

    state = state.copyWith(
      isAnalyzing: true,
      analysisProgress: 0.0,
      analyzedMoves: [],
    );

    final moves = state.originalMoves;
    final analyzedMoves = <MoveAnalysis>[];
    final board = chess.Chess.fromFEN(state.startingFen);
    
    double prevEval = 0.0;

    // Get initial evaluation
    stockfish.AnalysisResult? previousResult;
    try {
      final initialResult = await _stockfish!.analyzePosition(
        fen: board.fen,
        depth: 15,
        multiPv: 1,
      );
      prevEval = initialResult.evaluation / 100.0;  // Convert centipawns to pawns
      previousResult = initialResult;
    } catch (e) {
      // Continue with 0.0
    }

    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      final isWhiteMove = board.turn == chess.Color.WHITE;
      
      // Get best move before making the actual move
      String? bestMove;

      // Use previous analysis result if available to save time
      if (previousResult != null && previousResult.lines.isNotEmpty &&
          previousResult.lines.first.moves.isNotEmpty) {
        bestMove = previousResult.lines.first.moves.first;
      } else {
        try {
          final bestMoveResult = await _stockfish!.getBestMove(
            fen: board.fen,
            depth: 15,
          );
          bestMove = bestMoveResult.bestMove;
        } catch (e) {
          // Continue without best move
        }
      }

      // Apply the actual move
      board.move({'from': move.from, 'to': move.to, 'promotion': move.promotion});

      // Get evaluation after move
      double afterEval = 0.0;
      List<EngineLine> engineLines = [];
      
      try {
        final result = await _stockfish!.analyzePosition(
          fen: board.fen,
          depth: 15,
          multiPv: 3,
        );
        
        previousResult = result;
        afterEval = result.evaluation / 100.0;  // Convert centipawns to pawns
        engineLines = result.lines.asMap().entries.map((entry) => EngineLine(
          rank: entry.key + 1,
          evaluation: (entry.value.evaluation ?? 0) / 100.0,
          depth: entry.value.depth,
          moves: entry.value.moves,
          isMate: entry.value.mateIn != null,
          mateIn: entry.value.mateIn,
        )).toList();
      } catch (e) {
        // Continue with 0.0
      }

      // Classify the move
      final classification = classifyMove(
        evalBefore: prevEval,
        evalAfter: afterEval,
        isWhiteMove: isWhiteMove,
        bestMove: bestMove,
        actualMove: '${move.from}${move.to}${move.promotion ?? ''}',
      );

      analyzedMoves.add(MoveAnalysis(
        moveIndex: i,
        san: move.san,
        fen: board.fen,
        evalBefore: prevEval,
        evalAfter: afterEval,
        bestMove: bestMove,
        classification: classification,
        engineLines: engineLines,
        isWhiteMove: isWhiteMove,
      ));

      prevEval = afterEval;

      // Update progress
      // Batch updates to improve performance (reduce UI rebuilds)
      // Update every 5 moves or on the last move
      if ((i + 1) % 5 == 0 || i == moves.length - 1) {
        state = state.copyWith(
          analysisProgress: (i + 1) / moves.length,
          analyzedMoves: List.from(analyzedMoves),
        );
        stateUpdateCount++;
      }
    }

    // Create full analysis result
    final fullAnalysis = GameAnalysis.fromMoves(analyzedMoves);

    state = state.copyWith(
      isAnalyzing: false,
      analysisProgress: 1.0,
      analyzedMoves: analyzedMoves,
      fullAnalysis: fullAnalysis,
    );
  }

  /// Stop analysis
  void stopAnalysis() {
    _stockfish?.stopAnalysis();
    state = state.copyWith(isAnalyzing: false);
  }

  /// Reset state
  void reset() {
    state = const AnalysisState();
  }

  /// Dispose
  @override
  void dispose() {
    _stockfish?.dispose();
    super.dispose();
  }
}
