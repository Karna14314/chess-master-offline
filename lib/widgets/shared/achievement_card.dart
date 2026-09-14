import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/widgets/shared/app_card.dart';

enum AchievementRarity {
  bronze('Bronze', Color(0xFFCD7F32)),
  silver('Silver', Color(0xFFC0C0C0)),
  gold('Gold', Color(0xFFFFD700)),
  epic('Epic', Color(0xFF8B5CF6)),
  legendary('Legendary', Color(0xFFF59E0B));

  final String label;
  final Color color;
  const AchievementRarity(this.label, this.color);
}

class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final String? progressText;
  final VoidCallback? onTap;

  const AchievementCard({
    super.key,
    required this.achievement,
    this.progressText,
    this.onTap,
  });

  AchievementRarity get rarity {
    final id = achievement.id;
    if (id.contains('legendary') || id.contains('grandmaster') || id.contains('500') || id.contains('streak_30')) {
      return AchievementRarity.legendary;
    }
    if (id.contains('epic') || id.contains('200') || id.contains('10') || id.contains('streak_14')) {
      return AchievementRarity.epic;
    }
    if (id.contains('gold') || id.contains('100') || id.contains('master') || id.contains('streak_7')) {
      return AchievementRarity.gold;
    }
    if (id.contains('silver') || id.contains('50') || id.contains('5') || id.contains('streak_3')) {
      return AchievementRarity.silver;
    }
    return AchievementRarity.bronze;
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final rarityColor = rarity.color;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space12),
      borderRadius: AppTheme.radiusMd,
      borderColor: isUnlocked ? rarityColor.withValues(alpha: 0.35) : null,
      color: isUnlocked
          ? null
          : AppTheme.surfaceLevel1(context).withValues(alpha: 0.6),
      child: Row(
        children: [
          // Trophy Icon / Badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? rarityColor.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              border: Border.all(
                color: isUnlocked
                    ? rarityColor.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Icon(
              isUnlocked ? achievement.icon : Icons.lock_outline_rounded,
              color: isUnlocked ? rarityColor : Colors.grey[500],
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.space12),

          // Title & Description
          Expanded(
            child: Opacity(
              opacity: isUnlocked ? 1.0 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          achievement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          rarity.label,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: rarityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    achievement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  if (isUnlocked && achievement.unlockedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Unlocked ${achievement.unlockedDate}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: rarityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (!isUnlocked && progressText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      progressText!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
