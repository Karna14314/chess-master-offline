import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MoveNavigationBar extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final int currentMove;
  final int totalMoves;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback? onJumpToPreviousMistake;
  final VoidCallback? onJumpToNextMistake;

  const MoveNavigationBar({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.currentMove,
    required this.totalMoves,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    this.onJumpToPreviousMistake,
    this.onJumpToNextMistake,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.fast_rewind_rounded,
                onPressed: canGoPrevious ? onFirst : null,
              ),
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onPressed: canGoPrevious ? onPrevious : null,
                isLarge: true,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Move $currentMove / $totalMoves',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onPressed: canGoNext ? onNext : null,
                isLarge: true,
              ),
              _NavButton(
                icon: Icons.fast_forward_rounded,
                onPressed: canGoNext ? onLast : null,
              ),
            ],
          ),

          if (onJumpToPreviousMistake != null ||
              onJumpToNextMistake != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.surfaceDark, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _JumpButton(
                  icon: Icons.history_rounded,
                  label: 'Prev Mistake',
                  onPressed: onJumpToPreviousMistake,
                  color: Colors.orange,
                ),
                _JumpButton(
                  icon: Icons.update_rounded,
                  label: 'Next Mistake',
                  onPressed: onJumpToNextMistake,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLarge;

  const _NavButton({required this.icon, this.onPressed, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                onPressed == null
                    ? Colors.transparent
                    : AppTheme.surfaceDark.withValues(alpha: 0.5),
          ),
          child: Icon(
            icon,
            size: isLarge ? 32 : 24,
            color: onPressed == null ? AppTheme.textHint : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _JumpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _JumpButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final displayColor = isDisabled ? AppTheme.textHint : color;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: displayColor, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: displayColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor:
            isDisabled
                ? Colors.transparent
                : displayColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
