import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/widgets/shared/app_button.dart';

/// Game-over outcome modal dialog card answering:
/// 1. "What happened?" (Victory, Defeat, Draw, reason)
/// 2. "What did I gain?" (ELO delta, campaign stars, badges)
/// 3. "What should I do next?" (Rematch, Analyse, Home)
class ResultCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isWin;
  final bool isDraw;
  final String opponentName;
  final int? opponentElo;
  final int? eloDelta;
  final int? playerElo;
  final double? playerAccuracy;
  final double? opponentAccuracy;
  final int? campaignStarsEarned;
  final VoidCallback onRematch;
  final VoidCallback onAnalyse;
  final VoidCallback onHome;

  const ResultCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.isWin,
    required this.isDraw,
    required this.opponentName,
    this.opponentElo,
    this.eloDelta,
    this.playerElo,
    this.playerAccuracy,
    this.opponentAccuracy,
    this.campaignStarsEarned,
    required this.onRematch,
    required this.onAnalyse,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.textSecondaryFor(context);

    final outcomeColor = isDraw
        ? AppTheme.royalBlue
        : (isWin ? AppTheme.amberGold : AppTheme.crimsonRed);

    final outcomeIcon = isDraw
        ? Icons.handshake_rounded
        : (isWin ? Icons.emoji_events_rounded : Icons.shield_outlined);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLevel1(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: outcomeColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: outcomeColor.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    outcomeColor.withValues(alpha: 0.22),
                    outcomeColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: outcomeColor.withValues(alpha: 0.2),
                      border: Border.all(color: outcomeColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: outcomeColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(outcomeIcon, size: 38, color: outcomeColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: outcomeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // Content Body: "What did I gain?"
            Padding(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                children: [
                  // Gains Row (ELO delta & Stars)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (playerElo != null)
                        _buildMetricPill(
                          context,
                          label: 'Your Rating',
                          value: '$playerElo',
                          delta: eloDelta != null ? (eloDelta! >= 0 ? '+$eloDelta' : '$eloDelta') : null,
                          deltaColor: eloDelta != null && eloDelta! >= 0 ? AppTheme.emeraldGreen : AppTheme.crimsonRed,
                        ),
                      if (campaignStarsEarned != null && campaignStarsEarned! > 0)
                        _buildMetricPill(
                          context,
                          label: 'Campaign Mastery',
                          value: '$campaignStarsEarned Stars',
                          icon: Icons.star_rounded,
                          iconColor: AppTheme.amberGold,
                        ),
                      if (playerAccuracy != null && playerAccuracy! > 0)
                        _buildMetricPill(
                          context,
                          label: 'Accuracy',
                          value: '${playerAccuracy!.toStringAsFixed(1)}%',
                          delta: opponentAccuracy != null ? 'vs ${opponentAccuracy!.toStringAsFixed(1)}%' : null,
                          deltaColor: textSecondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // Primary Actions: "What should I do next?"
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: 'Home',
                          icon: Icons.home_rounded,
                          onPressed: onHome,
                          size: AppButtonSize.medium,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: AppButton.outlined(
                          label: 'Analyse',
                          icon: Icons.insights_rounded,
                          onPressed: onAnalyse,
                          size: AppButtonSize.medium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      label: 'Play Again',
                      icon: Icons.replay_rounded,
                      onPressed: onRematch,
                      size: AppButtonSize.large,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    String? delta,
    Color? deltaColor,
    IconData? icon,
    Color? iconColor,
  }) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLevel2(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderStroke(context)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 1),
            Text(
              delta,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: deltaColor ?? textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
