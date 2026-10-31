# ChessMaster Offline — Redesign Progress Log

## Phase 0 — Audit & Plan
*Completed Audit of Codebase Structure and Architecture.*

### Current Architecture & State Management Overview
- **State Management**: Riverpod (`flutter_riverpod`, `ConsumerWidget`, `ConsumerStatefulWidget`, `StateNotifier`, `Notifier`, `FutureProvider`, `Provider`).
- **Navigation Structure**: 4 fixed tabs in `MainScreen` (`Play`, `Puzzles`, `Learn`, `Profile`).
- **Theme, Colors & Fonts**:
  - Centralized in `lib/core/theme/app_theme.dart`.
  - Bundled Inter TTF font assets in `assets/fonts/` (`Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`) declared in `pubspec.yaml` with zero runtime network fetching (`google_fonts` completely removed).
  - Softer dark palette: `#272522` background, `#302E2B` surface, `#3A3835` surfaceHigh, `#45423E` outline, `#F2F0EC` textPrimary, `#B8B4AD` textSecondary, `#8A867F` textDisabled, primary green CTA, `#F0A030` amber reserved exclusively for streak/stars/achievements.
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

## Fix Round Updates & Design Enhancements

### 1. Inter Font Bundled Assets & Theme Typography
- Bundled Inter font weights 400, 500, 600, and 700 directly in `assets/fonts/`.
- Configured `fontFamily: 'Inter'` in `ThemeData` for both light and dark themes.
- Established typography scale: Screen titles (22/semibold), Section headers (18/semibold), Body (15/regular), Secondary (13/regular), Labels (12/medium).
- Removed `google_fonts` package dependency and replaced all per-widget font overrides across 50+ files to inherit typography directly from `ThemeData`.
- Registered Inter SIL Open Font License in Flutter `LicenseRegistry`.

### 2. Softer Dark Palette & Flat Surface Cards
- Updated palette tokens in `AppTheme`: `#272522` background, `#302E2B` surface, `#3A3835` surfaceHigh, `#45423E` outline.
- Flat card surfaces (`AppCard` and `CardTheme`) with 16pt border radius and no coloured outlines or borders.
- Replaced orange card borders and blue/teal card accents with primary green (`#2E7D32`) or neutral `surfaceHigh`.
- Converted difficulty badges to neutral tonal chips (`surfaceHigh` background, `textSecondary` text, small coloured dot).
- Ensured filter chips use primary green when selected.

### 3. Screenshot Bug Fixes
- **Play Tab**: Updated "Review last game" shortcut to query completed games (`result IS NOT NULL`) via `getCompletedRealGames` and hide when only an in-progress game exists.
- **Daily Puzzle Solved State**: Simplified UI to a single row containing checkmark with 'Solved Today' label and a 'Review puzzle' button.
- **Campaign Card**: Set `showElo: false` on `BotAvatar` in the campaign card so "400" appears only once as "vs Rusty (400)".
- **Pass & Play Subtitle**: Shortened subtitle from "Two players, 1 phone" to "Same device" to prevent text truncation.
- **Learn Hub App Bar**: Removed redundant "Chess Lessons" app bar title when `LessonsScreen` is embedded in the `LearnScreen` hub tab.

### 4. Learn Lessons Async Loading Fix & Widget Tests
- **Root Cause**: `LessonService.instance.initialize()` loads JSON asynchronously via `rootBundle.loadString`. On cold open, `LessonsScreen` synchronously accessed `LessonService.instance.sections`. Since asset files on mobile devices are bundled inside the APK/IPA, `_ensureLoadedFromFileSync()` failed to load them as local filesystem paths, returning an empty list (`[]`). Tapping a filter chip triggered `setState()`, by which time the background async `initialize()` had completed.
- **Fix**: Wrapped `LessonsScreen`, `OpeningPlaybookScreen`, and `AnalysisMenuScreen` in `FutureBuilder<void>(future: service.initialize(), ...)`. Implemented clean loading spinner state, explicit empty filter results state with reset button, and error retry state.
- **Widget Tests**: Created `test/learn_lessons_widget_test.dart` verifying cold open non-empty lessons list, filter selection counts, and filter roundtrip consistency (All -> Beginner -> All) for both Lessons and Openings (100% pass rate).

---
## Implementation Roadmap

- [x] Phase 0: Codebase Audit & Progress Log Documentation
- [x] Phase 1: Theme Engine Refinement (Dark Default, Charcoal Surfaces, Inter Font, Centralized Palette)
- [x] Phase 2: Bottom Navigation Structure (4 Tabs: Play, Puzzles, Learn, Profile, Puzzles Dot Badge, Settings in Profile)
- [x] Phase 3: Play Home Hub Redesign & Campaign Stepper Fix
- [x] Phase 4: Puzzles & Learn Restructuring & Screenshot Bug Fixes
- [x] Phase 5: Profile Screen Refinement & Settings Integration
- [x] Phase 6: Daily Puzzle Local Notification System (Injectable Clock, Permission Timing, Rolling 7-day Schedule)
- [x] Phase 7: Fix Round — Inter Font, Softer Dark Palette, Screenshot Bugs & Learn Lessons Async Fix
- [ ] Phase 8: Final Verification & Stability Pass (`flutter analyze`, `flutter test`, `flutter build apk --debug`)
