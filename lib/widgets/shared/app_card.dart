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
    this.borderRadius = AppTheme.radiusLg,
    this.gradient,
    this.boxShadow,
    this.isSelected = false,
    this.enableHaptics = true,
  });

  /// Hero card constructor with flat surface styling and subtle primary highlight when active
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
    List<BoxShadow>? boxShadow,
    Color? glowColor,
    bool enableHaptics = true,
  }) {
    return AppCard(
      key: key,
      onTap: onTap,
      padding: padding,
      margin: margin,
      color: color,
      borderColor: borderColor,
      borderRadius: borderRadius,
      gradient: gradient,
      boxShadow: boxShadow,
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
    double borderRadius = AppTheme.radiusLg,
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
          ? (activeBorderColor ?? AppTheme.primaryColor)
          : null,
      enableHaptics: enableHaptics,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultBaseColor = isSelected
        ? AppTheme.primaryColor.withValues(alpha: 0.12)
        : (color ?? AppTheme.surfaceLevel1(context));

    final effectiveBorderColor = isSelected
        ? AppTheme.primaryColor
        : borderColor;

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? defaultBaseColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorderColor != null
            ? Border.all(color: effectiveBorderColor, width: isSelected ? 1.5 : 1.0)
            : null,
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
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          highlightColor: AppTheme.primaryColor.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Alias for AppCard conforming to design system naming
typedef PremiumCard = AppCard;
