import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/game_model.dart';

/// Modern chess move list supporting both a compact horizontal strip
/// and a full 2-column move table.
class MoveList extends StatelessWidget {
  final List<ChessMove> moves;
  final int? currentMoveIndex;
  final Function(int)? onMoveTap;
  final VoidCallback? onExpandTap;
  final ScrollController? scrollController;

  const MoveList({
    super.key,
    required this.moves,
    this.currentMoveIndex,
    this.onMoveTap,
    this.onExpandTap,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return Container(
        height: 38,
        alignment: Alignment.center,
        child: Text(
          'Game in progress • White to move',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: AppTheme.textSecondaryFor(context).withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final effectiveCurrentIndex = currentMoveIndex ?? (moves.length - 1);
    final textSecondary = AppTheme.textSecondaryFor(context);

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
              itemCount: (moves.length / 2).ceil(),
              itemBuilder: (context, turnIndex) {
                final moveNum = turnIndex + 1;
                final whiteIdx = turnIndex * 2;
                final blackIdx = turnIndex * 2 + 1;
                final whiteMove = moves[whiteIdx];
                final blackMove = blackIdx < moves.length ? moves[blackIdx] : null;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Move number prefix
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$moveNum.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),

                    // White move chip
                    _buildMoveChip(
                      context,
                      san: whiteMove.san,
                      isCheck: whiteMove.isCheck,
                      isMate: whiteMove.isCheckmate,
                      isSelected: effectiveCurrentIndex == whiteIdx,
                      onTap: onMoveTap != null ? () => onMoveTap!(whiteIdx) : null,
                    ),

                    // Black move chip (if exists)
                    if (blackMove != null) ...[
                      const SizedBox(width: 2),
                      _buildMoveChip(
                        context,
                        san: blackMove.san,
                        isCheck: blackMove.isCheck,
                        isMate: blackMove.isCheckmate,
                        isSelected: effectiveCurrentIndex == blackIdx,
                        onTap: onMoveTap != null ? () => onMoveTap!(blackIdx) : null,
                      ),
                    ],
                    const SizedBox(width: 6),
                  ],
                );
              },
            ),
          ),
          if (onExpandTap != null)
            IconButton(
              icon: Icon(
                Icons.format_list_bulleted_rounded,
                size: 18,
                color: textSecondary,
              ),
              tooltip: 'Move History',
              onPressed: onExpandTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveChip(
    BuildContext context, {
    required String san,
    required bool isCheck,
    required bool isMate,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final textPrimary = AppTheme.textPrimaryFor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              san,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : textPrimary,
              ),
            ),
            if (isMate) ...[
              const SizedBox(width: 2),
              const Icon(Icons.stars_rounded, size: 12, color: AppTheme.amberGold),
            ] else if (isCheck) ...[
              const SizedBox(width: 2),
              const Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.crimsonRed),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full 2-column move table for dialogs or bottom sheets
class MoveTableSheet extends StatelessWidget {
  final List<ChessMove> moves;
  final int? currentMoveIndex;
  final Function(int)? onMoveTap;

  const MoveTableSheet({
    super.key,
    required this.moves,
    this.currentMoveIndex,
    this.onMoveTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);

    return Container(
      constraints: const BoxConstraints(maxHeight: 450),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Move History (${moves.length} moves)',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: moves.isEmpty
                ? Center(
                    child: Text(
                      'No moves played yet',
                      style: GoogleFonts.inter(color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: (moves.length / 2).ceil(),
                    itemBuilder: (context, index) {
                      final moveNum = index + 1;
                      final whiteIdx = index * 2;
                      final blackIdx = index * 2 + 1;
                      final whiteMove = moves[whiteIdx];
                      final blackMove = blackIdx < moves.length ? moves[blackIdx] : null;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Colors.transparent
                              : AppTheme.surfaceLevel1(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '$moveNum.',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  if (onMoveTap != null) onMoveTap!(whiteIdx);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: currentMoveIndex == whiteIdx
                                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    whiteMove.san,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: currentMoveIndex == whiteIdx
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: currentMoveIndex == whiteIdx
                                          ? AppTheme.primaryColor
                                          : textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: blackMove != null
                                  ? InkWell(
                                      onTap: () {
                                        if (onMoveTap != null) onMoveTap!(blackIdx);
                                        Navigator.pop(context);
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: currentMoveIndex == blackIdx
                                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          blackMove.san,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: currentMoveIndex == blackIdx
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: currentMoveIndex == blackIdx
                                                ? AppTheme.primaryColor
                                                : textPrimary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
