import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class GameAccuracySummary extends StatelessWidget {
  final GameAnalysis analysis;
  final String? openingName;

  const GameAccuracySummary({
    super.key,
    required this.analysis,
    this.openingName,
  });

  @override
  Widget build(BuildContext context) {
    final accuracyStr = analysis.averageAccuracy.toStringAsFixed(1);
    final isExcellent = analysis.averageAccuracy >= 90;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
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
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isExcellent ? 'Outstanding Accuracy' : 'Game Review',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color:
                            isExcellent ? Colors.blue : AppTheme.textSecondary,
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
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.book_rounded,
                    color: AppTheme.textHint,
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
                            color: AppTheme.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          openingName!,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
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
              style: GoogleFonts.inter(color: AppTheme.textHint, fontSize: 13),
            ),
          ),
        ],
      ),
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
