import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/services/audio_service.dart';

/// Parse puzzles in a separate isolate
List<Puzzle> _parsePuzzles(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((j) => Puzzle.fromJson(j)).toList();
}

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
  final Set<String> highlightedSquares;
  final bool isRetry;

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
    this.highlightedSquares = const {},
    this.isRetry = false,
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
    Set<String>? highlightedSquares,
    bool? isRetry,
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
      highlightedSquares: highlightedSquares ?? this.highlightedSquares,
      isRetry: isRetry ?? this.isRetry,
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
  List<Puzzle> _allPuzzles = [];
  final Random _random = Random();
  final Set<int> _recentlySolvedIds = {}; // Track recently solved puzzles
  static const int _maxRecentPuzzles = 50; // Keep last 50 puzzles in memory
  Timer? _solutionTimer;

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
      await _loadPuzzles();
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

  /// Load puzzles from assets
  Future<void> _loadPuzzles() async {
    try {
      debugPrint('🧩 Loading puzzles from assets...');
      final String jsonString = await rootBundle.loadString(
        'assets/puzzles/puzzles.json',
      );
      debugPrint('🧩 JSON loaded, size: ${jsonString.length} bytes');

      // Use compute to parse JSON in background isolate to prevent UI jank
      _allPuzzles = await compute(_parsePuzzles, jsonString);

      debugPrint('🧩 Successfully loaded ${_allPuzzles.length} puzzles');
    } catch (e) {
      debugPrint('🧩 ERROR loading puzzles: $e');
      // If JSON doesn't exist, use empty list
      _allPuzzles = [];
    }
  }

  /// Start a new puzzle session
  Future<void> startNewPuzzle({int? targetRating}) async {
    _stopSolutionPlayback();

    debugPrint(
      '🧩 Starting new puzzle, _allPuzzles.length = ${_allPuzzles.length}',
    );

    if (_allPuzzles.isEmpty) {
      debugPrint('🧩 Puzzles empty, loading...');
      await _loadPuzzles();
      if (_allPuzzles.isEmpty) {
        debugPrint('🧩 ERROR: No puzzles available after loading');
        state = state.copyWith(
          errorMessage: 'No puzzles available',
          state: PuzzleState.loading,
        );
        return;
      }
    }

    final rating = targetRating ?? state.currentRating;
    debugPrint('🧩 Target rating: $rating');

    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      attempts++;

      // Find a puzzle close to current rating
      final puzzle = _selectPuzzleByRating(rating);

      if (puzzle == null) {
        debugPrint('🧩 ERROR: No suitable puzzle found');
        state = state.copyWith(
          errorMessage: 'No suitable puzzle found',
          state: PuzzleState.loading,
        );
        return;
      }

      debugPrint('🧩 Selected puzzle ${puzzle.id}, rating ${puzzle.rating}');
      final success = await _loadPuzzle(puzzle);
      if (success) {
        debugPrint('🧩 Puzzle loaded successfully');
        return;
      }

      debugPrint('Skipping invalid puzzle: ${puzzle.id}');
      // If validation failed, try another one
    }

    debugPrint(
      '🧩 ERROR: Failed to find valid puzzle after $maxAttempts attempts',
    );
    state = state.copyWith(
      errorMessage: 'Failed to find valid puzzle',
      state: PuzzleState.loading,
    );
  }

  /// Select puzzle based on current mode and filters
  Puzzle? _selectPuzzleByRating(int targetRating) {
    if (_allPuzzles.isEmpty) return null;

    List<Puzzle> candidates;

    switch (_mode) {
      case PuzzleFilterMode.random:
        // Any puzzle from the collection
        candidates = List.from(_allPuzzles);
        break;

      case PuzzleFilterMode.eloRange:
        // Filter by custom ELO range
        candidates =
            _allPuzzles
                .where((p) => p.rating >= _minRating && p.rating <= _maxRating)
                .toList();
        break;

      case PuzzleFilterMode.theme:
        // Filter by theme
        if (_themeFilter == 'all') {
          candidates = List.from(_allPuzzles);
        } else {
          candidates =
              _allPuzzles
                  .where(
                    (p) => p.themes.any(
                      (t) =>
                          t.toLowerCase().contains(_themeFilter.toLowerCase()),
                    ),
                  )
                  .toList();
        }
        break;

      case PuzzleFilterMode.daily:
        // Daily puzzle based on date
        final now = DateTime.now();
        final seed = now.year * 10000 + now.month * 100 + now.day;
        final dailyRandom = Random(seed);
        if (_allPuzzles.isEmpty) return null;
        return _allPuzzles[dailyRandom.nextInt(_allPuzzles.length)];

      case PuzzleFilterMode.adaptive:
      default:
        // Adaptive: within ±200 of current rating
        final minRating = targetRating - 200;
        final maxRating = targetRating + 200;
        candidates =
            _allPuzzles
                .where((p) => p.rating >= minRating && p.rating <= maxRating)
                .toList();
        break;
    }

    if (candidates.isEmpty) {
      // Fall back to any puzzle
      candidates = List.from(_allPuzzles);
    }

    // Filter out recently solved puzzles
    final freshCandidates =
        candidates.where((p) => !_recentlySolvedIds.contains(p.id)).toList();

    // If all puzzles were recently solved, clear history and use all candidates
    if (freshCandidates.isEmpty) {
      _recentlySolvedIds.clear();
      return candidates[_random.nextInt(candidates.length)];
    }

    return freshCandidates[_random.nextInt(freshCandidates.length)];
  }

  /// Load a specific puzzle
  Future<bool> _loadPuzzle(Puzzle puzzle) async {
    try {
      // Validation
      final valid = chess.Chess.validate_fen(puzzle.fen);
      if (valid['valid'] != true) {
        debugPrint(
          'Invalid puzzle FEN: ${puzzle.fen}, Error: ${valid['error']}',
        );
        return false;
      }

      final board = chess.Chess.fromFEN(puzzle.fen);

      // Additional validation: check if position is already checkmate
      if (board.in_checkmate) {
        debugPrint('Skipping puzzle - position is already checkmate');
        return false;
      }

      // The Lichess puzzle FEN represents the position BEFORE the opponent's blunder
      // The first move in puzzle.moves is the opponent's move.
      if (puzzle.moves.isEmpty) return false;

      final setupMoveUci = puzzle.moves.first;
      final from = setupMoveUci.substring(0, 2);
      final to = setupMoveUci.substring(2, 4);
      final promotion =
          setupMoveUci.length > 4 ? setupMoveUci.substring(4, 5) : null;

      final success = board.move({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      });

      if (!success) {
        debugPrint('Failed to apply initial setup move: $setupMoveUci');
        return false;
      }

      // Determine whose turn it is from the FEN
      // The player should be the one to move in the puzzle position AFTER the setup move
      final isPlayerTurn = true;

      state = state.copyWith(
        currentPuzzle: puzzle,
        board: board,
        currentMoveIndex: 1, // Player starts at index 1!
        selectedSquare: null,
        legalMoves: [],
        lastMoveFrom: from,
        lastMoveTo: to,
        showingHint: false,
        hintsUsed: 0,
        errorMessage: null,
        isPlayerTurn: isPlayerTurn,
        state: PuzzleState.playing,
        clearSelection: true,
        clearError: true,
        highlightedSquares: {},
        isRetry: false, // Default not retry, will override in retry function
      );

      return true;
    } catch (e) {
      debugPrint('Error loading puzzle: $e');
      return false;
    }
  }

  /// Apply a UCI format move
  bool _applyUciMove(String uci) {
    if (state.board == null) return false;

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : null;

    try {
      state.board!.move({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      });

      // Update state with new board position
      state = state.copyWith(
        board: state.board,
        lastMoveFrom: from,
        lastMoveTo: to,
      );

      return true;
    } catch (e) {
      debugPrint('Error applying UCI move $uci: $e');
      return false;
    }
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

    debugPrint(
      '🧩 Player move: $uciMove, Expected: $expectedMove, MoveIndex: ${state.currentMoveIndex}',
    );

    if (expectedMove == null) {
      debugPrint(
        '🧩 ERROR: No expected move at index ${state.currentMoveIndex}',
      );
      return;
    }

    final isCorrect = expectedMove.toLowerCase().startsWith(
      uciMove.toLowerCase(),
    );

    if (!isCorrect) {
      // Wrong move - play error sound
      AudioService.instance.playCheck(); // Using check sound as error indicator

      debugPrint('🧩 Wrong move! Expected: $expectedMove, Got: $uciMove');

      // Puzzle failed!
      _onPuzzleCompleted(false);

      state = state.copyWith(
        state: PuzzleState.incorrect,
        errorMessage: 'Not the best move. Try again!',
        clearSelection: true,
      );

      return;
    }

    debugPrint('🧩 Correct move!');

    // Correct move - play move sound
    final capturedPiece = state.board!.get(to);
    if (capturedPiece != null) {
      AudioService.instance.playCapture();
    } else {
      AudioService.instance.playMove();
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
      debugPrint('🧩 Puzzle solved! No more moves.');
      _onPuzzleCompleted(true);
      return;
    }

    debugPrint('🧩 Next expected move: $nextExpectedMove');

    state = state.copyWith(
      currentMoveIndex: newMoveIndex,
      isPlayerTurn: false,
      clearSelection: true,
      state: PuzzleState.correct, // Show success feedback
    );

    // Apply opponent's response after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _applyOpponentMove(nextExpectedMove);
    });
  }

  /// Apply opponent's move in puzzle
  void _applyOpponentMove(String uciMove) {
    debugPrint('🧩 Applying opponent move: $uciMove');

    if (!_applyUciMove(uciMove)) {
      debugPrint('🧩 ERROR: Failed to apply opponent move');
      return;
    }

    final newMoveIndex = state.currentMoveIndex + 1;

    // Check if there are more moves for player
    final nextPlayerMove = state.currentPuzzle?.getExpectedMove(newMoveIndex);

    if (nextPlayerMove == null) {
      // Puzzle completed!
      debugPrint('🧩 Puzzle completed! No more moves.');
      _onPuzzleCompleted(true);
      return;
    }

    debugPrint('🧩 Next player move expected: $nextPlayerMove');
    state = state.copyWith(
      currentMoveIndex: newMoveIndex,
      isPlayerTurn: true,
      state: PuzzleState.playing, // Back to playing state
    );
  }

  /// Handle puzzle completion
  Future<void> _onPuzzleCompleted(bool solved) async {
    final puzzle = state.currentPuzzle;
    if (puzzle == null) return;

    if (state.isRetry) {
      // Don't modify stats or ELO for retries. Just track the state change.
      state = state.copyWith(
        state: solved ? PuzzleState.completed : PuzzleState.incorrect,
        isPlayerTurn: false,
      );
      return;
    }

    // Add to recently solved puzzles to avoid duplicates
    _recentlySolvedIds.add(puzzle.id);
    // Keep only the last N puzzles
    if (_recentlySolvedIds.length > _maxRecentPuzzles) {
      _recentlySolvedIds.remove(_recentlySolvedIds.first);
    }

    // Play completion sound
    AudioService.instance.playGameEnd();

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

    // Save to puzzle progress tracking history
    await db.savePuzzleProgress(puzzle.id, solved);

    final currentStats = await db.getStatistics() ?? {};
    final puzzlesAttempted =
        (currentStats['puzzles_attempted'] as int? ?? 0) + 1;
    final puzzlesSolved =
        solved
            ? (currentStats['puzzles_solved'] as int? ?? 0) + 1
            : (currentStats['puzzles_solved'] as int? ?? 0);

    await db.updateStatistics({
      'current_puzzle_rating': newRating,
      'puzzles_attempted': puzzlesAttempted,
      'puzzles_solved': puzzlesSolved,
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
  Future<void> showSolution() async {
    if (state.currentPuzzle == null) return;

    state = state.copyWith(
      showingSolution: true,
      hintsUsed: state.hintsUsed + 1,
      highlightedSquares: {},
    );

    // Auto-play the solution
    _startSolutionPlayback();
  }

  /// Play through the solution moves using Timer
  void _startSolutionPlayback() {
    _stopSolutionPlayback();

    final puzzle = state.currentPuzzle;
    if (puzzle == null) return;

    // Reset board to starting position of the puzzle
    final board = chess.Chess.fromFEN(puzzle.fen);
    state = state.copyWith(board: board, currentMoveIndex: 0);

    // DO NOT apply setup move - the FEN is already the correct starting position

    int moveIndex = 0;

    _solutionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.showingSolution) {
        timer.cancel();
        return;
      }

      if (moveIndex >= puzzle.moves.length) {
        timer.cancel();
        _onPuzzleCompleted(false);
        return;
      }

      final uciMove = puzzle.moves[moveIndex];
      _applyUciMove(uciMove);

      // Highlight squares
      if (uciMove.length >= 4) {
        final from = uciMove.substring(0, 2);
        final to = uciMove.substring(2, 4);
        state = state.copyWith(highlightedSquares: {from, to});
      }

      moveIndex++;
    });
  }

  void _stopSolutionPlayback() {
    _solutionTimer?.cancel();
    _solutionTimer = null;
  }

  /// Hide solution
  void hideSolution() {
    _stopSolutionPlayback();
    state = state.copyWith(showingSolution: false, highlightedSquares: {});
  }

  /// Get all solution moves for current puzzle
  List<String> getSolutionMoves() {
    final puzzle = state.currentPuzzle;
    if (puzzle == null) return [];

    return puzzle.moves;
  }

  /// Skip current puzzle
  Future<void> skipPuzzle() async {
    _stopSolutionPlayback();
    await _onPuzzleCompleted(false);
    // Load next puzzle after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    await startNewPuzzle();
  }

  /// Retry current puzzle
  Future<void> retryPuzzle() async {
    _stopSolutionPlayback();
    final puzzle = state.currentPuzzle;
    if (puzzle != null) {
      final success = await _loadPuzzle(puzzle);
      if (success) {
        state = state.copyWith(isRetry: true);
      }
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

  @override
  void dispose() {
    _stopSolutionPlayback();
    super.dispose();
  }
}
