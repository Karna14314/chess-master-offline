import 'package:flutter/material.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Widget for selecting difficulty level with ELO display
class DifficultySelector extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<DifficultyLevel> onChanged;
  final bool showDetails;

  const DifficultySelector({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDifficulty = AppConstants.difficultyLevels[selectedLevel - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with current selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Difficulty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getDifficultyColor(selectedLevel).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getDifficultyColor(selectedLevel),
                  width: 1.5,
                ),
              ),
              child: Text(
                selectedDifficulty.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _getDifficultyColor(selectedLevel),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Level slider
        Row(
          children: [
            Text(
              '1',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getDifficultyColor(selectedLevel),
                  inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                  thumbColor: _getDifficultyColor(selectedLevel),
                  overlayColor: _getDifficultyColor(
                    selectedLevel,
                  ).withOpacity(0.2),
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                ),
                child: Slider(
                  value: selectedLevel.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    final level = value.round();
                    onChanged(AppConstants.difficultyLevels[level - 1]);
                  },
                ),
              ),
            ),
            Text(
              '10',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),

        // ELO display
        if (showDetails) ...[
          const SizedBox(height: 16),
          _buildDifficultyDetails(context, selectedDifficulty),
        ],

        const SizedBox(height: 16),

        // Quick select buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AppConstants.difficultyLevels.map((difficulty) {
              final isSelected = difficulty.level == selectedLevel;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _DifficultyChip(
                  difficulty: difficulty,
                  isSelected: isSelected,
                  onTap: () => onChanged(difficulty),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyDetails(
    BuildContext context,
    DifficultyLevel difficulty,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            'ELO Rating',
            '${difficulty.elo}',
            Icons.star_rounded,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
          _buildStatItem(
            context,
            'Engine Depth',
            '${difficulty.depth}',
            Icons.psychology_rounded,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
          _buildStatItem(
            context,
            'Think Time',
            '${difficulty.thinkTimeMs}ms',
            Icons.timer_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(int level) {
    if (level <= 3) return Colors.green;
    if (level <= 5) return Colors.orange;
    if (level <= 7) return Colors.deepOrange;
    return Colors.red;
  }
}

/// Compact chip for quick level selection
class _DifficultyChip extends StatelessWidget {
  final DifficultyLevel difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyChip({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getDifficultyColor(difficulty.level);

    return Material(
      color: isSelected ? color : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lv ${difficulty.level}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${difficulty.elo}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? Colors.white.withOpacity(0.8)
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(int level) {
    if (level <= 3) return Colors.green;
    if (level <= 5) return Colors.orange;
    if (level <= 7) return Colors.deepOrange;
    return Colors.red;
  }
}

/// Compact version of difficulty selector for game info display
class DifficultyBadge extends StatelessWidget {
  final DifficultyLevel difficulty;
  final bool compact;

  const DifficultyBadge({
    super.key,
    required this.difficulty,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getDifficultyColor(difficulty.level);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(Icons.psychology_rounded, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            compact
                ? 'Lv${difficulty.level}'
                : '${difficulty.name} (${difficulty.elo})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(int level) {
    if (level <= 3) return Colors.green;
    if (level <= 5) return Colors.orange;
    if (level <= 7) return Colors.deepOrange;
    return Colors.red;
  }
}
