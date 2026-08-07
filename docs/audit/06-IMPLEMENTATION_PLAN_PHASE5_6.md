# Implementation Plan — Phases 5 & 6

## Phase 5: UI Consistency + Notification Service (Days 15-18)

### 5.1 Color System Unification
**File:** `lib/core/theme/app_theme.dart`

**Changes:**
1. Create a unified color system with semantic names:
```dart
// Semantic colors (theme-aware)
static Color semanticSuccess(BuildContext context) =>
  Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF4CAF50)  // Brighter green for dark
    : const Color(0xFF2E7D32); // Forest green for light

static Color semanticError(BuildContext context) =>
  Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFEF5350)  // Brighter red for dark
    : const Color(0xFFC62828); // Darker red for light

static Color semanticWarning(BuildContext context) =>
  Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFB74D)
    : const Color(0xFFE65100);

static Color semanticInfo(BuildContext context) =>
  Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF64B5F6)
    : const Color(0xFF1565C0);
```

2. Create move classification color helper:
```dart
// In MoveClassification enum, add theme-aware color getter:
Color get themeColor {
  switch (this) {
    case MoveClassification.blunder:
      return const Color(0xFFE53935);
    case MoveClassification.mistake:
      return const Color(0xFFFB8C00);
    case MoveClassification.inaccuracy:
      return const Color(0xFFFDD835);
    case MoveClassification.good:
      return const Color(0xFF7CB342);
    case MoveClassification.excellent:
    case MoveClassification.best:
      return const Color(0xFF43A047);
    case MoveClassification.great:
      return const Color(0xFF1E88E5);
    case MoveClassification.brilliant:
      return const Color(0xFF00ACC1);
    case MoveClassification.miss:
      return const Color(0xFFE53935);
    case MoveClassification.book:
      return const Color(0xFF8E24AA);
    case MoveClassification.forced:
      return const Color(0xFF78909C);
    case MoveClassification.onlyMove:
      return const Color(0xFF43A047);
  }
}
```

3. Update analysis_screen.dart to use semantic colors
4. Update statistics_screen.dart to use semantic colors
5. Remove inline color definitions

### 5.2 Eval Bar Redesign (Win% Display)
**File:** `lib/screens/analysis/widgets/unified_eval_bar.dart`

**Changes:**
1. Accept `double winPercent` parameter (0-100)
2. Fill bar proportional to Win%
3. Show Win% text (e.g., "53%")
4. Animate transitions with `AnimatedContainer`
5. Color coding:
   - > 60%: White/green tint (White winning)
   - 40-60%: Balanced gray
   - < 40%: Black/red tint (Black winning)

```dart
class UnifiedEvalBar extends StatelessWidget {
  final double winPercent;
  final bool isFlipped;
  final bool showPercentage;
  
  // Build method:
  // - Container with gradient background
  // - AnimatedContainer for fill
  // - Text showing winPercent
}
```

### 5.3 Notification Service
**New file:** `lib/services/notification_service.dart`

**Implementation:**
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();
  
  final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();
  
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }
  
  Future<void> requestPermission() async {
    await _plugin.resolvePlatformSpecificImplementation
        <AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
  
  Future<void> showGameAnalysisReady({
    required double accuracy,
    required int blunders,
    required int bestMoves,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'game_analysis',
        'Game Analysis',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    
    await _plugin.show(
      0,
      'Game Analysis Ready',
      'Accuracy: ${accuracy.toStringAsFixed(0)}% | Blunders: $blunders | Best: $bestMoves',
      details,
    );
  }
  
  Future<void> scheduleDailyPuzzleReminder({required int streak}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_puzzle',
        'Daily Puzzle',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    
    await _plugin.zonedSchedule(
      1,
      'Daily Puzzle Available',
      streak > 0 
        ? 'Keep your $streak-day streak alive!'
        : 'New puzzle waiting for you!',
      _nextInstanceOfTime(10, 0), // 10:00 AM
      details,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  
  Future<void> showAchievementUnlocked(String achievementName) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'achievements',
        'Achievements',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    
    await _plugin.show(
      2,
      'Achievement Unlocked!',
      achievementName,
      details,
    );
  }
  
  Future<void> showRatingMilestone(int newRating) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rating_milestones',
        'Rating Milestones',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    
    await _plugin.show(
      3,
      'Rating Milestone!',
      'You reached $newRating ELO!',
      details,
    );
  }
  
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
```

**Also add:**
- `import 'package:timezone/data/latest.dart' as tz;` in main.dart
- `import 'package:timezone/timezone.dart' as tz;` in notification_service.dart
- Initialize timezone data in main.dart

### 5.4 Navigation Improvements
**File:** `lib/screens/main_screen.dart`

**Changes:**
1. Add "Analyze" FAB (Floating Action Button) when a game just ended
2. Quick navigation from game over screen to analysis
3. Add back button handling in analysis to return to game context

**File:** `lib/screens/game/game_screen.dart`

**Changes:**
1. On game over, show dialog:
```
Game Over - Checkmate!
Accuracy: 84%
[Analyze Game] [New Game] [Close]
```

2. "Analyze Game" button navigates directly to AnalysisScreen with the completed game's moves

### 5.5 Settings Screen Updates
**File:** `lib/screens/settings/settings_screen.dart`

**Changes:**
1. Add notification settings section:
```
Notifications
├── Enable Notifications [toggle]
├── Game Analysis Complete [toggle]
├── Daily Puzzle Reminder [toggle]
├── Achievement Unlocks [toggle]
└── Preferred Reminder Time [time picker]
```

2. Add analysis settings:
```
Analysis
├── Engine Lines [1/2/3/5]
├── Auto-analyze after game [toggle]
├── Show Win% instead of centipawns [toggle]
└── Analysis Depth [12/15/18/20]
```

**Verification:**
- All screens use consistent colors
- Eval bar shows Win% correctly
- Notifications can be enabled/disabled
- Daily puzzle reminder scheduled
- Analysis accessible from game over screen

---

## Phase 5 Verification Checklist

- [ ] Color system uses semantic names throughout
- [ ] Move classification colors are consistent
- [ ] Eval bar shows Win% and animates
- [ ] Notification service initializes
- [ ] Post-game notification fires
- [ ] Daily puzzle reminder schedules
- [ ] Analysis settings persist
- [ ] Game over screen has "Analyze" button
- [ ] All existing tests pass

Run: `flutter test` — expected: all passing
Run: `flutter analyze` — expected: 0 errors

---

## Phase 6: Post-Game Flow + Final Polish (Days 19-21)

### 6.1 Auto-Offer Game Review
**File:** `lib/screens/game/game_screen.dart`

**Changes:**
1. After game ends, show bottom sheet:
```
┌─────────────────────────────────────────┐
│  Game Over - White wins by checkmate    │
│                                         │
│  Accuracy: 84%                          │
│  Best Moves: 12/40                      │
│  Blunders: 2                            │
│                                         │
│  [Analyze Full Game]                    │
│  [Practice Mistakes]                    │
│  [New Game]                             │
└─────────────────────────────────────────┘
```

2. "Analyze Full Game" navigates to AnalysisScreen
3. "Practice Mistakes" navigates to practice mode with only the blunder positions

### 6.2 Practice from Mistakes
**New file:** `lib/screens/practice/practice_mistakes_screen.dart`

**Implementation:**
1. After game analysis, identify all blunders/mistakes
2. Create a "practice session" where the player faces each mistake position
3. Score: how many did they find the right move?
4. Show summary at the end:
```
Practice Results: 3/4 mistakes corrected
Great improvement on tactical awareness!
```

### 6.3 Share Game with Key Moments
**File:** `lib/screens/analysis/widgets/export_share_buttons.dart`

**Changes:**
1. Add "Share Analysis" button
2. Share format:
```
ChessMaster Game Analysis
Result: Win by checkmate
Accuracy: 84%
Blunders: 2 | Mistakes: 3

Key Moments:
- Move 15: Blunder (??) — lost queen
- Move 23: Brilliant (!!) — found tactic
- Move 31: Mistake (?) — missed defense

PGN: [link]
```

3. Uses `share_plus` package to share text

### 6.4 Time Graph (Move Times)
**New file:** `lib/screens/analysis/widgets/time_graph.dart`

**Implementation:**
1. Track time per move (already stored in session)
2. Show bar chart: X-axis = move number, Y-axis = time spent
3. Color bars by player (white/black)
4. Tap bar to navigate to that move

### 6.5 Final Polish
**Changes throughout:**
1. Add loading skeletons for analysis screen
2. Add haptic feedback for navigation
3. Smooth animations for eval bar transitions
4. Consistent border radius (16px) across all cards
5. Consistent spacing (8/16/24px grid)
6. Fix all lint warnings
7. Update README.md with new features
8. Update app version to 1.1.0

---

## Phase 6 Verification Checklist

- [ ] Post-game review bottom sheet appears
- [ ] "Analyze Full Game" navigates correctly
- [ ] Practice from mistakes works
- [ ] Share analysis generates correct text
- [ ] Time graph displays per-move times
- [ ] Consistent UI across all screens
- [ ] Smooth animations
- [ ] All tests pass

Run: `flutter test` — expected: all passing
Run: `flutter analyze` — expected: 0 errors

---

## Final Verification & Build

### Test Suite
```bash
flutter test --coverage
```
Expected: All tests pass, >70% coverage

### Static Analysis
```bash
flutter analyze
```
Expected: 0 errors, 0 warnings

### Build
```bash
flutter build appbundle --release
```
Expected: Successful build, no errors

### Manual Testing Checklist
- [ ] Play bot game at each difficulty level
- [ ] Verify timer works in bot games
- [ ] Analyze completed game
- [ ] Check Win% eval bar
- [ ] Verify move accuracy matches expectations
- [ ] Test puzzle mode with rating
- [ ] Check adaptive difficulty suggestion
- [ ] View rating graph
- [ ] Test notification permissions
- [ ] Export and re-import PGN
- [ ] Toggle dark/light theme
- [ ] Test on different screen sizes

---

## Summary of Changes by File

### New Files
- `lib/services/notification_service.dart` — Notification management
- `lib/screens/practice/practice_from_analysis_screen.dart` — Practice mode
- `lib/screens/practice/practice_mistakes_screen.dart` — Mistake practice
- `lib/screens/stats/widgets/rating_graph.dart` — ELO history graph
- `lib/screens/analysis/widgets/time_graph.dart` — Move time graph
- `lib/screens/analysis/widgets/collapsible_section.dart` — Reusable collapsible
- `lib/models/elo_snapshot.dart` — Rating history model

### Modified Files
- `lib/core/constants/app_constants.dart` — Win% formula, more MultiPV
- `lib/core/theme/app_theme.dart` — Unified color system
- `lib/core/services/database_service.dart` — Eval cache, ELO storage
- `lib/core/services/stockfish_service.dart` — Reference counting
- `lib/providers/statistics_provider.dart` — Fix pow, single rating source
- `lib/providers/puzzle_provider.dart` — Remove duplicate rating
- `lib/providers/analysis_provider.dart` — Win% accuracy, no dispose
- `lib/providers/game_session_viewmodel.dart` — Timer support, ELO tracking
- `lib/providers/engine_provider.dart` — Dynamic ELO mapping
- `lib/screens/analysis/analysis_screen.dart` — New layout, retry, practice
- `lib/screens/analysis/analysis_menu_screen.dart` — Fix provider
- `lib/screens/analysis/widgets/unified_eval_bar.dart` — Win% display
- `lib/screens/game/game_screen.dart` — Post-game flow, timer fix
- `lib/screens/main_screen.dart` — Quick analyze button
- `lib/screens/stats/statistics_screen.dart` — Rating graph
- `lib/models/statistics_model.dart` — ELO fields
- `lib/models/analysis_model.dart` — Win% fields, phase accuracy

### New Dependencies
- `timezone: ^0.9.2` — For scheduled notifications
```
