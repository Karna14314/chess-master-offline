# ChessMaster Offline — Redesign Progress Log

## Phase 0 — Audit & Plan
*Completed Audit of Codebase Structure and Architecture.*

### Current Architecture & State Management Overview
- **State Management**: Riverpod (`flutter_riverpod`, `ConsumerWidget`, `ConsumerStatefulWidget`, `StateNotifier`, `Notifier`, `FutureProvider`, `Provider`). No new state management patterns will be introduced.
- **Navigation Structure**: Currently 4 tabs in `MainScreen` (`HomeScreen`, `PuzzleMenuScreen`, `LearnScreen`, `StatisticsScreen`).
- **Theme, Colors & Fonts**:
  - Centralized in `lib/core/theme/app_theme.dart`.
  - Color definitions include `primaryColor`, `backgroundDark`, `surfaceDark`, `cardDark`, `borderColor`, etc.
  - Typography uses clean sans-serif fonts with `GoogleFonts.config.allowRuntimeFetching = false` for offline stability.
- **Puzzles / Curriculum / Openings / Review / Campaign / Bot Arena / Settings / Profile Wiring**:
  - *Puzzles*: `lib/screens/puzzles/puzzle_menu_screen.dart` driven by `puzzle_provider.dart` and `journey_provider.dart`. Daily Puzzle tracked via `streakProvider`.
  - *Curriculum (Lessons)*: `lib/screens/lessons/lessons_screen.dart` backed by `LessonService`.
  - *Openings*: `lib/screens/openings/opening_playbook_screen.dart` backed by `OpeningService`.
  - *Review*: `lib/screens/history/game_history_screen.dart` and `lib/screens/analysis/analysis_screen.dart`.
  - *Campaign*: `lib/models/campaign_model.dart` and `lib/screens/bots/bot_campaign_screen.dart` backed by `botProgressProvider`.
  - *Bot Arena*: `lib/screens/bots/bots_hub_screen.dart` and `BotProfile`.
  - *Settings*: `lib/screens/settings/settings_screen.dart` backed by `settingsProvider`.
  - *Profile*: `lib/screens/stats/statistics_screen.dart` backed by `statisticsProvider` and `achievementProvider`.
- **Notifications**: `flutter_local_notifications` (`^18.0.1`), `timezone` (`^0.10.1`), `flutter_timezone` (`^3.0.1`).

## Phase 1 — Centralized Theme Engine & Dark Default Setup
- Configured `ThemeMode.dark` as default in `MaterialApp` and `AppSettings` while persisting System / Dark / Light theme mode preferences in `SharedPreferences`.
- Refined color palette in `AppTheme`: Chess.com-style charcoal background (`#161512`), lighter card surfaces (`#262421`), green CTA (`#2E7D32`), orange accent (`#FF6D00`).
- Disabled runtime network font fetching (`GoogleFonts.config.allowRuntimeFetching = false;`) in `main.dart`.
- Added Theme Mode selector (`System` / `Dark` / `Light`) to `SettingsScreen`.

## Phase 2 — Bottom Navigation & Settings Gear Repositioning
- Restructured bottom navigation bar to 4 fixed tabs with visible labels: `Play` · `Puzzles` · `Learn` · `Profile`.
- Added small orange badge dot on the Puzzles tab icon until today's Daily Puzzle is solved (`streakProvider.isDailyPuzzleSolvedToday`).
- Created `LearnScreen` containing top segmented control (`Lessons` | `Openings` | `Review`), remembering last-selected segment.
- Moved Settings gear icon to top-right of Profile (`StatisticsScreen`) and removed it from Play header (`HomeScreen`).

## Phase 3 — Play Home Hub Redesign & Campaign Stepper Fix
- Redesigned Play home top-to-bottom:
  a. Header with smaller app title, streak chip, stars chip (tapping chips switches to Profile tab).
  b. Hero card: "Play Bot" with last-used opponent + ELO (default Rusty 400), "Choose opponent" link, and automatic "Resume Game" mode when an unfinished match exists.
  c. Compact button row: "Pass & Play" and "Analyze Game" (opens Learn → Review).
  d. Daily Puzzle card above the fold (date, streak, Solve button / checkmark state).
  e. "Review last game" shortcut (shown dynamically if a completed game exists).
  f. Master Campaign card with bug fix in campaign stepper (`startLevel = currentLevelNum.clamp(1, 9)` ensuring 1, 2, 3, 4 sequentially).
  g. Bot Arena horizontal carousel across full rating range with "See all" action. Removed standalone "All Opponents" button.

## Checkpoint Verification (Phases 1-3)
- Executed `flutter pub get`: Dependencies resolved cleanly.
- Executed `flutter analyze`: 0 errors, 0 warnings.
- Verified sans-serif fonts in every screen with `GoogleFonts.config.allowRuntimeFetching = false;`.
- Verified dark default theme, charcoal surfaces, and System/Dark/Light theme persistence.
- Verified Settings opens from Profile gear and settings button is removed from Play header.

## Phase 4 — Puzzles Tab Cleanup & Review Entry Points
- Cleaned up `PuzzleMenuScreen`: removed Curriculum & Openings sections (hosted under `Learn`). Both title and tab label are "Puzzles".
- Unified all Review entry points to access the identical analysis flow (`AnalysisScreen` / `LearnScreen` Review segment):
  a. Play "Analyze Game" button -> switches to Learn → Review segment.
  b. Play "Review last game" shortcut -> opens game's `AnalysisScreen` directly.
  c. Game-over screen (`ResultCard`) -> "Review Game" button opens `AnalysisScreen`.

## Phase 5 — Profile Screen Refinement
- Verified Profile screen (`StatisticsScreen`): displays ratings (including puzzle rating), solved puzzle count, success rate, streak, stars, achievement summary, and top-right Settings gear icon.
- Confirmed no game history list is present in Profile (as game history lives under Learn → Review).

## Phase 6 — Daily Puzzle Local Notification System
- Added `timezone` (`^0.10.1`), `flutter_timezone` (`^3.0.1`), and `clock` (`^1.1.2`).
- Configured Android Manifest with `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and `ScheduledNotificationBootReceiver`.
- Built `DailyPuzzleNotificationService` with an injectable `Clock`:
  - Channel `'daily_puzzle'`, default importance.
  - Inexact zoned scheduling (`AndroidScheduleMode.inexactAllowWhileIdle`).
  - Rolling 7-day schedule window (max 1 notification/day). Cancels today's notification when solved.
  - Notification copy: "Today's puzzle is ready" / "Keep your N-day streak going — today's puzzle is ready".
  - Prompt timing: modal bottom sheet `DailyPuzzleReminderBottomSheet` with time picker appears after first Daily Puzzle solve. Prompts at most twice (at least 7 days apart).
  - Integrated toggle switch & time picker into Settings screen.
- Added comprehensive unit tests in `test/daily_puzzle_notification_test.dart` (100% pass rate).

---
## Implementation Roadmap

- [x] Phase 0: Codebase Audit & Progress Log Documentation
- [x] Phase 1: Theme Engine Refinement (Dark Default, Charcoal Surfaces, Sans-serif, Centralized Palette)
- [x] Phase 2: Bottom Navigation Structure (4 Tabs: Play, Puzzles, Learn, Profile, Puzzles Dot Badge, Settings in Profile)
- [x] Phase 3: Play Home Hub Redesign & Campaign Stepper Fix
- [x] Phase 4: Puzzles & Learn Restructuring (Segmented Control: Lessons | Openings | Review)
- [x] Phase 5: Profile Screen Refinement & Settings Integration
- [x] Phase 6: Daily Puzzle Local Notification System (Injectable Clock, Permission Timing, Rolling 7-day Schedule)
- [ ] Phase 7: Verification & Final Polish (`flutter analyze`, `flutter test`, Manual Test Checklist)
