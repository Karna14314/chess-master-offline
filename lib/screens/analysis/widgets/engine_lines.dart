import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/models/analysis_model.dart';

/// Widget displaying top engine lines
class EngineLines extends StatelessWidget {
  final List<EngineLine> lines;
  final bool isLoading;

  const EngineLines({super.key, required this.lines, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Analyzing...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No engine lines available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Engine Analysis',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (lines.isNotEmpty)
                  Text(
                    'Depth ${lines.first.depth}',
                    style: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceDark),
          ...lines.map((line) => _EngineLineRow(line: line)),
        ],
      ),
    );
  }
}

class _EngineLineRow extends StatelessWidget {
  final EngineLine line;

  const _EngineLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final isPositive =
        line.isMate ? (line.mateIn ?? 0) > 0 : line.evaluation >= 0;

    final evalColor = isPositive ? Colors.white : Colors.grey[800];
    final evalBgColor = isPositive ? AppTheme.surfaceDark : Colors.white;
    final evalTextColor = isPositive ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceDark, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Rank indicator
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  line.rank == 1
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${line.rank}',
              style: TextStyle(
                color:
                    line.rank == 1 ? AppTheme.primaryColor : AppTheme.textHint,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Evaluation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: evalBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              line.evalDisplay,
              style: TextStyle(
                color: evalTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Moves
          Expanded(
            child: Text(
              line.getMovePreview(count: 6),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Best move indicator widget
class BestMoveIndicator extends StatelessWidget {
  final String? bestMove;
  final String? bestMoveSan;

  const BestMoveIndicator({super.key, this.bestMove, this.bestMoveSan});

  @override
  Widget build(BuildContext context) {
    if (bestMove == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppTheme.primaryColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'Best: ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            bestMoveSan ?? bestMove!,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
