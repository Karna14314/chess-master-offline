import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/statistics_model.dart';

/// Grandmaster Design System standardized badge / pill component
class AppBadge extends StatelessWidget {
  final String label;
  final Widget? leading;
  final Color color;
  final Color? textColor;
  final Color? backgroundColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool outlineOnly;

  const AppBadge({
    super.key,
    required this.label,
    this.leading,
    required this.color,
    this.textColor,
    this.backgroundColor,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTheme.space8, vertical: 3),
    this.outlineOnly = false,
  });

  /// Streak flame badge (e.g. "🔥 5 Days")
  factory AppBadge.streak({
    Key? key,
    required int streakDays,
    bool isActiveToday = true,
  }) {
    final color = isActiveToday ? const Color(0xFFFF6D00) : Colors.orange;
    final dayLabel = streakDays == 1 ? 'Day' : 'Days';
    return AppBadge(
      key: key,
      label: '$streakDays $dayLabel',
      leading: const Text('🔥', style: TextStyle(fontSize: 12)),
      color: color,
      backgroundColor: color.withValues(alpha: isActiveToday ? 0.18 : 0.10),
      textColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  /// Crown Stars badge (e.g. "★ 24")
  factory AppBadge.stars({
    Key? key,
    required int stars,
  }) {
    return AppBadge(
      key: key,
      label: '$stars',
      leading: const Icon(Icons.star_rounded, size: 14, color: AppTheme.amberGold),
      color: AppTheme.amberGold,
      backgroundColor: AppTheme.amberGold.withValues(alpha: 0.15),
      textColor: const Color(0xFFD97706),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    );
  }

  /// ELO Rating badge (e.g. "1200 ELO")
  factory AppBadge.elo({
    Key? key,
    required int elo,
    Color? customColor,
  }) {
    final tierColor = customColor ?? StatisticsModel.getRatingColor(elo);

    return AppBadge(
      key: key,
      label: '$elo ELO',
      color: tierColor,
      backgroundColor: tierColor.withValues(alpha: 0.15),
      textColor: tierColor,
      fontSize: 10,
    );
  }

  /// Achievement rarity badge (Common, Rare, Epic, Legendary, Master)
  factory AppBadge.rarity({
    Key? key,
    required String rarityName,
    required Color rarityColor,
  }) {
    return AppBadge(
      key: key,
      label: rarityName.toUpperCase(),
      color: rarityColor,
      backgroundColor: rarityColor.withValues(alpha: 0.15),
      textColor: rarityColor,
      fontSize: 9,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }

  /// Semantic status badge (Success, Warning, Danger, Info)
  factory AppBadge.status({
    Key? key,
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return AppBadge(
      key: key,
      label: label,
      leading: icon != null ? Icon(icon, size: 12, color: color) : null,
      color: color,
      backgroundColor: color.withValues(alpha: 0.15),
      textColor: color,
      fontSize: 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.15);
    final textCol = textColor ?? color;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: outlineOnly ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppTheme.space4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textCol,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
