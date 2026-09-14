import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/bot_avatar.dart';

/// Personality-driven Bot Opponent Card.
/// Supports tap-to-inspect (modal sheet) and 1-tap direct "Play" button.
class BotCard extends StatelessWidget {
  final BotProfile bot;
  final int stars;
  final String? recordText;
  final VoidCallback? onInspect;
  final VoidCallback? onPlay;
  final bool isFeatured;

  const BotCard({
    super.key,
    required this.bot,
    this.stars = 0,
    this.recordText,
    this.onInspect,
    this.onPlay,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final tierColor = bot.tier.color;

    if (isFeatured) {
      return _buildFeaturedCard(context, textPrimary, textSecondary, tierColor);
    }

    return AppCard(
      onTap: onInspect,
      padding: const EdgeInsets.all(AppTheme.space12),
      borderRadius: AppTheme.radiusMd,
      child: Row(
        children: [
          // Bot Avatar
          BotAvatar(
            bot: bot,
            size: 52,
            stars: stars,
            showElo: false,
          ),
          const SizedBox(width: AppTheme.space12),

          // Bot info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        bot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Text(
                        '${bot.elo}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tierColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  bot.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.25,
                  ),
                ),
                if (recordText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    recordText!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space12),

          // Quick Play Action
          if (onPlay != null)
            ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minimumSize: const Size(60, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                elevation: 0,
              ),
              child: Text(
                'PLAY',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color tierColor,
  ) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: AppTheme.space12),
      child: AppCard(
        onTap: onInspect,
        padding: const EdgeInsets.all(AppTheme.space12),
        borderRadius: AppTheme.radiusLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                BotAvatar(
                  bot: bot,
                  size: 56,
                  stars: stars,
                  showElo: false,
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  bot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '${bot.elo} ELO',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: tierColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            if (onPlay != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'PLAY',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
