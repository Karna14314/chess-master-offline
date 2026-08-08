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
    // Don't award the "outstanding" treatment to a partial figure.
    final isExcellent = !isInProgress && analysis.averageAccuracy >= 90;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$accuracyStr%',
                      style: GoogleFonts.inter(
                        fontSize: 28,
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
                        fontSize: 14,
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
            ],
          ),

          if (openingName != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.book_rounded,
                    color: AppTheme.textHintFor(context),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opening',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textHintFor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          openingName!,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppTheme.textPrimaryFor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              if (analysis.brilliantMoves > 0)
                _StatChip(
                  label: 'Brilliant',
                  value: analysis.brilliantMoves.toString(),
                  color: Color(MoveClassification.brilliant.color),
                  icon: Icons.auto_awesome_rounded,
                ),
              if (analysis.greatMoves > 0)
                _StatChip(
                  label: 'Great',
                  value: analysis.greatMoves.toString(),
                  color: Color(MoveClassification.great.color),
                  icon: Icons.star_rounded,
                ),
              _StatChip(
                label: 'Best Move',
                value: analysis.bestMoves.toString(),
                color: Color(MoveClassification.best.color),
                icon: Icons.verified_rounded,
              ),
              _StatChip(
                label: 'Excellent',
                value: analysis.excellentMoves.toString(),
                color: Color(MoveClassification.excellent.color),
                icon: Icons.thumb_up_rounded,
              ),
              _StatChip(
                label: 'Good',
                value: analysis.goodMoves.toString(),
                color: Color(MoveClassification.good.color),
                icon: Icons.check_circle_outline_rounded,
              ),
              // Book moves are not detected yet (no opening database), so the
              // chip stays hidden rather than always reporting zero.
              if (analysis.bookMoves > 0)
                _StatChip(
                  label: 'Book',
                  value: analysis.bookMoves.toString(),
                  color: Color(MoveClassification.book.color),
                  icon: Icons.menu_book_rounded,
                ),
              _StatChip(
                label: 'Inaccuracy',
                value: analysis.inaccuracies.toString(),
                color: Color(MoveClassification.inaccuracy.color),
                icon: Icons.help_outline_rounded,
              ),
              _StatChip(
                label: 'Mistake',
                value: analysis.mistakes.toString(),
                color: Color(MoveClassification.mistake.color),
                icon: Icons.warning_rounded,
              ),
              if (analysis.misses > 0)
                _StatChip(
                  label: 'Miss',
                  value: analysis.misses.toString(),
                  color: Color(MoveClassification.miss.color),
                  icon: Icons.cancel_outlined,
                ),
              _StatChip(
                label: 'Blunder',
                value: analysis.blunders.toString(),
                color: Color(MoveClassification.blunder.color),
                icon: Icons.error_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Avg Centipawn Loss: ${analysis.averageCpl.toInt()}',
              style: GoogleFonts.inter(color: AppTheme.textHintFor(context), fontSize: 13),
            ),
          ),

          if (analysis.moves.length > 10) ...[
            const SizedBox(height: 16),
            Divider(color: AppTheme.borderColorFor(context)),
            const SizedBox(height: 12),
            Text(
              'Accuracy by Phase',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 10),
            _PhaseAccuracyRow(
              label: 'Opening',
              accuracy: analysis.openingAccuracy,
              color: const Color(0xFF8E24AA),
              icon: Icons.menu_book_outlined,
            ),
            const SizedBox(height: 6),
            _PhaseAccuracyRow(
              label: 'Middlegame',
              accuracy: analysis.middlegameAccuracy,
              color: const Color(0xFF1E88E5),
              icon: Icons.psychology_outlined,
            ),
            const SizedBox(height: 6),
            _PhaseAccuracyRow(
              label: 'Endgame',
              accuracy: analysis.endgameAccuracy,
              color: const Color(0xFF43A047),
              icon: Icons.flag_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseAccuracyRow extends StatelessWidget {
  final String label;
  final double accuracy;
  final Color color;
  final IconData icon;

  const _PhaseAccuracyRow({
    required this.label,
    required this.accuracy,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pct = accuracy.clamp(0.0, 100.0);
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${pct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
