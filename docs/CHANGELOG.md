# Release Changelog — Chess Master Offline

## Version 1.0.95 — Engine Stability, Lessons & Daily Puzzle

### 🛡️ Engine Stability (SIGSEGV / ANR)
- Hardened Stockfish usage: FEN validation (promoted pieces, en-passant, castling/rook consistency), move-list/FEN consistency checks, readyok generation tokens, ordered stop handshake.
- Removed duplicate stop commands and double newlines; adaptive analysis timeouts (6–20s).
- Serialized native engine lifetimes with restart cooldowns to prevent queue corruption.
- Lowered crash circuit breaker to 2 consecutive failures.
- Fixed bot strength calibration in fallback mode (ELO-aware depth/blunder sampling).

### 📚 Lessons
- Expanded puzzle catalog to 1,171 chapters across 43 categories.
- Added progress filter chips (All Progress / In Progress / Completed).
- Added "Continue Learning" card and resume from first incomplete chapter.
- Fixed horizontal overflows in lesson screens.

### 🧩 Puzzles
- Daily puzzle streak now correctly reflects persisted streak count on completion.

### 🎨 UI
- Stabilized game board (no shake on move) by fixing player bar border width.

### 🧪 Tests
- New `engine_fen_hardening_test.dart` (13 tests) plus updated lesson counts; analyze 0 errors.

---

EOF# Release Changelog — Chess Master Offline

## Version 1.0.69 — Two-Tier Adaptive Analysis Pipeline & Streak Fix

### ⚡ Performance: Two-Tier Adaptive Classification Pipeline
- **Progressive Deepening with Early Cutoff**: Replaced the monolithic depth-14/MultiPV-2 analysis with a two-phase adaptive pipeline:
  - **Phase 1 (Depth 8 Probe)**: All positions are first analyzed at depth 8 with MultiPV 1 for a quick evaluation snapshot.
  - **Phase 2 (Adaptive Depth 14)**: Based on the depth-8 CPL (centipawn loss), 50%+ of positions are classified without further engine work:
    - CPL > 50 → classified as Inaccuracy/Mistake/Blunder (early cutoff, no depth-14)
    - CPL ≤ 50 → proceed to full depth-14 MultiPV-2 refinement for fine-grained evaluation of competitive positions
  - **Soft Cache Acceptance**: Added `_getSoftCachedEvaluation()` that accepts cached results at depth 10/12 when the position is mathematically stable (mate positions or extreme evaluations |eval| > 5.0), skipping redundant re-analysis.
  - **Expected impact**: ~50% reduction in engine query count for typical games, targeting <15s for 50-move game analysis.

### 🐛 Bug Fixes
- **Daily Puzzle Streak Day-Rollover Fix**: Fixed a bug where `isPuzzleSolvedToday` could remain `true` across calendar days after a multi-day app absence.
  - Updated `loadStreak()` to explicitly evaluate date strings using `DateFormat('yyyy-MM-dd').format(DateTime.now())` and reset the puzzle-solved flag when `lastPuzzleDate != todayStr`.
  - Updated `recordActivity()` to explicitly reset `isPuzzleSolvedToday: false` on day rollover, with proper handling for multi-day absences (streak resets to 1 rather than preserving stale counts).

### 🧪 Test Coverage
- Analysis pipeline continues to pass all compatible tests (390 passing, 4 pre-existing failures due to missing Stockfish binary in CI environment).

---

## Version 1.0.68 — Product, Retention & Stability Audit

### 🚨 Critical Crash Fixes & Policy Compliance
- **Native Stockfish C++ Crash Prevention (SIGSEGV Fix)**:
  - Fixed native crash in `Stockfish::Position::is_draw(int) const`, `Worker::search`, and `Position::do_move` by adding strict pre-flight FEN validation in `StockfishService`.
  - Enforced valid board dimensions (8x8), valid piece notation, correct halfmove/fullmove bounds, and **exactly 1 White King (`K`) and 1 Black King (`k`)**. Malformed FENs are intercepted and safely routed to `SimpleBotService`.
  - Added `_stopCurrentSearchAndWait()` in `getBestMove()` before issuing `position` commands to prevent native worker thread race conditions.
- **Android Target SDK 36 Update**:
  - Updated `android/app/build.gradle.kts` setting `compileSdk = 36` and `targetSdk = 36` to comply with Google Play Store target API level policy.

### 🎨 UI, Theming & UX Enhancements
- **Context-Aware Material 3 Theming System**:
  - Resolved dark mode hardcoding by migrating 17 screen scaffolds to `Theme.of(context)` context-aware color resolution.
  - Added full light theme tokens (`AppTheme.lightTheme`) and enabled automatic system light/dark theme switching.
- **Dynamic Home Screen Dashboard**:
  - Surface daily playing streak counter badge (`🔥 3 Days`), Today's Daily Puzzle hero card, Quick Play vs AI hero button, and 4-mode game grid.
- **First-Launch Onboarding & Skill Level Setup**:
  - Implemented 3-page `OnboardingScreen` explaining 100% offline & ad-free positioning.
  - Integrated skill level picker (Beginner Level 1, Intermediate Level 3, Advanced Level 5) configuring starting Stockfish AI difficulty on first launch.
- **Mid-Game Gameplay Control Bar**:
  - Promoted **Flip Board** (`Icons.swap_vert_rounded`) and **Resign Game** (`Icons.flag_outlined`) onto the primary bottom control bar alongside **Undo** and **Hint** with theme-adaptive confirmation dialogs.

### 🏆 Gamification & Retention
- **Local Badges & Achievements**:
  - Created `AchievementNotifier` tracking 6 offline milestones (*First Victory*, *Tactics Scholar*, *Tactics Master*, *On a Roll*, *Unstoppable*, *Grandmaster Slayer*).
  - Added "Achievements & Trophies" card in `StatisticsScreen` showcasing unlocked vs locked badges.
- **Native Store Review Prompts**:
  - Integrated `in_app_review` service with a 30-day prompt throttle to solicit native Play Store ratings after major game victories.
- **Local Daily Puzzle & Streak Notifications**:
  - Implemented offline on-device daily puzzle reminders and streak protection nudges via `flutter_local_notifications`.

### 🧩 Puzzles
- **Promotion Dialog Fix**:
  - Fixed a critical bug where making a promotion move in puzzles using the tap-to-move interaction failed the puzzle instantly without showing the piece selection dialog.
  - Achieved full parity with drag-and-drop mechanics.

### 🛡️ Privacy, Diagnostics & Open Source Positioning
- **Local Opt-in Crash Diagnostics**:
  - Built `LocalDiagnosticsService` saving up to 512 KB of error logs locally with FIFO rotation.
  - Added native OS share sheet export (`share_plus`) with zero background uploads or pre-filled recipients, guaranteeing clean Google Play Data Safety ("No Data Collected") status.
- **Cross-Promotion ("Our Games")**:
  - Added 5th "More" tab in `MainScreen` highlighting Karna Digital games (*Mahjong Master*, *Block Puzzle Master*, *Sudoku Master*).

---

### 🧪 Automated Test Coverage
- Master test suite expanded with 245+ unit and widget tests covering theming, diagnostics, notification scheduling, onboarding, controls, achievements, SDK 36 config, and Stockfish crash prevention.
