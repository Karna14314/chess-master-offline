# Mobile Chess UI Optimization Skill

## Purpose
Best practices for building a polished, performant chess UI on mobile (Flutter), matching the quality of Lichess and Chess.com.

## Design System

### Color Tokens
Use semantic color names throughout the app:

```dart
// Semantic colors (theme-aware)
class ChessColors {
  // Status colors
  static Color success(BuildContext context) => ...
  static Color error(BuildContext context) => ...
  static Color warning(BuildContext context) => ...
  static Color info(BuildContext context) => ...
  
  // Chess-specific colors
  static Color whiteSquare(BuildContext context, BoardTheme theme) => ...
  static Color darkSquare(BuildContext context, BoardTheme theme) => ...
  static Color checkHighlight(BuildContext context) => ...
  static Color lastMoveHighlight(BuildContext context) => ...
  static Color legalMove(BuildContext context) => ...
  static Color selectedSquare(BuildContext context) => ...
  
  // Analysis colors
  static Color winBarWhite = const Color(0xFFF5F5F5);  // Almost white
  static Color winBarBlack = const Color(0xFF424242);  // Dark gray
  static Color evalPositive = const Color(0xFF4CAF50);  // Green
  static Color evalNegative = const Color(0xFFE53935);  // Red
  static Color evalNeutral = const Color(0xFF757575);   // Gray
}
```

### Move Classification Colors
```dart
extension MoveClassificationColors on MoveClassification {
  Color get color {
    switch (this) {
      case blunder: return const Color(0xFFE53935);  // Red
      case mistake: return const Color(0xFFFB8C00);  // Orange
      case inaccuracy: return const Color(0xFFFDD835); // Yellow
      case miss: return const Color(0xFFE53935);     // Red (same as blunder)
      case book: return const Color(0xFF8E24AA);     // Purple
      case good: return const Color(0xFF7CB342);     // Light Green
      case excellent: return const Color(0xFF43A047); // Green
      case best: return const Color(0xFF2E7D32);     // Dark Green
      case great: return const Color(0xFF1E88E5);    // Blue
      case brilliant: return const Color(0xFF00ACC1); // Cyan
      case forced: return const Color(0xFF78909C);   // Gray-Blue
      case onlyMove: return const Color(0xFF43A047); // Green
    }
  }
  
  IconData get icon {
    switch (this) {
      case blunder: return Icons.close;
      case mistake: return Icons.close;
      case inaccuracy: return Icons.remove;
      case miss: return Icons.help_outline;
      case brilliant: return Icons.star;
      case great: return Icons.star_half;
      case best: return Icons.check;
      default: return Icons.circle;
    }
  }
}
```

### Spacing System
Use a consistent 4px grid:
```dart
class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}
```

### Border Radius
```dart
class Radii {
  static const sm = 8.0;   // Small elements (chips, badges)
  static const md = 12.0;  // Medium elements (list items)
  static const lg = 16.0;  // Large elements (cards, buttons)
  static const xl = 20.0;  // Extra large (dialogs)
  static const full = 999.0; // Full round (avatars, FABs)
}
```

### Typography
Use Inter font family consistently:
```dart
class ChessTextStyle {
  static TextStyle headline(BuildContext context) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimaryFor(context),
  );
  
  static TextStyle body(BuildContext context) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppTheme.textPrimaryFor(context),
  );
  
  static TextStyle caption(BuildContext context) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppTheme.textSecondaryFor(context),
  );
  
  static TextStyle evalNumber = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularNumbers()], // Monospace numbers
  );
}
```

## Board Design

### Board Themes
```dart
// Lichess Classic
BoardTheme(
  lightSquare: Color(0xFFF0D9B5),
  darkSquare: Color(0xFFB58863),
  highlight: Color(0xFFCDD26A),
)

// Chess.com Green
BoardTheme(
  lightSquare: Color(0xFFEEEED2),
  darkSquare: Color(0xFF769656),
  highlight: Color(0xFFF7F769),
)

// Dark mode optimized
BoardTheme(
  lightSquare: Color(0xFF4A4A4A),
  darkSquare: Color(0xFF2D2D2D),
  highlight: Color(0xFF6B6B3A),
)
```

### Piece Rendering
- Use SVG pieces for crisp rendering at all sizes
- Cache piece images after first render
- Use `RepaintBoundary` to isolate piece animations
- High-DPI aware: render at 2x/3x device pixel ratio

## Eval Bar Design

### Win% Eval Bar (Lichess Style)
```dart
class WinPercentEvalBar extends StatelessWidget {
  final double winPercent; // 0-100
  final bool isFlipped;
  final double width;
  final double height;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.black, // Black portion (bottom)
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: width - 2,
          height: (height - 2) * (winPercent / 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.white, // White portion (top)
          ),
          child: Center(
            child: Text(
              '${winPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: winPercent > 50 ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### Key Features
- Smooth animation between positions
- Win% text displayed inside bar
- Flippable (when viewing from Black's side)
- Color gradient option (green → gray → red)

## Move List Design

### Compact Move List
```dart
class CompactMoveList extends StatelessWidget {
  // Two-column layout:
  // 1. e4    e5
  // 2. Nf3   Nc6
  // 3. Bb5   a6 ← (current, highlighted)
  
  // Features:
  // - Tap to navigate
  // - Color-coded classification symbols
  // - Current move highlighted
  // - Scrollable with move numbers
  // - Collapsible sections (opening/middlegame/endgame)
}
```

### Move Classification Badges
```dart
Widget buildClassificationBadge(MoveClassification c) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: c.color, width: 1),
    ),
    child: Text(
      c.symbol,
      style: TextStyle(
        color: c.color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}
```

## Analysis Panel Design

### Collapsible Section Pattern
```dart
class CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final IconData icon;
  
  // Animated expansion
  // Chevron rotation
  // Consistent padding
  // Theme-aware colors
}
```

### Engine Line Display
```dart
class EngineLineWidget extends StatelessWidget {
  final EngineLine line;
  final int index;
  final bool isBest;
  
  // Shows:
  // [1] +1.25  e4 e5 Nf3 Nc6 Bb5 ...  (clickable to preview on board)
  // [2] +0.87  d4 d5 c4 e6 Nc3 Nf6 ...
  // [3] +0.52  Nf3 d5 d4 Nf6 c4 e6 ...
  
  // Features:
  // - Color-coded eval (green = good, red = bad)
  // - Click to preview PV on board (ghost pieces)
  // - Mate scores shown as #3, #-2
  // - Depth shown on hover/long-press
}
```

## Navigation Patterns

### Bottom Navigation (5 tabs)
```
[Home] [Puzzles] [Analysis] [Stats] [More]
```

### Quick Actions
- Game Over → Show bottom sheet with Analyze / New Game / Share
- Post-analysis → Show notification
- Puzzle complete → Show next puzzle prompt

### Back Button Handling
```dart
// In analysis screen, back button should:
// 1. If viewing a variation: go back to main line
// 2. If at start position: exit to previous screen
// 3. Otherwise: go to previous move (not exit)
```

## Animation Guidelines

### Move Animations
```dart
// Piece slides from source to destination
Duration: 200ms
Curve: Curves.easeOutCubic
```

### Eval Bar Animation
```dart
// Smooth fill transition
Duration: 300ms
Curve: Curves.easeOut
```

### Screen Transitions
```dart
// Use MaterialPageRoute with default transitions
// Or custom:
PageRouteBuilder(
  transitionDuration: Duration(milliseconds: 300),
  pageBuilder: (_, __, ___) => AnalysisScreen(),
  transitionsBuilder: (_, animation, __, child) {
    return FadeTransition(opacity: animation, child: child);
  },
)
```

### Haptic Feedback
```dart
// Light tap for move
HapticFeedback.lightImpact();

// Medium for capture
HapticFeedback.mediumImpact();

// Heavy for checkmate
HapticFeedback.heavyImpact();

// Selection click for UI
HapticFeedback.selectionClick();
```

## Performance Optimization

### Board Rendering
1. Use `RepaintBoundary` around the board widget
2. Cache piece images in memory
3. Only redraw changed squares
4. Use `CustomPainter` for highlights (no extra widgets)

### Scroll Performance
1. Use `ListView.builder` for long move lists
2. Set `itemExtent` when possible for predictable heights
3. Use `AutomaticKeepAliveClientMixin` for tab state preservation

### Analysis Performance
1. Run analysis in isolate (already done)
2. Batch UI updates (every 10 moves)
3. Cache evaluations
4. Use `throttle` for progress updates (max 5/sec)

## Accessibility

### Screen Reader Support
```dart
Semantics(
  label: 'Chess board. White to move. King at e1, Queen at d1...',
  child: ChessBoard(...),
)
```

### Color Blindness
- Do not rely solely on color for move classifications
- Include symbols (??, ?, !, !!)
- Use patterns/icons alongside colors

### Large Text Support
- Use `MediaQuery.textScaler` for responsive text
- Ensure board remains usable at 200% text size

## References
- Lichess: lichess.org (open source: github.com/lichess-org/lila)
- Chess.com: chess.com
- Material 3: material.io/components
- Flutter docs: docs.flutter.dev
