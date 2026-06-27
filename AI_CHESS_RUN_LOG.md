## 2026-04-22
**Status:** SUCCESS ✅
**Category:** C — UI/UX Enhancement
**Task:** Added a premium subtle 15% pop scaling effect to piece movement animations
**Files Changed:**
- `lib/screens/game/widgets/chess_board.dart`: Wrapped the animating `ChessPiece` in a `Transform.scale` linked to a `math.sin` calculation of the animation controller value to provide a smooth bounce effect during travel.
**Verification:**
- Build: PASS
- Tests: PASS
- Emulator: SKIPPED
**User-Visible Impact:** Users will notice a much smoother, premium feel when pieces glide across the board as they slightly pop/scale up dynamically during transit.
**Commit:** (see PR)
**Branch:** auto/chess-20260422-premium-piece-animations
**Notes:** Added `dart:math` to use a sine wave on the animation value for smooth, non-linear scaling interpolation.
