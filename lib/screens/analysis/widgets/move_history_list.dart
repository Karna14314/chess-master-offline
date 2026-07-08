import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/constants/app_constants.dart';

class MoveHistoryList extends StatelessWidget {
  final List<ChessMove> moves;
  final List<MoveAnalysis> analyzedMoves;
  final int currentIndex;
  final ValueChanged<int> onMoveSelected;

  const MoveHistoryList({
    super.key,
    required this.moves,
    required this.analyzedMoves,
    required this.currentIndex,
    required this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) return const SizedBox.shrink();

    // Group moves into pairs (White, Black)
    final pairs = <List<int>>[];
    for (int i = 0; i < moves.length; i += 2) {
      if (i + 1 < moves.length) {
        pairs.add([i, i + 1]);
      } else {
        pairs.add([i]);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.list_alt_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Move History',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.surfaceDark),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(pairs.length, (index) {
              final moveNumber = index + 1;
              final pair = pairs[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$moveNumber.',
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.textHint,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _MoveChip(
                      moveIndex: pair[0],
                      move: moves[pair[0]],
                      analysis: _getAnalysis(pair[0]),
                      isSelected: currentIndex == pair[0],
                      onTap: () => onMoveSelected(pair[0]),
                    ),
                    if (pair.length > 1) ...[
                      const SizedBox(width: 4),
                      _MoveChip(
                        moveIndex: pair[1],
                        move: moves[pair[1]],
                        analysis: _getAnalysis(pair[1]),
                        isSelected: currentIndex == pair[1],
                        onTap: () => onMoveSelected(pair[1]),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  MoveAnalysis? _getAnalysis(int index) {
    if (index < analyzedMoves.length) {
      return analyzedMoves[index];
    }
    return null;
  }
}

class _MoveChip extends StatelessWidget {
  final int moveIndex;
  final ChessMove move;
  final MoveAnalysis? analysis;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoveChip({
    required this.moveIndex,
    required this.move,
    required this.analysis,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor = isSelected ? Colors.white : AppTheme.textPrimary;
    Color bgColor = isSelected ? AppTheme.primaryColor : Colors.transparent;

    if (analysis != null && !isSelected) {
      final cColor = Color(analysis!.classification.color);
      // Highlight blunders/mistakes/brilliant even if not selected
      if (analysis!.classification == MoveClassification.blunder ||
          analysis!.classification == MoveClassification.mistake ||
          analysis!.classification == MoveClassification.brilliant) {
        textColor = cColor;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              move.san,
              style: GoogleFonts.spaceMono(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (analysis != null &&
                analysis!.classification.symbol.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                analysis!.classification.symbol,
                style: GoogleFonts.inter(
                  color:
                      isSelected
                          ? Colors.white
                          : Color(analysis!.classification.color),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
