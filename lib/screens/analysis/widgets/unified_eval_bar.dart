import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern evaluation bar widget showing position assessment.
class UnifiedEvalBar extends StatelessWidget {
  final double evaluation; // In pawns, positive = white advantage
  final bool isMate;
  final int? mateIn;
  final bool isFlipped;
  final bool showWinPercent;

  const UnifiedEvalBar({
    super.key,
    required this.evaluation,
    this.isMate = false,
    this.mateIn,
    this.isFlipped = false,
    this.showWinPercent = true,
  });

  @override
  Widget build(BuildContext context) {
    double winPercent;
    if (isMate && mateIn != null) {
      winPercent = mateIn! > 0 ? 95.0 : 5.0;
    } else {
      winPercent = EvalConstants.centipawnsToWinPercent(evaluation * 100);
    }

    final displayPercentage = showWinPercent ? winPercent : null;
    final rawFillFraction = showWinPercent ? winPercent / 100.0 : null;

    final clampedEval = evaluation.clamp(-10.0, 10.0);
    double whiteFraction;
    if (isMate && mateIn != null) {
      whiteFraction = mateIn! > 0 ? 0.95 : 0.05;
    } else {
      whiteFraction = 0.5 + (clampedEval / 20.0);
      whiteFraction = whiteFraction.clamp(0.05, 0.95);
    }

    final fillFraction = rawFillFraction ?? whiteFraction;

    final topPercentage = isFlipped ? fillFraction : 1.0 - fillFraction;
    final topColor = isFlipped ? AppTheme.winBarWhite : AppTheme.winBarBlack;
    final bottomColor = isFlipped ? AppTheme.winBarBlack : AppTheme.winBarWhite;

    final evalText =
        displayPercentage != null
            ? '${displayPercentage.toStringAsFixed(0)}%'
            : _getEvalText();
    final textOnTop = isFlipped ? (fillFraction > 0.5) : (fillFraction < 0.5);

    return Container(
      width: 28, // Wider than original for better readability
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: bottomColor,
        border: Border.all(color: AppTheme.borderColorFor(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Bar
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: topPercentage),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, child) {
                return Column(
                  children: [
                    Expanded(
                      flex: (animValue * 1000).round(),
                      child: Container(color: topColor),
                    ),
                    Expanded(
                      flex: ((1 - animValue) * 1000).round(),
                      child: Container(color: Colors.transparent),
                    ),
                  ],
                );
              },
            ),
          ),

          // Evaluation Text
          Positioned(
            top: textOnTop ? 8 : null,
            bottom: textOnTop ? null : 8,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                evalText,
                style: GoogleFonts.inter(
                  color:
                      textOnTop
                          ? (isFlipped ? const Color(0xFF424242) : Colors.white)
                          : (isFlipped
                              ? Colors.white
                              : const Color(0xFF424242)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEvalText() {
    if (isMate && mateIn != null) {
      return mateIn! > 0 ? 'M$mateIn' : 'M${mateIn!.abs()}';
    }
    final absEval = evaluation.abs();
    if (absEval < 0.1) return '0.0';

    final sign = evaluation >= 0 ? '+' : '-';
    return '$sign${absEval.toStringAsFixed(1)}';
  }
}
