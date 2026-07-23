# ChessMaster Offline — Product & Retention Audit & Execution Log

**Repo:** Karna14314/chess-master-offline
**Date:** July 23, 2026
**Context:** ~10% retention, investigated against actual repo code

---

## Hard Constraints & Core Principles (Do Not Violate)

- **No ads** (no AdMob or any ad SDK).
- **No in-app purchases / no paywalls**.
- **No third-party analytics or telemetry SDKs** (no Firebase, Crashlytics, Mixpanel, etc.).
- **Local-only opt-in diagnostics**: Crash/error logs stored locally and shared strictly via native OS share sheet by explicit user action.
- **Local notifications only**: On-device scheduling, no push servers, no accounts.
- **Offline & AGPLv3 / F-Droid compatible**: App must remain fully functional offline without license conflicts.
- **Purpose**: Clean, trustworthy, ad-free flagship experience.

---

## Master Priority Table (P0 – P3)

| Priority | Item | Effort | Depends on Data Collection? | Status |
|---|---|---|---|---|
| P0 | [Section 6] Fix hardcoded dark-theme Scaffolds | Low | No | Fixed |
| P0 | [Section 9] Verify Data Safety form implications before release | Low (process/doc) | N/A | Verified |
| P0 | [Section 10] Upgrade Android compileSdk & targetSdk from 35 to 36 | Low | No | Fixed |
| P0 | [Section 11] Fix Native Stockfish SIGSEGV Crashes (is_draw, search, do_move) | High | No | Fixed |
| P1 | [Section 8] Wire up "Our Games" cross-promo surface | Medium | No | Fixed |
| P1 | [Section 1] Opt-in local crash log + share-sheet export | Medium | No (see Section 9) | Fixed |
| P2 | [Section 2] Local daily-puzzle / streak notifications | Medium | No | Fixed |
| P2 | [Section 3] Home screen redesign — surface puzzles/streak | Medium | No | Fixed |
| P3 | [Section 4] Onboarding flow for new players | Medium | No | Fixed |
| P3 | [Section 5] Mid-game control bar (resign/flip) | Low | No | Fixed |
| P3 | [Section 7] Achievements/streaks/native review prompt | Medium | No | Fixed |

---

## Detailed Audit & Checklist

### Priority P0

- [x] **Section 6 — Theming Bug (Hardcoded Dark-Theme Scaffolds)**
  - **Status:** `Fixed`
  - **Issue:** `Scaffold(backgroundColor: AppTheme.backgroundDark, ...)` is hardcoded directly in screens (`home_screen.dart`, `main_screen.dart`, `more_screen.dart`, etc.) rather than reading from `Theme.of(context)` / `AppTheme`. This forces dark mode regardless of system/user theme settings.
  - **Recommendation:** Audit every `Scaffold` for hardcoded background colors and replace with theme-aware values (`Theme.of(context).scaffoldBackgroundColor` or `AppTheme` light/dark context resolution).
  - **Notes / Files Touched:** Added `AppTheme.lightTheme` & light theme tokens, enabled system theme mode in `main.dart`, removed hardcoded dark background colors from 17 screen scaffolds, wrapped settings cards in `Material` widget to fix ListTile assertions, and added unit/widget test coverage (`test/theme_support_test.dart`).

- [x] **Section 9 — Google Play Data Safety & Content Guidelines Verification**
  - **Status:** `Verified`
  - **Issue:** Ensure local opt-in crash log export complies with Google Play Data Safety declarations ("no data collected" clean claim).
  - **Recommendation:** Implement fully open OS share sheet export (no pre-filled recipient or auto-upload) to guarantee user-initiated action exception. Document Play Console guidelines compliance.
  - **Notes / Files Touched:** Verified Play Store Data Safety exception guidelines for user-initiated actions. Confirmed UX specification for Section 1: local file writing + open native OS share sheet (`share_plus`) with no background uploads or pre-filled recipients, preserving clean "No Data Collected" status.

- [x] **Section 10 — Google Play Policy: Android Target & Compile SDK 36 Upgrade**
  - **Status:** `Fixed`
  - **Issue:** Google Play Store policy requires targeting API level 36 (`targetSdk = 36`) and compiling with API level 36 (`compileSdk = 36`).
  - **Recommendation:** Update `android/app/build.gradle.kts` setting `compileSdk = 36` and `targetSdk = 36`.
  - **Notes / Files Touched:** Updated `android/app/build.gradle.kts` to target and compile SDK 36. Verified in `test/stockfish_crash_prevention_test.dart`.

- [x] **Section 11 — Critical Production Crashes: Stockfish Native SIGSEGV & ANR Fix**
  - **Status:** `Fixed`
  - **Issue:** High native SIGSEGV crash rate in Google Play Console (`Stockfish::Position::is_draw(int) const`, `Worker::search`, `NNUE::FeatureTransformer::update_accumulator_refresh_cache`, `Position::do_move`). Caused by unvalidated FEN inputs passed directly to C++ pointers and race conditions when position/search commands are issued during active evaluation.
  - **Recommendation:**
    1. Implement strict FEN string validation in `StockfishService` before sending commands to native C++. Fall back to `SimpleBotService` if FEN is malformed.
    2. Enforce active search cancellation (`stop`) and wait for `readyok` before sending new `position` commands.
    3. Wrap isolate command execution in robust exception barriers.
  - **Notes / Files Touched:** Enhanced `_isValidFen` in `lib/core/services/stockfish_service.dart` with strict White King (`K`) & Black King (`k`) piece counts, castling, en-passant, halfmove/fullmove bounds, and added `_stopCurrentSearchAndWait()` before setting new position in `getBestMove()`. Verified in `test/stockfish_crash_prevention_test.dart`.

---

### Priority P1

- [x] **Section 8 — Cross-Promotion Surface ("Our Games")**
  - **Status:** `Fixed`
  - **Issue:** `lib/screens/more/more_screen.dart` exists but is not referenced in navigation (`main_screen.dart`). No in-app discovery path for other Karna Digital games.
  - **Recommendation:** Wire `more_screen.dart` into `main_screen.dart` navigation/tab bar or settings, and add a clean, non-intrusive "Our Games" / "Explore Karna Digital" section with store links via `url_launcher`.
  - **Notes / Files Touched:** Wired `MoreScreen` into `main_screen.dart` navigation as the 5th tab ("More"), added "Explore Karna Digital Games" section showcasing Mahjong Master, Block Puzzle Master, Sudoku Master, and developer store page link via `url_launcher`, added cross-promo tile in `settings_screen.dart`, and created `test/cross_promotion_test.dart`.

- [x] **Section 1 — Diagnostics (Local-Only Opt-In Crash/Error Log)**
  - **Status:** `Fixed`
  - **Issue:** No crash reporting or error logging exists to diagnose user churn or engine/storage failures.
  - **Recommendation:** Implement local-only, opt-in crash/error log system saving to a local file. Add a "Send crash report" / "Export diagnostic log" option in settings using native OS share sheet (`share_plus`). Zero background uploads, no device IDs, no server.
  - **Notes / Files Touched:** Created `LocalDiagnosticsService` (`lib/core/services/diagnostics_service.dart`) with local file writing, FIFO write queue, and open share sheet export (`share_plus`). Initialized global error handlers in `main.dart`, added export tiles in `SettingsScreen` and `MoreScreen`, and added unit tests (`test/diagnostics_service_test.dart`).

---

### Priority P2

- [x] **Section 2 — Re-engagement (Local Notifications)**
  - **Status:** `Fixed`
  - **Issue:** No notifications or re-engagement mechanism to bring lapsed users back for daily puzzles or streaks.
  - **Recommendation:** Implement local scheduled notifications via `flutter_local_notifications` for daily puzzles and streak reminders. Purely on-device scheduling from SQLite data; no server or network calls.
  - **Notes / Files Touched:** Added `flutter_local_notifications` dependency, created `NotificationService` (`lib/core/services/notification_service.dart`), initialized service in `main.dart`, updated `AppSettings` & `SettingsNotifier` (`lib/providers/settings_provider.dart`) to persist and toggle notification options, added UI toggles under "Local Notifications" card in `SettingsScreen`, and added unit/integration test coverage (`test/notification_service_test.dart`).

- [x] **Section 3 — Home Screen Redesign (Surface Puzzles & Streaks)**
  - **Status:** `Fixed`
  - **Issue:** Home screen only shows static welcome header, Quick Play hero, two mode cards, and Continue Playing carousel. Built features like Puzzles, Analysis, and Stats are hidden.
  - **Recommendation:** Surface "Today's Puzzle" card directly on Home with one-tap entry, display streak/rating trend cards, and personalize welcome header when profile exists.
  - **Notes / Files Touched:** Built `StreakProvider` (`lib/providers/streak_provider.dart`) to calculate active daily playing streak and daily puzzle completion status. Redesigned `HomeScreen` (`lib/screens/home/home_screen.dart`) with a dynamic dashboard featuring top flame streak badge, "Today's Daily Puzzle" hero card with instant "Solve Daily Puzzle Now" button, Quick Play vs AI hero, and expanded 4-card Game Modes grid (Play Bot, Daily Puzzle, Play Friend, Analyze Game). Added widget tests (`test/home_screen_redesign_test.dart`).

---

### Priority P3

- [x] **Section 4 — Onboarding Flow for New Players**
  - **Status:** `Fixed`
  - **Issue:** No onboarding flow or skill assessment screen. New players drop straight into an ELO selector (800–2800) which is intimidating to casuals/beginners.
  - **Recommendation:** Add a lightweight 2-3 screen first-run onboarding flow with skill self-assessment mapping to beginner/intermediate/advanced bot presets. Store first-run status locally.
  - **Notes / Files Touched:** Built `OnboardingScreen` (`lib/screens/onboarding/onboarding_screen.dart`) featuring a 3-page guide (100% Offline & Ad-Free positioning, Skill Level Picker configuring starting Stockfish AI difficulty, and Features Overview). Created `AppOnboardingGateway` in `lib/main.dart` to automatically show onboarding on first launch and bypass on subsequent launches via `SharedPreferences` (`has_completed_onboarding`). Added "Welcome Tutorial & Skill Setup" tile in `SettingsScreen`. Added widget tests (`test/onboarding_test.dart`).

- [x] **Section 5 — Mid-Game Controls Enhancement**
  - **Status:** `Fixed`
  - **Issue:** Control bar in `game_screen.dart` only shows Undo and Hint. Resign and Flip Board are missing or buried in a menu.
  - **Recommendation:** Bring Resign and Flip Board onto the primary control bar in `game_screen.dart` (`_buildControlBar`). Keep secondary actions in overflow popup menu.
  - **Notes / Files Touched:** Updated `_buildControlBar` in `lib/screens/game/game_screen.dart` to feature 4 primary action buttons: Undo Move, Engine Hint, Flip Board, and Resign Game with tooltips and light/dark theme color adaptability. Updated `_showResignConfirmation` and `_showDrawConfirmation` dialogs to adapt dynamically to light/dark themes. Added widget tests (`test/midgame_controls_test.dart`).

- [x] **Section 7 — Achievements, Streaks & Native Review Prompt**
  - **Status:** `Fixed`
  - **Issue:** No achievements/badges, no streak tracking UI, and Play Store rate link is a plain URL buried in settings.
  - **Recommendation:** Add local achievement & streak tracking derived from local SQLite statistics, and replace raw Play Store URL with `in_app_review` native prompt triggered contextually after wins.
  - **Notes / Files Touched:** Added `in_app_review: ^2.0.9` dependency. Created `ReviewService` (`lib/core/services/review_service.dart`) with 30-day prompt throttling and native store listing launch. Built `AchievementNotifier` & `achievementProvider` (`lib/providers/achievement_provider.dart`) tracking 6 local badges (First Victory, Tactics Scholar, Tactics Master, On a Roll, Unstoppable, Grandmaster Slayer). Hooked win triggers in `GameSessionViewModel`. Added "Achievements & Trophies" card in `StatisticsScreen` (`lib/screens/stats/statistics_screen.dart`). Added unit/widget test suite (`test/achievements_and_review_test.dart`).

---

## Log of Completed Audit Items

## 2026-07-23
**Status:** FIXED ✅
**Category:** P0 — Theming / Design System
**Task:** Section 6: Fixed hardcoded dark-theme Scaffolds & added full light/dark theme support.
**Files Changed:**
- `lib/core/theme/app_theme.dart`: Added `backgroundLight`, `surfaceLight`, `cardLight`, `borderLight`, `textPrimaryLight` tokens and complete Material 3 `lightTheme` configuration.
- `lib/main.dart`: Configured `MaterialApp` with `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`, and `themeMode: ThemeMode.system`.
- `lib/screens/main_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/more/more_screen.dart`, `lib/screens/analysis/analysis_menu_screen.dart`, `lib/screens/analysis/analysis_screen.dart`, `lib/screens/analysis/pgn_import_screen.dart`, `lib/screens/game/game_screen.dart`, `lib/screens/game_setup/new_game_setup_screen.dart`, `lib/screens/history/game_history_screen.dart`, `lib/screens/position_setup/position_setup_screen.dart`, `lib/screens/puzzles/daily_puzzle_screen.dart`, `lib/screens/puzzles/puzzle_history_screen.dart`, `lib/screens/puzzles/puzzle_menu_screen.dart`, `lib/screens/puzzles/puzzle_screen.dart`, `lib/screens/settings/about_screen.dart`, `lib/screens/settings/settings_screen.dart`, `lib/screens/stats/statistics_screen.dart`: Removed hardcoded `backgroundColor: AppTheme.backgroundDark` overrides and migrated container/appbar surfaces to theme context.
- `lib/screens/settings/settings_screen.dart`: Wrapped settings card container in a `Material` widget to resolve ListTile background assertion.
- `test/theme_support_test.dart`: Added unit and widget tests verifying light and dark ThemeData properties and Scaffold theme responsiveness.
**Verification:**
- `flutter test test/theme_support_test.dart`: PASS (3/3 tests)
- `flutter test test/widget_test.dart`: PASS (1/1 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** The app now respects the device's system theme (light/dark mode) smoothly across all screens, eliminating forced dark mode.

## 2026-07-23
**Status:** VERIFIED ✅
**Category:** P0 — Compliance / Data Safety
**Task:** Section 9: Verified Google Play Data Safety implications for local opt-in crash log export.
**Files Changed:**
- `docs/RETENTION_AUDIT.md`: Documented verification and UX constraints.
**Verification:**
- Confirmed Google Play Data Safety exception criteria: user-initiated exports via open OS share sheets do not require declaring background data collection/sharing.
- Specified implementation guidelines for Section 1 (Opt-in local crash log): zero automatic background uploads, local-only file generation, and fully open native share sheet export (`share_plus`).
**User-Visible Impact:** Guarantees that diagnostic export remains 100% user-initiated and preserves the app's clean, zero-telemetry store declaration.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P1 — Growth & Cross-Promotion
**Task:** Section 8: Wired up "Our Games" cross-promotion surface in navigation & screens.
**Files Changed:**
- `lib/screens/main_screen.dart`: Connected `MoreScreen` into main navigation as the 5th tab ("More").
- `lib/screens/more/more_screen.dart`: Added "Explore Karna Digital Games" section featuring Mahjong Master Offline, Block Puzzle Master, Sudoku Master Offline, and developer store page link via `url_launcher`. Upgraded all containers for full theme awareness.
- `lib/screens/settings/settings_screen.dart`: Added "Our Other Games" entry tile in the About section linking directly to Karna Digital's developer page.
- `test/cross_promotion_test.dart`: Added widget tests verifying navigation to More tab and rendering of all cross-promotion game tiles.
**Verification:**
- `flutter test test/cross_promotion_test.dart`: PASS (2/2 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** Players can now navigate to the "More" tab to access settings, stats, quick toggles, and discover all other ad-free offline games by Karna Digital.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P1 — Diagnostics & Error Handling
**Task:** Section 1: Implemented local-only, opt-in crash/error log with native OS share sheet export.
**Files Changed:**
- `lib/core/services/diagnostics_service.dart`: Built `LocalDiagnosticsService` with local file persistence (`chess_diagnostics.log`), size capping (512 KB), FIFO async write queue, and native `share_plus` export.
- `lib/main.dart`: Hooked global Flutter errors (`FlutterError.onError`) and platform dispatcher uncaught errors (`PlatformDispatcher.instance.onError`) to log to the local file automatically.
- `lib/screens/settings/settings_screen.dart`: Added "Export Diagnostic Log" option in Settings to share the log file via OS share sheet.
- `lib/screens/more/more_screen.dart`: Added "Diagnostic Logs" menu tile in MoreScreen for user-initiated log sharing.
- `test/diagnostics_service_test.dart`: Added unit tests verifying log file creation, entry formatting, FIFO ordering, clearing, and mock platform provider behavior.
**Verification:**
- `flutter test test/diagnostics_service_test.dart`: PASS (3/3 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** Users can now generate and export diagnostic logs via the native OS share sheet if they encounter issues, with zero background tracking or automatic server uploads.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P2 — Re-engagement & Retention
**Task:** Section 2: Implemented local-only, privacy-preserving scheduled notifications for daily puzzles and streak nudges.
**Files Changed:**
- `pubspec.yaml`: Added `flutter_local_notifications` dependency.
- `lib/core/services/notification_service.dart`: Built `NotificationService` providing on-device local notification scheduling (`scheduleDailyPuzzleReminder`, `scheduleStreakReminder`, `cancelDailyPuzzleReminder`, `cancelStreakReminder`).
- `lib/main.dart`: Initialized `NotificationService.instance.initialize()` at startup.
- `lib/providers/settings_provider.dart`: Added `dailyPuzzleNotificationEnabled` and `streakNotificationEnabled` state properties, SharedPreferences persistence, and sync toggles.
- `lib/screens/settings/settings_screen.dart`: Added "Local Notifications" settings card with toggles for Daily Puzzle Reminders and Streak Protection Nudges.
- `test/notification_service_test.dart`: Added unit and integration tests for NotificationService methods and Riverpod settings notifier state toggling.
**Verification:**
- `flutter test test/notification_service_test.dart`: PASS (4/4 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** Players receive gentle on-device daily puzzle and streak reminders without any server infrastructure, account requirement, or data leaving the phone.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P2 — Engagement & Dashboard UX
**Task:** Section 3: Redesigned Home screen into a dynamic dashboard surfacing Daily Puzzles, Streaks, and Quick Actions.
**Files Changed:**
- `lib/providers/streak_provider.dart`: Created `StreakProvider` and `StreakNotifier` to track daily activity streaks and today's puzzle status from `SharedPreferences`.
- `lib/screens/home/home_screen.dart`: Transformed static homepage into a rich, theme-aware dashboard featuring:
  - Header with flame streak badge pill (`🔥 3 Days`).
  - Hero card for "Today's Daily Puzzle" displaying completion state and one-tap "Solve Daily Puzzle Now" button.
  - Recommended "Quick Play vs AI" hero.
  - Expanded 4-tile Game Modes grid (Play Bot, Daily Puzzle, Play Friend, Analyze Game).
  - Unfinished games carousel with quick "Resume" buttons.
- `test/home_screen_redesign_test.dart`: Added widget tests for light/dark theme adaptability, streak badge rendering, game mode tiles, and navigation flow to `DailyPuzzleScreen`.
**Verification:**
- `flutter test test/home_screen_redesign_test.dart`: PASS (3/3 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** Players immediately see their daily streak and puzzle status on launching the app, giving them a clear daily goal and instant 1-tap entry into tactics.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P3 — Onboarding & Retention UX
**Task:** Section 4: Implemented first-launch onboarding flow with skill level assessment and feature overview.
**Files Changed:**
- `lib/screens/onboarding/onboarding_screen.dart`: Created 3-slide onboarding experience with welcome privacy positioning, skill level selector (Beginner Level 1, Intermediate Level 3, Advanced Level 5), and feature highlights.
- `lib/main.dart`: Created `AppOnboardingGateway` to detect `has_completed_onboarding` in `SharedPreferences` and automatically route first-time users to `OnboardingScreen`.
- `lib/screens/settings/settings_screen.dart`: Added "Welcome Tutorial & Skill Setup" tile under About section for re-visiting onboarding anytime.
- `test/onboarding_test.dart`: Added widget tests for first-launch routing, skill level selection, and subsequent launch bypass.
**Verification:**
- `flutter test test/onboarding_test.dart`: PASS (3/3 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** First-time players are welcomed with a clean, privacy-first introduction and can immediately configure the AI difficulty to match their skill level, preventing beginner drop-off.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P3 — Gameplay Controls UX
**Task:** Section 5: Promoted Resign and Flip Board onto the primary mid-game control bar.
**Files Changed:**
- `lib/screens/game/game_screen.dart`: Updated `_buildControlBar` to feature 4 primary action buttons: Undo Move (`Icons.undo`), Engine Hint (`Icons.lightbulb_outline`), Flip Board (`Icons.swap_vert_rounded`), and Resign Game (`Icons.flag_outlined`). Added tooltips and theme-aware color adaptation. Updated confirmation dialogs (`_showResignConfirmation`, `_showDrawConfirmation`) to adapt dynamically to light and dark themes.
- `test/midgame_controls_test.dart`: Created widget tests verifying the primary control bar renders 4 action buttons and tapping Resign triggers the confirmation dialog.
**Verification:**
- `flutter test test/midgame_controls_test.dart`: PASS (2/2 tests)
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** Players can instantly flip the board or resign a lost game with a single tap on the main control bar without having to dig through secondary menus.

## 2026-07-23
**Status:** FIXED ✅
**Category:** P3 — Gamification & Retention UX
**Task:** Section 7: Implemented local achievement system and native in-app review prompt.
**Files Changed:**
- `pubspec.yaml`: Added `in_app_review: ^2.0.9` dependency.
- `lib/core/services/review_service.dart`: Created `ReviewService` for managing 30-day throttled native Play Store review prompts and direct store listing opens.
- `lib/providers/achievement_provider.dart`: Created `AchievementNotifier` tracking 6 local badges (First Victory, Tactics Scholar, Tactics Master, On a Roll, Unstoppable, Grandmaster Slayer).
- `lib/providers/game_session_viewmodel.dart`: Hooked win triggers to auto-check achievements and prompt in-app review on major milestones.
- `lib/screens/stats/statistics_screen.dart`: Added "Achievements & Trophies" card rendering unlocked vs locked badges.
- `lib/screens/settings/settings_screen.dart`: Updated Play Store rating tile to trigger `ReviewService.openStoreListing()`.
- `test/achievements_and_review_test.dart`: Created unit and widget tests for local achievement unlocks and StatisticsScreen achievements UI.
**Verification:**
- `flutter test test/achievements_and_review_test.dart`: PASS (2/2 tests)
- `flutter test`: PASS across all 22 audit tests
- `flutter analyze`: CLEAN on touched files
**User-Visible Impact:** Players earn motivating local achievement badges for wins and tactics milestones, and are prompted for native Play Store reviews at optimal moments without invasive popups.
