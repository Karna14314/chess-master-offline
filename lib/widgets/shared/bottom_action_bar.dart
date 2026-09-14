import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';

/// Thumb-zone in-game action bar container with standardized button slots.
class BottomActionBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const BottomActionBar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTheme.space16, vertical: AppTheme.space8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLevel1(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderStroke(context),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Action bar icon button with label, haptic feedback, and tooltip
class BottomActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isHighlighted;
  final Color? customColor;

  const BottomActionItem({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isHighlighted = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final isEnabled = onPressed != null;

    final effectiveColor = !isEnabled
        ? textSecondary.withValues(alpha: 0.3)
        : (isHighlighted ? AppTheme.emeraldGreen : (customColor ?? textPrimary));

    return InkWell(
      onTap: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: effectiveColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
