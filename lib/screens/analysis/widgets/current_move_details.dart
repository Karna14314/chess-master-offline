import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class CurrentMoveDetails extends StatelessWidget {
  final MoveAnalysis? analysis;

  const CurrentMoveDetails({super.key, this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis == null) {
      return const SizedBox.shrink();
    }

    final classification = analysis!.classification;
    final color = Color(classification.color);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIcon(classification), color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          analysis!.san,
                          style: GoogleFonts.spaceMono(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (classification.symbol.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            classification.symbol,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      classification.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _EvalChangeWidget(evalLoss: analysis!.evalLoss, color: color),
                  const SizedBox(height: 4),
                  if (analysis!.engineLines.isNotEmpty)
                    Text(
                      'Depth ${analysis!.engineLines.first.depth}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(MoveClassification classification) {
    switch (classification) {
      case MoveClassification.blunder:
      case MoveClassification.miss:
        return Icons.error_rounded;
      case MoveClassification.mistake:
        return Icons.warning_rounded;
      case MoveClassification.inaccuracy:
        return Icons.help_outline_rounded;
      case MoveClassification.book:
        return Icons.menu_book_rounded;
      case MoveClassification.good:
        return Icons.check_circle_outline_rounded;
      case MoveClassification.excellent:
      case MoveClassification.great:
        return Icons.star_rounded;
      case MoveClassification.brilliant:
        return Icons.auto_awesome_rounded;
      case MoveClassification.best:
      case MoveClassification.forced:
      case MoveClassification.onlyMove:
        return Icons.verified_rounded;
    }
  }
}

class _EvalChangeWidget extends StatelessWidget {
  final double evalLoss;
  final Color color;

  const _EvalChangeWidget({required this.evalLoss, required this.color});

  @override
  Widget build(BuildContext context) {
    if (evalLoss.abs() <= 0.05) {
      return Text(
        '0.0',
        style: GoogleFonts.spaceMono(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      );
    }

    final isPositive = evalLoss < 0; // Negative loss = gained eval
    final displayValue = evalLoss.abs().toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          isPositive ? '+$displayValue' : '-$displayValue',
          style: GoogleFonts.spaceMono(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
