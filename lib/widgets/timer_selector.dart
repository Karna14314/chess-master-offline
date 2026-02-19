import 'package:flutter/material.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Widget for selecting time control
class TimerSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const TimerSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedControl = AppConstants.timeControls[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time Control',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getTimeControlColor(selectedControl).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getTimeControlColor(selectedControl),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 16,
                    color: _getTimeControlColor(selectedControl),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    selectedControl.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getTimeControlColor(selectedControl),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Time control grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(AppConstants.timeControls.length, (index) {
            final control = AppConstants.timeControls[index];
            final isSelected = index == selectedIndex;

            return _TimeControlChip(
              control: control,
              isSelected: isSelected,
              onTap: () => onChanged(index),
            );
          }),
        ),
      ],
    );
  }

  Color _getTimeControlColor(TimeControl control) {
    if (!control.hasTimer) return Colors.grey;
    if (control.minutes <= 2) return Colors.purple; // Bullet
    if (control.minutes <= 5) return Colors.orange; // Blitz
    if (control.minutes <= 15) return Colors.green; // Rapid
    return Colors.blue; // Classical
  }
}

class _TimeControlChip extends StatelessWidget {
  final TimeControl control;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeControlChip({
    required this.control,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();

    return Material(
      color: isSelected ? color : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                control.hasTimer
                    ? Icons.timer_rounded
                    : Icons.timer_off_rounded,
                size: 24,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(height: 4),
              Text(
                control.displayString,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_getCategory().isNotEmpty)
                Text(
                  _getCategory(),
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

  Color _getColor() {
    if (!control.hasTimer) return Colors.grey;
    if (control.minutes <= 2) return Colors.purple;
    if (control.minutes <= 5) return Colors.orange;
    if (control.minutes <= 15) return Colors.green;
    return Colors.blue;
  }

  String _getCategory() {
    if (!control.hasTimer) return '';
    if (control.minutes <= 2) return 'Bullet';
    if (control.minutes <= 5) return 'Blitz';
    if (control.minutes <= 15) return 'Rapid';
    return 'Classical';
  }
}

/// Badge to display selected time control
class TimeControlBadge extends StatelessWidget {
  final TimeControl control;
  final bool compact;

  const TimeControlBadge({
    super.key,
    required this.control,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();

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
          Icon(
            control.hasTimer ? Icons.timer_rounded : Icons.timer_off_rounded,
            size: compact ? 14 : 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            control.displayString,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    if (!control.hasTimer) return Colors.grey;
    if (control.minutes <= 2) return Colors.purple;
    if (control.minutes <= 5) return Colors.orange;
    if (control.minutes <= 15) return Colors.green;
    return Colors.blue;
  }
}
