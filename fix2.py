import re

with open('lib/screens/analysis/widgets/move_navigation_bar.dart', 'r') as f:
    content = f.read()

# Update the row layout
old_row = '''          Row(
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
              _JumpButton(
                icon: Icons.fitness_center_rounded,
                label: 'Practice',
                onPressed: onPracticeFromHere,
                color: const Color(0xFF00ACC1),
              ),
            ],
          ),'''

new_row = '''          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
          ),'''

content = content.replace(old_row, new_row)

old_jump_button = '''    return TextButton.icon(
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
    );'''

new_jump_button = '''    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: displayColor, size: 16),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: displayColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        backgroundColor:
            isDisabled
                ? Colors.transparent
                : displayColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );'''

content = content.replace(old_jump_button, new_jump_button)

with open('lib/screens/analysis/widgets/move_navigation_bar.dart', 'w') as f:
    f.write(content)
