import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';

/// Evaluation bar widget showing position assessment
class EvalBar extends StatelessWidget {
  final double evaluation; // In pawns, positive = white advantage
  final bool isVertical;
  final bool isMate;
  final int? mateIn;

  const EvalBar({
    super.key,
    required this.evaluation,
    this.isVertical = true,
    this.isMate = false,
    this.mateIn,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp evaluation between -10 and +10 for display
    final clampedEval = evaluation.clamp(-10.0, 10.0);

    // Convert to percentage (0.0 to 1.0 where 0.5 is equal)
    // When eval is +10, white portion should be ~90%
    // When eval is -10, white portion should be ~10%
    double whitePercentage;

    if (isMate && mateIn != null) {
      whitePercentage = mateIn! > 0 ? 0.95 : 0.05;
    } else {
      // Sigmoid-like transformation for smoother display
      whitePercentage = 0.5 + (clampedEval / 20.0);
      whitePercentage = whitePercentage.clamp(0.05, 0.95);
    }

    final evalText = _getEvalText();

    if (isVertical) {
      return Container(
        width: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Column(
            children: [
              // Black portion (top)
              Expanded(
                flex: ((1 - whitePercentage) * 100).round(),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child:
                      whitePercentage < 0.5
                          ? RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              evalText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          : null,
                ),
              ),
              // White portion (bottom)
              Expanded(
                flex: (whitePercentage * 100).round(),
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child:
                      whitePercentage >= 0.5
                          ? RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              evalText,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          : null,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Horizontal version
      return Container(
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              // White portion (left)
              Expanded(
                flex: (whitePercentage * 100).round(),
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child:
                      whitePercentage >= 0.5
                          ? Text(
                            evalText,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
              ),
              // Black portion (right)
              Expanded(
                flex: ((1 - whitePercentage) * 100).round(),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child:
                      whitePercentage < 0.5
                          ? Text(
                            evalText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
              ),
            ],
          ),
        ),
      );
    }
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

/// Large evaluation display for analysis screen
class EvalDisplay extends StatelessWidget {
  final double evaluation;
  final bool isMate;
  final int? mateIn;

  const EvalDisplay({
    super.key,
    required this.evaluation,
    this.isMate = false,
    this.mateIn,
  });

  @override
  Widget build(BuildContext context) {
    final isWhiteAdvantage = isMate ? (mateIn ?? 0) > 0 : evaluation >= 0;
    final color = isWhiteAdvantage ? Colors.white : Colors.black;
    final bgColor = isWhiteAdvantage ? AppTheme.cardDark : Colors.white;
    final textColor = isWhiteAdvantage ? Colors.white : Colors.black;

    String evalText;
    if (isMate && mateIn != null) {
      evalText = mateIn! > 0 ? 'M$mateIn' : '-M${mateIn!.abs()}';
    } else {
      final absEval = evaluation.abs();
      final sign = evaluation >= 0 ? '+' : '-';
      evalText = '$sign${absEval.toStringAsFixed(2)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[400]!, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            evalText,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
