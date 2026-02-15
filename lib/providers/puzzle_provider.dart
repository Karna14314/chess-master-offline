import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/core/services/database_service.dart';

/// Provider for puzzle state
final puzzleProvider = StateNotifierProvider<PuzzleNotifier, PuzzleGameState>((
  ref,
) {
  return PuzzleNotifier(ref);
});

/// Provider for puzzle statistics
final puzzleStatsProvider = FutureProvider<PuzzleStats>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final stats = await db.getStatistics();

  if (stats == null) {
    return PuzzleStats(
      currentRating: 1200,
      puzzlesSolved: 0,
      puzzlesAttempted: 0,
    );
  }

  return PuzzleStats(
    currentRating: stats['current_puzzle_rating'] as int? ?? 1200,
    puzzlesSolved: stats['puzzles_solved'] as int? ?? 0,
    puzzlesAttempted: stats['puzzles_attempted'] as int? ?? 0,
  );
});

/// Puzzle game state
class PuzzleGameState {
  final PuzzleState state;
  final Puzzle? currentPuzzle;
  final chess.Chess? board;
  final int currentMoveIndex;
  final String? selectedSquare;
  final List<String> legalMoves;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool showingHint;
  final String? hintFromSquare; // Full hint: from square
  final String? hintToSquare; // Full hint: to square
  final bool showingSolution; // Show complete solution
  final int hintsUsed;
  final int currentRating;
  final int streak;
  final String? errorMessage;
  final bool isPlayerTurn;
  final List<Puzzle> puzzleQueue;
  final bool isLoading;

  const PuzzleGameState({
    this.state = PuzzleState.loading,
    this.currentPuzzle,
    this.board,
    this.currentMoveIndex = 0,
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.showingHint = false,
    this.hintFromSquare,
    this.hintToSquare,
    this.showingSolution = false,
    this.hintsUsed = 0,
    this.currentRating = 1200,
    this.streak = 0,
    this.errorMessage,
    this.isPlayerTurn = false,
    this.puzzleQueue = const [],
    this.isLoading = false,
  });

  PuzzleGameState copyWith({
    PuzzleState? state,
    Puzzle? currentPuzzle,
    chess.Chess? board,
    int? currentMoveIndex,
    String? selectedSquare,
    List<String>? legalMoves,
    String? lastMoveFrom,
    String? lastMoveTo,
    bool? showingHint,
    String? hintFromSquare,
    String? hintToSquare,
    bool? showingSolution,
    int? hintsUsed,
    int? currentRating,
    int? streak,
    String? errorMessage,
    bool? isPlayerTurn,
    List<Puzzle>? puzzleQueue,
    bool? isLoading,
    bool clearSelection = false,
    bool clearError = false,
    bool clearHint = false,
  }) {
    return PuzzleGameState(
      state: state ?? this.state,
      currentPuzzle: currentPuzzle ?? this.currentPuzzle,
      board: board ?? this.board,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      selectedSquare:
          clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelection ? [] : (legalMoves ?? this.legalMoves),
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      showingHint: clearHint ? false : (showingHint ?? this.showingHint),
      hintFromSquare:
          clearHint ? null : (hintFromSquare ?? this.hintFromSquare),
      hintToSquare: clearHint ? null : (hintToSquare ?? this.hintToSquare),
      showingSolution: showingSolution ?? this.showingSolution,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      currentRating: currentRating ?? this.currentRating,
      streak: streak ?? this.streak,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPlayerTurn: isPlayerTurn ?? this.isPlayerTurn,
      puzzleQueue: puzzleQueue ?? this.puzzleQueue,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Current FEN position
  String get fen => board?.fen ?? '';

  /// Is white's turn
  bool get isWhiteTurn => board?.turn == chess.Color.WHITE;

  /// Get piece at square
  String? getPieceAt(String square) {
    if (board == null) return null;
    final piece = board!.get(square);
    if (piece == null) return null;

    final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final pieceChar = piece.type.name.toUpperCase();
    return '$colorPrefix$pieceChar';
  }

  /// Accuracy percentage
  double get accuracy {
    if (hintsUsed == 0) return 100.0;
    return max(0, 100 - (hintsUsed * 25)).toDouble();
  }
}

/// Puzzle statistics
class PuzzleStats {
  final int currentRating;
  final int puzzlesSolved;
  final int puzzlesAttempted;

  const PuzzleStats({
    required this.currentRating,
    required this.puzzlesSolved,
    required this.puzzlesAttempted,
  });

  double get successRate {
    if (puzzlesAttempted == 0) return 0;
    return (puzzlesSolved / puzzlesAttempted) * 100;
  }
}

/// Puzzle mode enum
enum PuzzleFilterMode {
  adaptive, // Based on current rating
  random, // Random puzzles
  eloRange, // Specific ELO range
  theme, // By theme
  daily, // Daily puzzle
}

/// Puzzle notifier managing puzzle logic
class PuzzleNotifier extends StateNotifier<PuzzleGameState> {
  final Ref _ref;
  final Random _random = Random();

  // Puzzle mode configuration
  PuzzleFilterMode _mode = PuzzleFilterMode.adaptive;
  int _minRating = 400;
  int _maxRating = 2500;
  String _themeFilter = 'all';

  PuzzleNotifier(this._ref) : super(const PuzzleGameState());

  // Helper class for mode config
  void setModeConfig({
    PuzzleFilterMode mode = PuzzleFilterMode.adaptive,
    int? minRating,
    int? maxRating,
    String? theme,
  }) {
    _mode = mode;
    _minRating = minRating ?? 400;
    _maxRating = maxRating ?? 2500;
    _themeFilter = theme ?? 'all';
  }

  /// Initialize and load puzzles
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _checkAndLoadPuzzles();
      final stats = await _ref.read(databaseServiceProvider).getStatistics();
      final rating = stats?['current_puzzle_rating'] as int? ?? 1200;

      state = state.copyWith(currentRating: rating, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to load puzzles: $e',
        isLoading: false,
      );
    }
  }

  /// Check if DB has puzzles, if not load from assets
  Future<void> _checkAndLoadPuzzles() async {
    final db = _ref.read(databaseServiceProvider);
    final count = await db.getPuzzleCount();

    if (count == 0) {
      try {
        final String jsonString = await rootBundle.loadString(
          'assets/puzzles/puzzles.json',
        );
        // Parse in isolate
        final puzzles = await compute(_parsePuzzles, jsonString);

        // Convert to map for DB insert
        final puzzleMaps = puzzles.map((p) => p.toJson()).toList();

        // Insert in batches
        const batchSize = 500;
        for (var i = 0; i < puzzleMaps.length; i += batchSize) {
          final end =
              (i + batchSize < puzzleMaps.length)
                  ? i + batchSize
                  : puzzleMaps.length;
          await db.insertPuzzles(puzzleMaps.sublist(i, end));
        }
      } catch (e) {
        debugPrint('Error loading initial puzzles: $e');
      }
    }
  }

  /// Start a new puzzle session
  Future<void> startNewPuzzle({int? targetRating}) async {
    final rating = targetRating ?? state.currentRating;

    // Find a puzzle from DB
    final puzzle = await _fetchPuzzle(rating);

    if (puzzle == null) {
      state = state.copyWith(
        errorMessage: 'No suitable puzzle found. Try changing filters.',
        state: PuzzleState.loading,
      );
      return;
    }

    await _loadPuzzle(puzzle);
  }

  /// Fetch puzzle from DB based on criteria
  Future<Puzzle?> _fetchPuzzle(int targetRating) async {
    final db = _ref.read(databaseServiceProvider);

    int? minRating;
    int? maxRating;
    String? theme;

    switch (_mode) {
      case PuzzleFilterMode.random:
        // No filters
        break;

      case PuzzleFilterMode.eloRange:
        minRating = _minRating;
        maxRating = _maxRating;
        break;

      case PuzzleFilterMode.theme:
        theme = _themeFilter;
        break;

      case PuzzleFilterMode.daily:
        // Daily puzzle logic needs stable random selection based on date
        // For DB implementation, we can pick based on ID offset
        final now = DateTime.now();
        final seed = now.year * 10000 + now.month * 100 + now.day;
        final dailyRandom = Random(seed);

        // Get total count
        final count = await db.getPuzzleCount();
        if (count == 0) return null;

        // Offset
        final offset = dailyRandom.nextInt(count);
        final results = await db.getPuzzles(
          limit: 1,
          random: false,
          offset: offset,
        );
        return (results.isNotEmpty) ? Puzzle.fromJson(results.first) : null;

      case PuzzleFilterMode.adaptive:
      default:
        minRating = targetRating - 200;
        maxRating = targetRating + 200;
        break;
    }

    final results = await db.getPuzzles(
      minRating: minRating,
      maxRating: maxRating,
      theme: theme,
      limit: 1, // Get one random
      random: true,
    );

    // If adaptive failed (too narrow), widen search
    if (results.isEmpty && _mode == PuzzleFilterMode.adaptive) {
      final widenedResults = await db.getPuzzles(
        minRating: targetRating - 500,
        maxRating: targetRating + 500,
        limit: 1,
        random: true,
      );
      if (widenedResults.isNotEmpty) {
        return Puzzle.fromJson(widenedResults.first);
      }
    }

    return results.isNotEmpty ? Puzzle.fromJson(results.first) : null;
  }

  /// Load a specific puzzle
  Future<void> _loadPuzzle(Puzzle puzzle) async {
    final board = chess.Chess.fromFEN(puzzle.fen);

    state = state.copyWith(
      currentPuzzle: puzzle,
      board: board,
      currentMoveIndex: 0,
      selectedSquare: null,
      legalMoves: [],
      lastMoveFrom: null,
      lastMoveTo: null,
      showingHint: false,
      hintsUsed: 0,
      errorMessage: null,
      isPlayerTurn: false,
      state: PuzzleState.ready,
      clearSelection: true,
      clearError: true,
    );

    // Apply setup move after a delay
    await Future.delayed(const Duration(milliseconds: 500));
    _applySetupMove();
  }

  /// Apply the opponent's setup move
  void _applySetupMove() {
    final puzzle = state.currentPuzzle;
    if (puzzle == null || state.board == null) return;

    final setupMove = puzzle.setupMove;
    if (setupMove == null) return;

    _applyUciMove(setupMove);

    state = state.copyWith(state: PuzzleState.playing, isPlayerTurn: true);
  }

  /// Apply a UCI format move
  bool _applyUciMove(String uci) {
    if (state.board == null) return false;

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : null;

    final move = state.board!.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    // Create new board with same state
    final newBoard = chess.Chess.fromFEN(state.board!.fen);
    state = state.copyWith(board: newBoard, lastMoveFrom: from, lastMoveTo: to);
    return true;
  }

  /// Select a square on the board
  void selectSquare(String square) {
    if (!state.isPlayerTurn || state.state != PuzzleState.playing) return;

    final board = state.board;
    if (board == null) return;

    // If already selected and clicking on a legal move, make the move
    if (state.selectedSquare != null && state.legalMoves.contains(square)) {
      _makePlayerMove(state.selectedSquare!, square);
      return;
    }

    // Check if square has a piece of current turn color
    final piece = board.get(square);
    if (piece != null && piece.color == board.turn) {
      // Get legal moves for this piece
      final moves = board.moves({'square': square, 'verbose': true});
      final legalSquares = moves.map((m) => m['to'] as String).toList();

      state = state.copyWith(selectedSquare: square, legalMoves: legalSquares);
    } else {
      state = state.copyWith(clearSelection: true);
    }
  }

  /// Make a player move
  void _makePlayerMove(String from, String to, {String? promotion}) {
    final puzzle = state.currentPuzzle;
    if (puzzle == null || state.board == null) return;

    // Check if this is the expected move
    final uciMove = '$from$to${promotion ?? ''}';
    final expectedMove = puzzle.getExpectedMove(state.currentMoveIndex);

    if (expectedMove == null) return;

    final isCorrect = expectedMove.toLowerCase().startsWith(
      uciMove.toLowerCase(),
    );

    if (!isCorrect) {
      // Wrong move
      state = state.copyWith(
        state: PuzzleState.incorrect,
        errorMessage: 'Not the best move. Try again!',
        clearSelection: true,
      );

      // Reset to try again after delay
      Future.delayed(const Duration(seconds: 1), () {
        if (state.state == PuzzleState.incorrect) {
          state = state.copyWith(
            state: PuzzleState.playing,
            isPlayerTurn: true,
            clearError: true,
          );
        }
      });
      return;
    }

    // Check for promotion
    final expectedPromotion =
        expectedMove.length > 4 ? expectedMove.substring(4) : null;
    final finalMove = '$from$to${expectedPromotion ?? promotion ?? ''}';

    // Apply the correct move
    if (!_applyUciMove(finalMove)) return;

    final newMoveIndex = state.currentMoveIndex + 1;

    // Check if puzzle is completed
    final nextExpectedMove = puzzle.getExpectedMove(newMoveIndex);

    if (nextExpectedMove == null) {
      // Puzzle completed!
      _onPuzzleCompleted(true);
      return;
    }

    state = state.copyWith(
      currentMoveIndex: newMoveIndex,
      isPlayerTurn: false,
      clearSelection: true,
    );

    // Apply opponent's response after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _applyOpponentMove(nextExpectedMove);
    });
  }

  /// Apply opponent's move in puzzle
  void _applyOpponentMove(String uciMove) {
    if (!_applyUciMove(uciMove)) return;

    final newMoveIndex = state.currentMoveIndex + 1;

    // Check if there are more moves for player
    if (state.currentPuzzle?.getExpectedMove(newMoveIndex) == null) {
      // Puzzle completed!
      _onPuzzleCompleted(true);
      return;
    }

    state = state.copyWith(currentMoveIndex: newMoveIndex, isPlayerTurn: true);
  }

  /// Handle puzzle completion
  Future<void> _onPuzzleCompleted(bool solved) async {
    final puzzle = state.currentPuzzle;
    if (puzzle == null) return;

    // Calculate rating change
    int ratingChange = 0;
    final currentRating = state.currentRating;
    final puzzleRating = puzzle.rating;

    if (solved) {
      // K-factor style rating change
      final expectedScore =
          1 / (1 + pow(10, (puzzleRating - currentRating) / 400));
      ratingChange = (32 * (1 - expectedScore)).round();
      if (state.hintsUsed > 0) {
        ratingChange =
            (ratingChange * 0.5).round(); // Reduce gain if hints used
      }
    } else {
      final expectedScore =
          1 / (1 + pow(10, (puzzleRating - currentRating) / 400));
      ratingChange = -(32 * expectedScore).round();
    }

    final newRating = (currentRating + ratingChange).clamp(100, 3000);
    final newStreak = solved ? state.streak + 1 : 0;

    state = state.copyWith(
      state: solved ? PuzzleState.completed : PuzzleState.incorrect,
      currentRating: newRating,
      streak: newStreak,
      isPlayerTurn: false,
    );

    // Update database
    final db = _ref.read(databaseServiceProvider);
    await db.updateStatistics({
      'current_puzzle_rating': newRating,
      'puzzles_attempted':
          (await db.getStatistics())?['puzzles_attempted'] ?? 0 + 1,
      if (solved)
        'puzzles_solved':
            (await db.getStatistics())?['puzzles_solved'] ?? 0 + 1,
    });
  }

  /// Show hint for current position - shows full move with arrow
  void showHint() {
    if (state.state != PuzzleState.playing || !state.isPlayerTurn) return;

    final puzzle = state.currentPuzzle;
    if (puzzle == null) return;

    final expectedMove = puzzle.getExpectedMove(state.currentMoveIndex);
    if (expectedMove == null) return;

    final fromSquare = expectedMove.substring(0, 2);
    final toSquare = expectedMove.substring(2, 4);

    state = state.copyWith(
      showingHint: true,
      hintFromSquare: fromSquare,
      hintToSquare: toSquare,
      hintsUsed: state.hintsUsed + 1,
    );

    // Hide hint after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (state.showingHint) {
        state = state.copyWith(clearHint: true);
      }
    });
  }

  /// Show complete solution for the puzzle
  void showSolution() {
    if (state.currentPuzzle == null) return;

    state = state.copyWith(
      showingSolution: true,
      hintsUsed: state.hintsUsed + 1, // Count as hint usage
    );
  }

  /// Hide solution
  void hideSolution() {
    state = state.copyWith(showingSolution: false);
  }

  /// Get all solution moves for current puzzle
  List<String> getSolutionMoves() {
    final puzzle = state.currentPuzzle;
    if (puzzle == null) return [];

    return puzzle.moves;
  }

  /// Skip current puzzle
  void skipPuzzle() {
    _onPuzzleCompleted(false);
  }

  /// Retry current puzzle
  Future<void> retryPuzzle() async {
    final puzzle = state.currentPuzzle;
    if (puzzle != null) {
      await _loadPuzzle(puzzle);
    }
  }

  /// Load next puzzle
  Future<void> nextPuzzle() async {
    await startNewPuzzle();
  }

  /// Try move via drag and drop
  void tryMove(String from, String to, {String? promotion}) {
    if (!state.isPlayerTurn || state.state != PuzzleState.playing) return;
    _makePlayerMove(from, to, promotion: promotion);
  }

  /// Check if a move needs promotion dialog
  bool needsPromotion(String from, String to) {
    if (state.board == null) return false;

    final piece = state.board!.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;

    final toRank = int.parse(to[1]);
    final isWhite = piece.color == chess.Color.WHITE;

    return (isWhite && toRank == 8) || (!isWhite && toRank == 1);
  }

  /// Get all legal moves for current position
  List<Map<String, String>> getAllLegalMoves() {
    if (state.board == null) return [];
    final moves = state.board!.moves({'verbose': true});
    return moves
        .map((m) => {'from': m['from'] as String, 'to': m['to'] as String})
        .toList()
        .cast<Map<String, String>>();
  }

  /// Check if square is a legal move target
  bool isLegalMoveSquare(String square) {
    return state.legalMoves.contains(square);
  }

  /// Check if square has a capturable piece
  bool isCapturableSquare(String square) {
    if (state.board == null || !state.legalMoves.contains(square)) return false;
    final piece = state.board!.get(square);
    return piece != null && piece.color != state.board!.turn;
  }
}

/// Parse puzzles in a separate isolate
List<Puzzle> _parsePuzzles(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((j) => Puzzle.fromJson(j)).toList();
}
