import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess_master/core/theme/app_theme.dart';

/// Reusable theme-aware card container for consistent elevated surfaces
/// adhering to the Grandmaster Design System.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final bool isSelected;
  final bool enableHaptics;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.space16),
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = AppTheme.radiusMd,
    this.gradient,
    this.boxShadow,
    this.isSelected = false,
    this.enableHaptics = true,
  });

  /// Hero card constructor with prominent padding and optional subtle ambient glow
  factory AppCard.hero({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppTheme.space20),
    EdgeInsetsGeometry? margin,
    Color? color,
    Color? borderColor,
    double borderRadius = AppTheme.radiusLg,
    Gradient? gradient,
    Color? glowColor,
    bool enableHaptics = true,
  }) {
    final effectiveGlow = glowColor ?? AppTheme.emeraldGreen;
    return AppCard(
      key: key,
      onTap: onTap,
      padding: padding,
      margin: margin,
      color: color,
      borderColor: borderColor ?? effectiveGlow.withValues(alpha: 0.35),
      borderRadius: borderRadius,
      gradient: gradient,
      boxShadow: [
        BoxShadow(
          color: effectiveGlow.withValues(alpha: 0.08),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ],
      enableHaptics: enableHaptics,
      child: child,
    );
  }

  /// Selectable card constructor with active visual state
  factory AppCard.selectable({
    Key? key,
    required Widget child,
    required bool isSelected,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppTheme.space12),
    EdgeInsetsGeometry? margin,
    double borderRadius = AppTheme.radiusMd,
    Color? activeBorderColor,
    bool enableHaptics = true,
  }) {
    return AppCard(
      key: key,
      onTap: onTap,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      isSelected: isSelected,
      borderColor: isSelected
          ? (activeBorderColor ?? AppTheme.emeraldGreen)
          : null,
      enableHaptics: enableHaptics,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBaseColor = isSelected
        ? (isDark
            ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
            : AppTheme.emeraldGreen.withValues(alpha: 0.08))
        : (color ?? AppTheme.surfaceLevel1(context));

    final defaultBorderColor = isSelected
        ? AppTheme.emeraldGreen
        : (borderColor ?? AppTheme.borderStroke(context));

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? defaultBaseColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: defaultBorderColor, width: isSelected ? 1.5 : 1.0),
        boxShadow: boxShadow,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (enableHaptics) {
              HapticFeedback.lightImpact();
            }
            onTap!();
          },
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppTheme.emeraldGreen.withValues(alpha: 0.12),
          highlightColor: AppTheme.emeraldGreen.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Alias for AppCard conforming to design system naming
typedef PremiumCard = AppCard;
