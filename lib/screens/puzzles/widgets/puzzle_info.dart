import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/puzzle_model.dart';

/// Puzzle information display widget
class PuzzleInfo extends StatelessWidget {
  final Puzzle puzzle;
  final int currentRating;
  final int streak;
  final int hintsUsed;

  const PuzzleInfo({
    super.key,
    required this.puzzle,
    required this.currentRating,
    required this.streak,
    required this.hintsUsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating row
          Row(
            children: [
              _InfoChip(
                icon: Icons.star,
                label: 'Puzzle',
                value: '${puzzle.rating}',
                color: _getRatingColor(puzzle.rating),
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: Icons.trending_up,
                label: 'Your Rating',
                value: '$currentRating',
                color: _getRatingColor(currentRating),
              ),
              const Spacer(),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppTheme.accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Themes row
          if (puzzle.themes.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: puzzle.themes.take(4).map((theme) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTheme(theme),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating < 1200) return Colors.green;
    if (rating < 1600) return Colors.blue;
    if (rating < 2000) return Colors.purple;
    if (rating < 2400) return Colors.orange;
    return Colors.red;
  }

  String _formatTheme(String theme) {
    // Convert camelCase to Title Case
    final words = theme.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return words
        .trim()
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Puzzle result dialog
class PuzzleResultDialog extends StatelessWidget {
  final bool solved;
  final int ratingChange;
  final int newRating;
  final int streak;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  const PuzzleResultDialog({
    super.key,
    required this.solved,
    required this.ratingChange,
    required this.newRating,
    required this.streak,
    required this.onNext,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = ratingChange >= 0;

    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Result icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: solved
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                solved ? Icons.check_circle : Icons.cancel,
                color: solved ? Colors.green : Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              solved ? 'Puzzle Solved!' : 'Incorrect',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Rating change
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Rating: ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
                Text(
                  '$newRating',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPositive ? '+$ratingChange' : '$ratingChange',
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Streak
            if (solved && streak > 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streak puzzle streak!',
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                if (!solved)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onRetry();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.textHint),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                if (!solved) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onNext();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Next Puzzle'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// To play indicator
class ToPlayIndicator extends StatelessWidget {
  final bool isWhiteToPlay;

  const ToPlayIndicator({super.key, required this.isWhiteToPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWhiteToPlay ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isWhiteToPlay ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isWhiteToPlay ? 'White' : 'Black'} to play',
            style: TextStyle(
              color: isWhiteToPlay ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
