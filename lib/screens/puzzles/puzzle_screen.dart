import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/puzzles/widgets/puzzle_info.dart';

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
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Puzzle Trainer'),
        actions: [
          // Rating display
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: AppTheme.accentColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${state.currentRating}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
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
      return const Center(child: CircularProgressIndicator());
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
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePuzzles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.currentPuzzle == null || state.board == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Puzzle info
        Padding(
          padding: const EdgeInsets.all(16),
          child: PuzzleInfo(
            puzzle: state.currentPuzzle!,
            currentRating: state.currentRating,
            streak: state.streak,
            hintsUsed: state.hintsUsed,
          ),
        ),

        // To play indicator
        ToPlayIndicator(isWhiteToPlay: state.isWhiteTurn),
        const SizedBox(height: 8),

        // Status message
        if (state.errorMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.close, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

        // Success message
        if (state.state == PuzzleState.correct)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Correct! Keep going...',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Chess board
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _PuzzleBoard(state: state, ref: ref),
              ),
            ),
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.all(16),
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
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => notifier.nextPuzzle(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                onPressed:
                    state.isPlayerTurn && !state.showingHint
                        ? () => notifier.showHint()
                        : null,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Hint'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentColor,
                  side: BorderSide(
                    color: AppTheme.accentColor.withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Show Solution button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSolutionDialog(state),
                icon: const Icon(Icons.visibility),
                label: const Text('Solution'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Skip button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSkipConfirmation(),
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.textHint),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Solution'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete solution moves:',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < puzzle.moves.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color:
                                      i % 2 == 0
                                          ? AppTheme.primaryColor.withOpacity(
                                            0.3,
                                          )
                                          : Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                puzzle.moves[i],
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight:
                                      i % 2 == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      i % 2 == 0
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                i % 2 == 0 ? '(Your move)' : '(Response)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Note: Viewing solution counts as a hint.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(puzzleProvider.notifier).showSolution();
                },
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  void _showSkipConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Skip Puzzle?'),
            content: const Text(
              'Skipping will count as an incorrect attempt and may lower your rating.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(puzzleProvider.notifier).skipPuzzle();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                child: const Text('Skip'),
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
    // Determine if board should be flipped
    // In puzzles, we want the player's pieces at the bottom
    final isFlipped = !state.isWhiteTurn;

    return ChessBoard(
      fen: state.fen,
      isFlipped: isFlipped,
      selectedSquare: state.selectedSquare,
      legalMoves: state.legalMoves,
      lastMoveFrom: state.lastMoveFrom,
      lastMoveTo: state.lastMoveTo,
      showHint: state.showingHint,
      hintSquare: state.selectedSquare,
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
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Promote Pawn'),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getPieceSymbol(), style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
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
