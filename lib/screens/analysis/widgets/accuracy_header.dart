import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:google_fonts/google_fonts.dart';

/// Per-side game accuracy header shown at the top of the Report tab.
class AccuracyHeader extends StatelessWidget {
  final GameAnalysis analysis;

  const AccuracyHeader({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SideAccuracy(
              label: 'White',
              accuracy: analysis.whiteAccuracy,
              swatch: AppTheme.winBarWhite,
              isDark: false,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.borderColorFor(context),
          ),
          Expanded(
            child: _SideAccuracy(
              label: 'Black',
              accuracy: analysis.blackAccuracy,
              swatch: AppTheme.winBarBlack,
              isDark: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideAccuracy extends StatelessWidget {
  final String label;
  final double accuracy;
  final Color swatch;
  final bool isDark;

  const _SideAccuracy({
    required this.label,
    required this.accuracy,
    required this.swatch,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColorFor(context)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${accuracy.toStringAsFixed(1)}%',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryFor(context),
          ),
        ),
        Text(
          'Accuracy',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textHintFor(context),
          ),
        ),
      ],
    );
  }
}
