import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outlined, ghost }

enum AppButtonSize { small, medium, large }

/// Grandmaster Design System standardized button component
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isFullWidth;
  final bool isLoading;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  }) : variant = AppButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = customColor ?? AppTheme.emeraldGreen;

    double height;
    double fontSize;
    EdgeInsets padding;
    double iconSize;

    switch (size) {
      case AppButtonSize.small:
        height = 36;
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: AppTheme.space12);
        iconSize = 16;
        break;
      case AppButtonSize.medium:
        height = 46;
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: AppTheme.space16);
        iconSize = 18;
        break;
      case AppButtonSize.large:
        height = 54;
        fontSize = 16;
        padding = const EdgeInsets.symmetric(horizontal: AppTheme.space24);
        iconSize = 22;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.primary ? Colors.white : baseColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: AppTheme.space8),
        ],
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: baseColor,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: baseColor.withValues(alpha: 0.4),
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppTheme.surfaceLevel2(context)
                : AppTheme.surfaceLevel2(context),
            foregroundColor: AppTheme.textPrimaryFor(context),
            elevation: 0,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(color: AppTheme.borderStroke(context)),
            ),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: baseColor,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            side: BorderSide(color: baseColor.withValues(alpha: 0.6), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.ghost:
        button = TextButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          style: TextButton.styleFrom(
            foregroundColor: baseColor,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: content,
        );
        break;
    }

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Primary button shortcut conforming to design system
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonSize size;
  final bool isFullWidth;
  final bool isLoading;
  final Color? customColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.primary(
      label: label,
      onPressed: onPressed,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      customColor: customColor,
    );
  }
}

/// Secondary button shortcut conforming to design system
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonSize size;
  final bool isFullWidth;
  final bool isLoading;
  final Color? customColor;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      label: label,
      onPressed: onPressed,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      customColor: customColor,
    );
  }
}
