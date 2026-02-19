import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:google_fonts/google_fonts.dart';

/// Puzzle training screen
class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePuzzles();
    });
  }

  Future<void> _initializePuzzles() async {
    final notifier = ref.read(puzzleProvider.notifier);
    await notifier.initialize();
    await notifier.startNewPuzzle();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(puzzleProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Puzzle Trainer',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Rating display
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${state.currentRating}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(PuzzleGameState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (state.errorMessage != null && state.currentPuzzle == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePuzzles,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (state.currentPuzzle == null || state.board == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    return Column(
      children: [
        // Puzzle info with gradient card
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPuzzleInfoCard(state),
        ),

        // To play indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            state.isWhiteTurn ? "White to Move" : "Black to Move",
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status message
        if (state.errorMessage != null) _buildErrorMessage(state.errorMessage!),

        // Success message with animation
        if (state.state == PuzzleState.correct) _buildSuccessMessage(),

        const SizedBox(height: 8),

        // Chess board
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 0,
              ), // Maximize width
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _PuzzleBoard(state: state, ref: ref),
              ),
            ),
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: _buildControls(state),
        ),
      ],
    );
  }

  Widget _buildControls(PuzzleGameState state) {
    final notifier = ref.read(puzzleProvider.notifier);
    final isCompleted = state.state == PuzzleState.completed;

    if (isCompleted) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => notifier.retryPuzzle(),
              icon: const Icon(Icons.replay),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.textHint),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => notifier.nextPuzzle(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Puzzle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // First row: Hint and Show Solution
        Row(
          children: [
            // Hint button - no limit
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.isPlayerTurn && !state.showingHint
                    ? () => notifier.showHint()
                    : null,
                icon: const Icon(Icons.lightbulb_outline, size: 20),
                label: const Text('Hint'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Show Solution button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSolutionDialog(state),
                icon: const Icon(Icons.visibility_outlined, size: 20),
                label: const Text('Solution'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Skip button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSkipConfirmation(),
                icon: const Icon(Icons.skip_next, size: 20),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSolutionDialog(PuzzleGameState state) {
    final puzzle = state.currentPuzzle;
    if (puzzle == null) return;

    // Navigate to auto-play solution screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AutoPlaySolutionScreen(puzzle: puzzle),
      ),
    );
  }

  void _showSkipConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Skip Puzzle?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Skipping will count as an incorrect attempt and may lower your rating.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(puzzleProvider.notifier).skipPuzzle();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Skip',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleInfoCard(PuzzleGameState state) {
    final puzzle = state.currentPuzzle!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.extension, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Puzzle #${state.puzzleQueue.length + 1}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rating: ${puzzle.rating} • ${puzzle.themes.join(", ")}',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${state.streak}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Hints: ${state.hintsUsed}',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.close, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Correct! Keep going...',
            style: GoogleFonts.inter(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Puzzle chess board
class _PuzzleBoard extends StatelessWidget {
  final PuzzleGameState state;
  final WidgetRef ref;

  const _PuzzleBoard({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Determine if board should be flipped based on puzzle starting position
    // Board should stay oriented to the side that's solving the puzzle
    final puzzle = state.currentPuzzle;
    final isFlipped = puzzle != null && puzzle.fen.contains(' b ');

    // Build hint move in UCI format for arrow display
    String? hintMove;
    if (state.showingHint &&
        state.hintFromSquare != null &&
        state.hintToSquare != null) {
      hintMove = '${state.hintFromSquare}${state.hintToSquare}';
    }

    return ChessBoard(
      fen: state.fen,
      isFlipped: isFlipped,
      selectedSquare: state.selectedSquare,
      legalMoves: state.legalMoves,
      lastMoveFrom: state.lastMoveFrom,
      lastMoveTo: state.lastMoveTo,
      bestMove: hintMove, // Show hint as arrow
      showHint: state.showingHint,
      hintSquare: state.hintFromSquare,
      highlightedSquares: state.highlightedSquares,
      onSquareTap: state.isPlayerTurn
          ? (square) {
              ref.read(puzzleProvider.notifier).selectSquare(square);
            }
          : null,
      onMove: state.isPlayerTurn
          ? (from, to) async {
              final notifier = ref.read(puzzleProvider.notifier);

              // Check for promotion
              if (notifier.needsPromotion(from, to)) {
                final promotion = await _showPromotionDialog(
                  context,
                  state.isWhiteTurn,
                );
                if (promotion != null) {
                  notifier.tryMove(from, to, promotion: promotion);
                }
              } else {
                notifier.tryMove(from, to);
              }
            }
          : null,
      showCoordinates: true,
    );
  }

  Future<String?> _showPromotionDialog(
    BuildContext context,
    bool isWhite,
  ) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Promote Pawn',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PromotionButton(piece: 'q', isWhite: isWhite, label: 'Queen'),
            _PromotionButton(piece: 'r', isWhite: isWhite, label: 'Rook'),
            _PromotionButton(piece: 'b', isWhite: isWhite, label: 'Bishop'),
            _PromotionButton(piece: 'n', isWhite: isWhite, label: 'Knight'),
          ],
        ),
      ),
    );
  }
}

class _PromotionButton extends StatelessWidget {
  final String piece;
  final bool isWhite;
  final String label;

  const _PromotionButton({
    required this.piece,
    required this.isWhite,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, piece),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getPieceSymbol(), style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPieceSymbol() {
    final symbols = {
      'q': isWhite ? '♕' : '♛',
      'r': isWhite ? '♖' : '♜',
      'b': isWhite ? '♗' : '♝',
      'n': isWhite ? '♘' : '♞',
    };
    return symbols[piece] ?? '?';
  }
}

/// Auto-play solution screen
class _AutoPlaySolutionScreen extends StatefulWidget {
  final Puzzle puzzle;

  const _AutoPlaySolutionScreen({required this.puzzle});

  @override
  State<_AutoPlaySolutionScreen> createState() =>
      _AutoPlaySolutionScreenState();
}

class _AutoPlaySolutionScreenState extends State<_AutoPlaySolutionScreen> {
  late chess.Chess _board;
  int _currentMoveIndex = 0;
  bool _isPlaying = false;
  String? _lastMoveFrom;
  String? _lastMoveTo;

  @override
  void initState() {
    super.initState();
    _board = chess.Chess.fromFEN(widget.puzzle.fen);
    // Apply setup move if exists
    if (widget.puzzle.setupMove != null) {
      _applyUciMove(widget.puzzle.setupMove!);
    }
  }

  void _applyUciMove(String uci) {
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : null;

    _board.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    setState(() {
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });
  }

  void _playNextMove() {
    if (_currentMoveIndex >= widget.puzzle.moves.length) return;

    setState(() => _isPlaying = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _applyUciMove(widget.puzzle.moves[_currentMoveIndex]);
      setState(() {
        _currentMoveIndex++;
        _isPlaying = false;
      });
    });
  }

  void _reset() {
    setState(() {
      _board = chess.Chess.fromFEN(widget.puzzle.fen);
      if (widget.puzzle.setupMove != null) {
        _applyUciMove(widget.puzzle.setupMove!);
      }
      _currentMoveIndex = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _currentMoveIndex >= widget.puzzle.moves.length;
    final isFlipped = widget.puzzle.fen.contains(' b ');

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Solution',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Move ${_currentMoveIndex + 1} of ${widget.puzzle.moves.length}',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ChessBoard(
                  fen: _board.fen,
                  isFlipped: isFlipped,
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                  showCoordinates: true,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isComplete || _isPlaying ? null : _playNextMove,
                    icon: Icon(isComplete ? Icons.check : Icons.play_arrow),
                    label: Text(isComplete ? 'Complete' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
