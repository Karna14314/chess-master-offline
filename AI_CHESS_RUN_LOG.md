
## Summary of Task: Refactor UI and Navigation
I have completed the task to refactor the UI and navigation for production readiness. The changes include:
- Simplified Home Screen, removed duplicate navigation.
- Cleaned up Game Setup and removed dead code.
- Removed AI Selection and enforced Stockfish usage.
- Improved startup performance by pre-initializing the engine.
- Full Theme Support propagation.
- Ensured all tests pass and analyzer is clean.

## AI Run: Complete Analysis Feature Refactor & UX Overhaul
* Refactored `GameSessionRepository.getRealGamesHistory` to strictly filter out puzzles and analysis modes, fixing the history bug.
* Redesigned `analysis_menu_screen.dart` into a scrollable, unified view and moved `pgn_import_screen.dart` into a matching Material 3 card/view.
* Refactored `analysis_screen.dart` to drop tab-based navigation, shifting to a SingleChildScrollView hosting modern reusable widgets.
* Created modular widgets (`UnifiedEvalBar`, `MoveNavigationBar`, `CurrentMoveDetails`, `EngineRecommendations`, `MoveExplanation`, `InteractiveEvalGraph`, `GameAccuracySummary`, `MoveHistoryList`, `ExportShareButtons`) mapping to standard chess apps (e.g. Chess.com/Lichess).
* Ensured Material 3 themes are fully respected, updating widget padding, shapes, spacing, and null safety.
* Passed all lint rules and unit tests successfully.

- Redesign Game Analysis module
  - Removed "Eye" toggle to enforce automatic live analysis mode.
  - Simplified AppBar by moving secondary actions ("Flip Board" and "Analyze Full Game") to a PopupMenuButton.
  - Rewrote Move Classification Logic to properly account for missed opportunities ("Miss") and ensure correct CPL bounds for brilliant, great, excellent, etc.
  - Enhanced UI components (UnifiedEvalBar and MoveNavigationBar) for a premium, Material 3 aesthetic.
  - Resolved unused variables and lints.
  - Tests verify that move classification logic correctly identifies misses and properly grades moves.
