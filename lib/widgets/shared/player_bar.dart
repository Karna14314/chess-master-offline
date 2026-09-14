import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';

/// Reusable tournament player bar component for Game, Analysis, and Practice.
/// Displays player avatar, name, ELO pill, captured pieces with material advantage,
/// clock timer, and turn indicator with subtle glowing border.
class PlayerBar extends ConsumerWidget {
  final Widget avatar;
  final String name;
  final int? elo;
  final bool isActive;
  final bool isWhite;
  final Widget? timerWidget;
  final List<String> capturedPieces;
  final int materialAdvantage;
  final VoidCallback? onTap;

  const PlayerBar({
    super.key,
    required this.avatar,
    required this.name,
    this.elo,
    required this.isActive,
    required this.isWhite,
    this.timerWidget,
    this.capturedPieces = const [],
    this.materialAdvantage = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final accentColor = settings.themePreset.accentColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12, vertical: AppTheme.space8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? accentColor.withValues(alpha: 0.12)
                  : accentColor.withValues(alpha: 0.08))
              : AppTheme.surfaceLevel1(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.6)
                : AppTheme.borderStroke(context),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Avatar with turn indicator dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: avatar,
                  ),
                ),
                if (isActive)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.surface0Dark : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.space12),

            // Player identity & captured material
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (elo != null) ...[
                        const SizedBox(width: AppTheme.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: textSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text(
                            '$elo',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Captured pieces preview
                      if (capturedPieces.isNotEmpty)
                        Flexible(
                          child: SizedBox(
                            height: 14,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              itemCount: capturedPieces.length.clamp(0, 10),
                              itemBuilder: (context, idx) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 1),
                                  child: ChessPiece(
                                    piece: capturedPieces[idx],
                                    size: 14,
                                    pieceSet: settings.currentPieceSet,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (materialAdvantage > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text(
                            '+$materialAdvantage',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emeraldGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Optional Timer
            if (timerWidget != null) ...[
              const SizedBox(width: AppTheme.space12),
              timerWidget!,
            ],
          ],
        ),
      ),
    );
  }
}
