import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/puzzles/widgets/puzzle_board_widget.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Puzzle training screen
class PuzzleScreen extends ConsumerStatefulWidget {
  final int? puzzleId;
  const PuzzleScreen({super.key, this.puzzleId});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePuzzles();
    });
  }

  @override
  void dispose() {
    // Reset orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _initializePuzzles() async {
    final notifier = ref.read(puzzleProvider.notifier);
    await notifier.initialize();
    
    if (widget.puzzleId != null) {
      await notifier.loadPuzzleById(widget.puzzleId!);
    } else if (ref.read(puzzleProvider).currentPuzzle == null) {
      await notifier.startNewPuzzle();
    }
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

        // Status message container with fixed height to prevent shaking
        SizedBox(
          height: 50,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStatusWidget(state),
            ),
          ),
        ),

        // Chess board
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: PuzzleBoardWidget(state: state, ref: ref),
            ),
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: _buildControls(state),
        ),
      ],
    );
  }

  Widget _buildStatusWidget(PuzzleGameState state) {
    if (state.state == PuzzleState.incorrect) {
      return Container(
        key: const ValueKey('incorrect'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close, color: AppTheme.error, size: 18),
            const SizedBox(width: 8),
            Text(
              state.errorMessage ?? "Wrong Move! Try Again",
              style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    
    if (state.state == PuzzleState.correct || state.state == PuzzleState.completed) {
      return Container(
        key: const ValueKey('correct'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              state.state == PuzzleState.completed ? "Puzzle Solved!" : "Correct!",
              style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Text(
      state.isWhiteTurn ? "White to Move" : "Black to Move",
      key: const ValueKey('turn'),
      style: GoogleFonts.inter(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildControls(PuzzleGameState state) {
    final notifier = ref.read(puzzleProvider.notifier);
    final isFailed = state.state == PuzzleState.incorrect;
    final isCompleted = state.state == PuzzleState.completed;

    if (isFailed || isCompleted) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => notifier.retryPuzzle(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => notifier.nextPuzzle(),
              icon: const Icon(Icons.arrow_forward),
              label: Text(isCompleted ? 'Next Puzzle' : 'Skip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => notifier.showHint(),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Hint'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSolutionDialog(state),
            icon: const Icon(Icons.visibility),
            label: const Text('Solution'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPuzzleInfoCard(PuzzleGameState state) {
    final puzzle = state.currentPuzzle!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Puzzle #${puzzle.id}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rating: ${puzzle.rating}',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: puzzle.themes.take(2).map((theme) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(theme, style: const TextStyle(fontSize: 10, color: AppTheme.primaryLight)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  void _showSolutionDialog(PuzzleGameState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Show Solution?'),
        content: const Text('Showing the solution will end the puzzle attempt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {Navigator.pop(context); ref.read(puzzleProvider.notifier).showSolution();}, child: const Text('Show')),
        ],
      ),
    );
  }
}
