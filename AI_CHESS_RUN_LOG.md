
## 2024-05-18
**Status:** SUCCESS ✅
**Category:** C — UI/UX Enhancement
**Task:** Added smooth piece movement animations globally by default.
**Files Changed:**
- `lib/screens/game/widgets/chess_board.dart`: Changed default `enableMoveAnimation` to true and added `ref.listen` in `build` to trigger animations for internal game state using `gameSessionProvider`.
**Verification:**
- Build: PASS
- Tests: PASS
- Emulator: SKIPPED
**User-Visible Impact:** Piece movement now has smooth animations instead of instant jumps globally across the app (game, analysis, puzzles).
**Commit:** [C] Add smooth piece animations for internal and external modes
**Branch:** auto/chess-20240518-piece-animations
**Notes:** `ref.listen` inside `build` is the idiomatic Riverpod pattern to trigger animations safely for internal state modifications.
