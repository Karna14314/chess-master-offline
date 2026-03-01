import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';

/// Shared puzzle board widget for both daily and normal puzzles
class PuzzleBoardWidget extends StatelessWidget {
  final PuzzleGameState state;
  final WidgetRef ref;

  const PuzzleBoardWidget({super.key, required this.state, required this.ref});

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
