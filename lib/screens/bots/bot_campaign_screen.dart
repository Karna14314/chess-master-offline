import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/campaign_model.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/screens/bots/bot_profile_sheet.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/bot_avatar.dart';

/// 12-Level Master Campaign vertical world map screen
class BotCampaignScreen extends ConsumerWidget {
  const BotCampaignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final botState = ref.watch(botProgressProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLevel0(context),
      appBar: AppBar(
        title: Text(
          'Campaign Map',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${botState.totalCampaignStars}/36 Stars',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber[800] ?? Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // World 1: Novice Grounds (Levels 1 - 4)
          _buildWorldHeader(
            context,
            worldNumber: 1,
            title: 'Novice Grounds',
            subtitle: 'Levels 1–4 • Fundamentals & Tactics',
            color: AppTheme.emeraldGreen,
            icon: Icons.shield_outlined,
          ),
          ..._buildWorldLevels(context, 1, 4, botState),

          const SizedBox(height: 24),

          // World 2: Tactical Circuit (Levels 5 - 8)
          _buildWorldHeader(
            context,
            worldNumber: 2,
            title: 'Club Circuit',
            subtitle: 'Levels 5–8 • Positional & Attack Mastery',
            color: AppTheme.royalBlue,
            icon: Icons.psychology_outlined,
          ),
          ..._buildWorldLevels(context, 5, 8, botState),

          const SizedBox(height: 24),

          // World 3: Grandmaster Summit (Levels 9 - 12)
          _buildWorldHeader(
            context,
            worldNumber: 3,
            title: 'Grandmaster Summit',
            subtitle: 'Levels 9–12 • Elite Engine Bosses',
            color: const Color(0xFF8B5CF6),
            icon: Icons.military_tech_rounded,
          ),
          ..._buildWorldLevels(context, 9, 12, botState),
        ],
      ),
    );
  }

  Widget _buildWorldHeader(
    BuildContext context, {
    required int worldNumber,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORLD $worldNumber: $title',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWorldLevels(
    BuildContext context,
    int startLevel,
    int endLevel,
    BotProgressState botState,
  ) {
    final widgets = <Widget>[];
    for (int i = startLevel; i <= endLevel; i++) {
      final level = CampaignLevel.allLevels[i - 1];
      final isUnlocked = botState.isCampaignLevelUnlocked(level.levelNumber);
      final isCurrent = level.levelNumber == botState.campaignUnlockedLevel;
      final stars = botState.campaignStars[level.levelNumber] ?? 0;
      final isLastInWorld = i == endLevel;

      widgets.add(
        _buildLevelNodeRow(
          context,
          level: level,
          isUnlocked: isUnlocked,
          isCurrent: isCurrent,
          stars: stars,
          isLastInWorld: isLastInWorld,
        ),
      );
    }
    return widgets;
  }

  Widget _buildLevelNodeRow(
    BuildContext context, {
    required CampaignLevel level,
    required bool isUnlocked,
    required bool isCurrent,
    required int stars,
    required bool isLastInWorld,
  }) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final bot = level.bot;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step Node Column with connecting line
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Node Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? AppTheme.amberGold
                        : (stars > 0
                            ? AppTheme.emeraldGreen
                            : (isUnlocked
                                ? AppTheme.surfaceLevel2(context)
                                : AppTheme.surfaceLevel1(context))),
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.amberGold
                          : (stars > 0
                              ? AppTheme.emeraldGreen
                              : (isUnlocked
                                  ? AppTheme.borderStroke(context)
                                  : AppTheme.borderStroke(context).withValues(alpha: 0.4))),
                      width: isCurrent ? 3.0 : 1.5,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppTheme.amberGold.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: stars > 0 && !isCurrent
                        ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                        : (isUnlocked
                            ? Text(
                                '${level.levelNumber}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.black87 : textPrimary,
                                ),
                              )
                            : Icon(
                                Icons.lock_rounded,
                                size: 16,
                                color: textSecondary.withValues(alpha: 0.5),
                              )),
                  ),
                ),

                // Connecting vertical track line
                if (!isLastInWorld)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: stars > 0
                            ? AppTheme.emeraldGreen.withValues(alpha: 0.6)
                            : AppTheme.borderStroke(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Level Details Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: isUnlocked
                    ? () => BotProfileSheet.show(
                          context,
                          bot,
                          campaignLevel: level.levelNumber,
                        )
                    : null,
                color: isUnlocked
                    ? (isCurrent
                        ? AppTheme.amberGold.withValues(alpha: 0.08)
                        : AppTheme.surfaceLevel1(context))
                    : AppTheme.surfaceLevel1(context).withValues(alpha: 0.5),
                borderColor: isCurrent
                    ? AppTheme.amberGold.withValues(alpha: 0.6)
                    : (stars > 0 ? AppTheme.emeraldGreen.withValues(alpha: 0.4) : AppTheme.borderStroke(context)),
                child: Row(
                  children: [
                    // Bot Avatar with opacity if locked
                    Opacity(
                      opacity: isUnlocked ? 1.0 : 0.35,
                      child: BotAvatar(
                        bot: bot,
                        size: 46,
                        stars: stars,
                        showElo: false,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Level Info
                    Expanded(
                      child: Opacity(
                        opacity: isUnlocked ? 1.0 : 0.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    level.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.amberGold,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'vs ${bot.name} (${bot.elo} ELO)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level.rewardBadge,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                if (isUnlocked && stars > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      3,
                                      (idx) => Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: idx < stars ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
