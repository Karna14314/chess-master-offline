import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:google_fonts/google_fonts.dart';

/// Daily puzzle screen - special UI for daily challenge
class DailyPuzzleScreen extends ConsumerStatefulWidget {
  const DailyPuzzleScreen({super.key});

  @override
  ConsumerState<DailyPuzzleScreen> createState() => _DailyPuzzleScreenState();
}

class _DailyPuzzleScreenState extends ConsumerState<DailyPuzzleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDailyPuzzle();
    });
  }

  Future<void> _initializeDailyPuzzle() async {
    final notifier = ref.read(puzzleProvider.notifier);
    notifier.setModeConfig(mode: PuzzleFilterMode.daily);
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
        title: Column(
          children: [
            Text(
              'Daily Puzzle',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            Text(
              _getFormattedDate(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(state),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _buildBody(PuzzleGameState state) {
    if (state.isLoading || state.currentPuzzle == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    // Show completion screen
    if (state.state == PuzzleState.completed) {
      return _buildCompletionScreen(state);
    }

    return Column(
      children: [
        // Puzzle info
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildDailyPuzzleInfo(state),
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

        // Status messages
        if (state.errorMessage != null) _buildErrorMessage(state.errorMessage!),
        if (state.state == PuzzleState.correct) _buildSuccessMessage(),

        const SizedBox(height: 8),

        // Chess board
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _DailyPuzzleBoard(state: state, ref: ref),
              ),
            ),
          ),
        ),

        // Controls (only hint and solution, no skip)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: _buildDailyControls(state),
        ),
      ],
    );
  }

  Widget _buildDailyPuzzleInfo(PuzzleGameState state) {
    final puzzle = state.currentPuzzle!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade800, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Challenge',
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
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.close, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: AppTheme.error),
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
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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

  Widget _buildDailyControls(PuzzleGameState state) {
    final notifier = ref.read(puzzleProvider.notifier);

    return Row(
      children: [
        // Hint button
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                state.isPlayerTurn && !state.showingHint
                    ? () => notifier.showHint()
                    : null,
            icon: const Icon(Icons.lightbulb_outline, size: 20),
            label: const Text('Hint'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
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
            onPressed: () => _showAutoPlaySolution(state),
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('Solution'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionScreen(PuzzleGameState state) {
    final puzzle = state.currentPuzzle!;
    final accuracy = state.accuracy;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy icon with animation
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Congratulations!',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You completed today\'s puzzle!',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Stats
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildStatRow('Puzzle Rating', '${puzzle.rating}'),
                  const Divider(height: 24, color: AppTheme.borderColor),
                  _buildStatRow(
                    'Your Accuracy',
                    '${accuracy.toStringAsFixed(0)}%',
                  ),
                  const Divider(height: 24, color: AppTheme.borderColor),
                  _buildStatRow('Hints Used', '${state.hintsUsed}'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showAutoPlaySolution(PuzzleGameState state) {
    // Navigate to auto-play solution screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _AutoPlaySolutionScreen(puzzle: state.currentPuzzle!),
      ),
    );
  }
}

/// Daily puzzle board widget
class _DailyPuzzleBoard extends StatelessWidget {
  final PuzzleGameState state;
  final WidgetRef ref;

  const _DailyPuzzleBoard({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Board should NOT flip - keep player's perspective consistent
    final puzzle = state.currentPuzzle;
    if (puzzle == null) return const SizedBox();

    // Determine orientation from initial FEN
    // If puzzle starts with black to move, flip board
    final isFlipped = puzzle.fen.contains(' w ');

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
      onSquareTap:
          state.isPlayerTurn
              ? (square) {
                ref.read(puzzleProvider.notifier).selectSquare(square);
              }
              : null,
      onMove:
          state.isPlayerTurn
              ? (from, to) async {
                final notifier = ref.read(puzzleProvider.notifier);

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
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
    // DO NOT apply setup move - FEN is already the correct starting position
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
      // DO NOT apply setup move
      _currentMoveIndex = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _currentMoveIndex >= widget.puzzle.moves.length;
    final isFlipped = widget.puzzle.fen.contains(' w ');

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
