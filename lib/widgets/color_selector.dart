import 'package:flutter/material.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Widget for selecting player color (White/Black/Random)
class ColorSelector extends StatelessWidget {
  final PlayerColor selectedColor;
  final ValueChanged<PlayerColor> onChanged;

  const ColorSelector({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Play as',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: PlayerColor.values.map((color) {
            final isSelected = color == selectedColor;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: color != PlayerColor.random ? 8 : 0,
                ),
                child: _ColorOptionCard(
                  color: color,
                  isSelected: isSelected,
                  onTap: () => onChanged(color),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ColorOptionCard extends StatelessWidget {
  final PlayerColor color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOptionCard({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 4 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPieceIcon(context),
              const SizedBox(height: 8),
              Text(
                color.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieceIcon(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    switch (color) {
      case PlayerColor.white:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '♔',
              style: TextStyle(fontSize: 28, color: Colors.black87),
            ),
          ),
        );
      case PlayerColor.black:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade600, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '♚',
              style: TextStyle(fontSize: 28, color: Colors.white),
            ),
          ),
        );
      case PlayerColor.random:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade800],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.shuffle_rounded, size: 28, color: iconColor),
          ),
        );
    }
  }
}

/// Compact badge for displaying selected color
class ColorBadge extends StatelessWidget {
  final PlayerColor color;
  final bool compact;

  const ColorBadge({super.key, required this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: _getBorderColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 14 : 16,
            height: compact ? 14 : 16,
            decoration: BoxDecoration(
              color: color == PlayerColor.white
                  ? Colors.white
                  : color == PlayerColor.black
                  ? Colors.grey.shade800
                  : null,
              gradient: color == PlayerColor.random
                  ? LinearGradient(colors: [Colors.white, Colors.grey.shade800])
                  : null,
              shape: BoxShape.circle,
              border: Border.all(color: _getBorderColor(), width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            color.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (color) {
      case PlayerColor.white:
        return Colors.grey.shade300;
      case PlayerColor.black:
        return Colors.grey.shade700;
      case PlayerColor.random:
        return Colors.purple;
    }
  }

  Color _getBorderColor() {
    switch (color) {
      case PlayerColor.white:
        return Colors.grey.shade400;
      case PlayerColor.black:
        return Colors.grey.shade600;
      case PlayerColor.random:
        return Colors.purple;
    }
  }
}
