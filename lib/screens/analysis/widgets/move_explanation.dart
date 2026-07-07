import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class MoveExplanation extends StatelessWidget {
  final MoveAnalysis? analysis;

  const MoveExplanation({super.key, this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis == null) return const SizedBox.shrink();

    final classification = analysis!.classification;
    final color = Color(classification.color);

    // Rule-based explanation generator
    final explanationText = _generateExplanation(analysis!);

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
              Icon(Icons.lightbulb_outline_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Move Explanation',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanationText,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (analysis!.bestMoveSan != null &&
              classification != MoveClassification.best) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.textHint,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Better was ${analysis!.bestMoveSan}',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _generateExplanation(MoveAnalysis analysis) {
    final c = analysis.classification;
    final loss = analysis.evalLoss;

    switch (c) {
      case MoveClassification.best:
        return 'This is the best move in the position. It maximizes your advantage or defends optimally.';
      case MoveClassification.excellent:
      case MoveClassification.great:
        return 'An excellent find. This move maintains strong pressure and improves your position significantly.';
      case MoveClassification.brilliant:
        return 'A brilliant move! This involves a deep tactical sacrifice or a profound positional idea that leads to a winning advantage.';
      case MoveClassification.good:
        return 'A solid, completely fine move, though the engine might slightly prefer an alternative.';
      case MoveClassification.book:
        return 'This is a recognized move in the opening theory.';
      case MoveClassification.inaccuracy:
        return 'This move is slightly inaccurate. It does not ruin your position, but it gives away a small advantage or misses a better opportunity.';
      case MoveClassification.mistake:
        return 'A mistake. This move loses a significant amount of the evaluation advantage (dropping ${loss.abs().toStringAsFixed(1)} pawns in eval).';
      case MoveClassification.blunder:
        return 'A blunder. This move drastically changes the evaluation in your opponent\'s favor, potentially dropping material or allowing a decisive attack.';
      case MoveClassification.miss:
        return 'This move misses a critical tactical opportunity or a chance to punish an opponent\'s mistake.';
      case MoveClassification.forced:
      case MoveClassification.onlyMove:
        return 'This was the only legal or logical move to avoid immediate disaster.';
    }
  }
}
