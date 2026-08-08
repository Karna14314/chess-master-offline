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
  final VoidCallback? onPracticeFromHere;

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
    this.onPracticeFromHere,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColorFor(context)),
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Move $currentMove / $totalMoves',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
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

          const SizedBox(height: 12),
          Divider(color: AppTheme.surfaceColor(context), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _JumpButton(
                  icon: Icons.history_rounded,
                  label: 'Prev Mistake',
                  onPressed: onJumpToPreviousMistake,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _JumpButton(
                  icon: Icons.update_rounded,
                  label: 'Next Mistake',
                  onPressed: onJumpToNextMistake,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _JumpButton(
                  icon: Icons.fitness_center_rounded,
                  label: 'Practice',
                  onPressed: onPracticeFromHere,
                  color: const Color(0xFF00ACC1),
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                onPressed == null
                    ? Colors.transparent
                    : AppTheme.surfaceColor(context).withValues(alpha: 0.5),
          ),
          child: Icon(
            icon,
            size: isLarge ? 28 : 22,
            color: onPressed == null ? AppTheme.textHintFor(context) : AppTheme.textPrimaryFor(context),
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
    final displayColor = isDisabled ? AppTheme.textHintFor(context) : color;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        backgroundColor:
            isDisabled
                ? Colors.transparent
                : displayColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: displayColor, size: 15),
          const SizedBox(width: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.inter(
                  color: displayColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
