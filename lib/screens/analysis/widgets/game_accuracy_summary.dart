import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class GameAccuracySummary extends StatelessWidget {
  final GameAnalysis analysis;
  final String? openingName;

  /// True while the batch analysis is still running. The figure shown is then
  /// only over the plies analysed so far, so it is labelled as provisional to
  /// stop users reading a mid-run number as the final score.
  final bool isInProgress;

  const GameAccuracySummary({
    super.key,
    required this.analysis,
    this.openingName,
    this.isInProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final accuracyStr = analysis.averageAccuracy.toStringAsFixed(1);
    final isExcellent = !isInProgress && analysis.averageAccuracy >= 90;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with accuracy + per-side
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isExcellent ? Colors.blue : AppTheme.primaryColor)
                      .withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExcellent
                      ? Icons.military_tech_rounded
                      : Icons.analytics_rounded,
                  color: isExcellent ? Colors.blue : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$accuracyStr%',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    Text(
                      isInProgress
                          ? 'Accuracy so far — analyzing…'
                          : (isExcellent
                              ? 'Outstanding Accuracy'
                              : 'Game Review'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isInProgress
                            ? AppTheme.textHintFor(context)
                            : (isExcellent
                                ? Colors.blue
                                : AppTheme.textSecondaryFor(context)),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Per-side accuracy
              Column(
                children: [
                  _MiniSideAccuracy(
                    label: 'W',
                    accuracy: analysis.whiteAccuracy,
                    color: AppTheme.winBarWhite,
                  ),
                  const SizedBox(height: 4),
                  _MiniSideAccuracy(
                    label: 'B',
                    accuracy: analysis.blackAccuracy,
                    color: AppTheme.winBarBlack,
                  ),
                ],
              ),
            ],
          ),

          if (openingName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.book_rounded, color: AppTheme.textHintFor(context), size: 16),
                const SizedBox(width: 6),
                Text(
                  openingName!,
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryFor(context)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Compact stat chips in a single wrap row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (analysis.brilliantMoves > 0)
                _CompactChip(label: 'Brilliant', value: analysis.brilliantMoves, color: Color(MoveClassification.brilliant.color)),
              if (analysis.greatMoves > 0)
                _CompactChip(label: 'Great', value: analysis.greatMoves, color: Color(MoveClassification.great.color)),
              if (analysis.bestMoves > 0)
                _CompactChip(label: 'Best', value: analysis.bestMoves, color: Color(MoveClassification.best.color)),
              if (analysis.excellentMoves > 0)
                _CompactChip(label: 'Excellent', value: analysis.excellentMoves, color: Color(MoveClassification.excellent.color)),
              if (analysis.goodMoves > 0)
                _CompactChip(label: 'Good', value: analysis.goodMoves, color: Color(MoveClassification.good.color)),
              if (analysis.inaccuracies > 0)
                _CompactChip(label: 'Inaccuracy', value: analysis.inaccuracies, color: Color(MoveClassification.inaccuracy.color)),
              if (analysis.mistakes > 0)
                _CompactChip(label: 'Mistake', value: analysis.mistakes, color: Color(MoveClassification.mistake.color)),
              if (analysis.misses > 0)
                _CompactChip(label: 'Miss', value: analysis.misses, color: Color(MoveClassification.miss.color)),
              if (analysis.blunders > 0)
                _CompactChip(label: 'Blunder', value: analysis.blunders, color: Color(MoveClassification.blunder.color)),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Avg CPL: ${analysis.averageCpl.toInt()}',
            style: GoogleFonts.inter(color: AppTheme.textHintFor(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MiniSideAccuracy extends StatelessWidget {
  final String label;
  final double accuracy;
  final Color color;

  const _MiniSideAccuracy({
    required this.label,
    required this.accuracy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '${accuracy.toStringAsFixed(0)}%',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryFor(context),
          ),
        ),
      ],
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CompactChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}


