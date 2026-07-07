import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern evaluation bar widget showing position assessment.
class UnifiedEvalBar extends StatelessWidget {
  final double evaluation; // In pawns, positive = white advantage
  final bool isMate;
  final int? mateIn;
  final bool isFlipped;

  const UnifiedEvalBar({
    super.key,
    required this.evaluation,
    this.isMate = false,
    this.mateIn,
    this.isFlipped = false,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp evaluation between -10 and +10 for display purposes
    final clampedEval = evaluation.clamp(-10.0, 10.0);

    // Convert to percentage (0.0 to 1.0 where 0.5 is equal)
    double whitePercentage;

    if (isMate && mateIn != null) {
      whitePercentage = mateIn! > 0 ? 0.95 : 0.05;
    } else {
      // Use a curve so that central values are more responsive
      whitePercentage = 0.5 + (clampedEval / 20.0);
      whitePercentage = whitePercentage.clamp(0.05, 0.95);
    }

    // If flipped, reverse the visual representation (black on bottom)
    final topPercentage = isFlipped ? whitePercentage : 1.0 - whitePercentage;
    final topColor = isFlipped ? Colors.white : const Color(0xFF303030);
    final bottomColor = isFlipped ? const Color(0xFF303030) : Colors.white;

    final evalText = _getEvalText();
    final textOnTop =
        isFlipped ? (whitePercentage > 0.5) : (whitePercentage < 0.5);

    return Container(
      width: 24, // Wider than original for better readability
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: bottomColor,
        border: Border.all(color: AppTheme.borderColor, width: 1),
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
                          ? (isFlipped ? Colors.black : Colors.white)
                          : (isFlipped ? Colors.white : Colors.black),
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
