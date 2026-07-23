# Release Changelog — Chess Master Offline

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

### 🛡️ Privacy, Diagnostics & Open Source Positioning
- **Local Opt-in Crash Diagnostics**:
  - Built `LocalDiagnosticsService` saving up to 512 KB of error logs locally with FIFO rotation.
  - Added native OS share sheet export (`share_plus`) with zero background uploads or pre-filled recipients, guaranteeing clean Google Play Data Safety ("No Data Collected") status.
- **Cross-Promotion ("Our Games")**:
  - Added 5th "More" tab in `MainScreen` highlighting Karna Digital games (*Mahjong Master*, *Block Puzzle Master*, *Sudoku Master*).

---

### 🧪 Automated Test Coverage
- Master test suite expanded with 245+ unit and widget tests covering theming, diagnostics, notification scheduling, onboarding, controls, achievements, SDK 36 config, and Stockfish crash prevention.
