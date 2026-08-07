# Analysis Feature Audit

## Current Analysis Screen Layout
1. UnifiedEvalBar (28px) + ChessBoard (read-only)
2. MoveNavigationBar (first/prev/next/last + jump to mistake)
3. CurrentMoveDetails
4. MoveExplanation
5. EngineRecommendations (top-3 PV lines)
6. InteractiveEvalGraph (fl_chart, tappable)
7. GameAccuracySummary
8. MoveHistoryList (color-coded classifications)
9. ExportShareButtons (PGN/FEN)

## What Works
- MultiPV analysis (3 lines)
- Move classification (best/excellent/good/inaccuracy/mistake/blunder)
- Full game analysis with progress indicator
- Cancellation support
- Eval graph with navigation
- Jump to next/previous mistake
- PGN export

## Feature Comparison

| Feature | Lichess | Chess.com | Our App |
|---------|---------|-----------|---------|
| Win% eval bar | Yes | Yes | No (raw centipawns) |
| MultiPV 5 lines | Yes | Yes | No (3 only) |
| Opening explorer | Yes | Yes | No |
| Tablebase (<=7 pcs) | Yes | Yes | No |
| Practice from here | Yes | Yes | No |
| Retry move (re-solve) | Yes | Yes | No |
| Eval caching | Yes | Yes | No (schema unused) |
| Saved analysis | Yes | Yes | No |
| Review as W/B/Both | Yes | Yes | No |
| Phase accuracy | Yes | No | No |
| Time graph | Yes | Yes | No |
| Best move diff graph | No | Yes | No |
| Comment/annotate | Yes | Yes | No |
| Auto-analysis post-game | Yes | Yes | No |
| Missed tactics practice | No | Yes | No |

## Analysis Flow Issues
1. **Entry broken** — cannot reach from active game (BUG-004)
2. **Recomputes everything** — no eval caching despite schema existing
3. **Kills engine on exit** — disposes singleton (BUG-003)
4. **No incremental analysis** — must run full game every time
5. **No practice from mistake** — cannot turn analysis into training

## Eval Bar Issues
- Currently shows raw centipawns (e.g., "+1.2", "-0.5")
- Should show Win% (e.g., "53%") with green/white gradient
- No visual indication of winning/drawing/losing thresholds
- No animation between position changes

## PGN Export Issues
- `_buildPgn()` in analysis_screen.dart emits no `[Result]` tag
- No result token at end of move list — technically invalid PGN
- Should include all standard PGN headers (Event, Site, Date, Round, White, Black, Result)

---

# Rating System Audit

## Current Rating Architecture
Three separate, unconnected rating systems:

| System | Baseline | Formula | Clamp | Storage |
|--------|----------|---------|-------|---------|
| Bot Difficulty | 1320 (Stockfish min) | Fixed 10 levels | 1320-2800 | AppConstants |
| Puzzle Rating | 1200 | Elo K=32 (BUGGY) | 100-3000 vs 400-3200 | SQLite |
| Per-ELO W/L/D | N/A | Display only | N/A | JSON in SQLite |

## Issues
1. **No player game ELO** — only bot difficulty levels and puzzle rating
2. **Broken pow()** — puzzle Elo is meaningless (BUG-001)
3. **Double computation** — two code paths compute different values (BUG-002)
4. **Inconsistent clamps** — 100-3000 vs 400-3200
5. **No adaptive difficulty** — bot does not adjust to player strength
6. **No rating graph** — cannot see progress over time

## Recommendation
1. Implement player game Elo (start at 1500, standard Elo or Glicko-2)
2. Match bot strength to player rating automatically
3. Fix puzzle Elo (BUG-001 + BUG-002)
4. Add rating history graph
5. Adaptive difficulty (after 3 wins → suggest harder, after 3 losses → suggest easier)

---

# UI/UX Inconsistencies

## Color System Issues

1. **Inconsistent Status Colors:**
   - `success` = `0xFF2E7D32` (forest green)
   - But `primaryColor` is also `0xFF2E7D32` (same green)
   - Move classification colors defined in `MoveClassification` enum
   - Analysis menu accuracy colors inline (`Colors.blue`, `Colors.green`, etc.)
   - No single source of truth for semantic colors

2. **Dark/Light Theme Inconsistencies:**
   - `textSecondary` uses `0xB3E1E1E1` (70% opacity white)
   - But `textSecondaryLight` is `0xFF49454F` (dark gray)
   - Some screens use `Theme.of(context).colorScheme.surface`, others use `AppTheme.cardColor(context)`

3. **Eval Bar Color:**
   - Currently shows raw centipawns (e.g., "+1.2", "-0.5")
   - Should show Win% (e.g., "53%") with green/white gradient
   - No visual indication of winning/drawing/losing thresholds

4. **Board Highlight Inconsistencies:**
   - `checkHighlight` = `0xFFFF5252`
   - `lastMoveHighlight` = `0x8081D4FA` (50% opacity)
   - `legalMoveHighlight` = `0x6090EE90` (38% opacity)
   - `selectedSquareHighlight` = `0x80FFEB3B` (50% opacity)
   - Board themes define their own highlight colors but they may not be used consistently

## Navigation Issues
1. **Bottom Nav has 5 tabs** but Analysis requires 2 taps (Analysis tab → Analyze Current Game)
2. **No "Analyze" button on game over screen** — user must navigate to Analysis tab manually
3. **Analysis menu is just a launcher** — not a true analysis workspace
4. **No back button handling** — pressing back from analysis does not return to game context

## Notification Service Issues
1. **No dedicated notification_service.dart** — file is missing
2. **Notification references** — `flutter_local_notifications` is in pubspec but unclear usage
3. **No post-game notification** — unlike Lichess which notifies "Game analyzed"
4. **No daily puzzle notification** — unlike Lichess's daily puzzle reminders
