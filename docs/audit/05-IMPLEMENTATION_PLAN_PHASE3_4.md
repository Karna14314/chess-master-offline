# Implementation Plan — Phases 3 & 4

## Phase 3: Analysis Screen Overhaul (Days 6-10)

### 3.1 Eval Caching (SQLite)
**File:** `lib/core/services/database_service.dart`

**Changes:**
1. Implement the existing `analysis_cache` table schema (already defined but unused)
2. Add methods:
```dart
Future<void> cacheEvaluation({
  required String fen,
  required int depth,
  required int multiPv,
  required double evaluation,
  required String engineLines,
  required bool isMate,
  int? mateIn,
});

Future<Map<String, dynamic>?> getCachedEvaluation({
  required String fen,
  required int requiredDepth,
  required int requiredMultiPv,
});

Future<void> clearEvaluationCache();
```

3. In `AnalysisNotifier._analyzeCurrentPosition()`:
   - Check cache first
   - If cached depth >= required depth, use cached value
   - Otherwise, run analysis and cache result

4. In `AnalysisNotifier.analyzeFullGame()`:
   - Check cache for each position
   - Skip analysis for cached positions
   - Dramatically speed up re-analysis

**Verification:**
- First analysis of a game: runs normally
- Re-analysis of same game: near-instant (from cache)
- Cache hit logged in debug console

### 3.2 Increase MultiPV to 5
**File:** `lib/core/constants/app_constants.dart`

**Change:**
```dart
static const int topEngineLinesCount = 5; // was 3
```

**Update UI in EngineRecommendations widget:**
- Show up to 5 lines
- Allow user to configure 1/2/3/5 lines
- Persist preference in settings

**Verification:**
- Analysis shows 5 engine lines
- User can change number of lines

### 3.3 Add "Practice from Here" Feature
**Files:**
- `lib/screens/analysis/analysis_screen.dart`
- `lib/providers/analysis_provider.dart`
- New: `lib/screens/practice/practice_from_analysis_screen.dart`

**Changes:**
1. Add "Practice" button in analysis screen (next to move navigation)
2. When clicked, navigate to a practice screen with:
   - Current position set up
   - Player plays against Stockfish from this position
   - Same bot difficulty as original game
   - Score tracking (did you find the best move?)

3. Practice mode should:
   - Track if player finds engine's top move
   - If not, show the correct move
   - Allow retry
   - Return to analysis when done

**Verification:**
- "Practice" button appears in analysis
- Tapping starts a practice game from current position
- Engine responds to player moves
- Best move hint is available

### 3.4 Add "Retry Move" Feature
**Files:**
- `lib/screens/analysis/widgets/current_move_details.dart`

**Changes:**
1. When viewing a blunder/mistake, show "Retry" button
2. On tap:
   - Go back one move (to the position before the mistake)
   - Enter a temporary "practice" mode
   - Player tries to find the better move
   - Show comparison with engine's suggestion

**Verification:**
- Retry button appears for classified mistakes
- Player can attempt the position again
- Correct solution shown after attempt

### 3.5 Add Phase Accuracy Breakdown
**Files:**
- `lib/models/analysis_model.dart`
- `lib/screens/analysis/widgets/game_accuracy_summary.dart`

**Changes:**
1. In `GameAnalysis`, add phase detection:
```dart
enum GamePhase { opening, middlegame, endgame }

GamePhase phaseForMove(int moveIndex, int totalMoves) {
  if (moveIndex < totalMoves * 0.15) return GamePhase.opening;
  if (moveIndex > totalMoves * 0.75) return GamePhase.endgame;
  return GamePhase.middlegame;
}
```

2. Compute separate accuracy for each phase
3. Display as:
```
Opening:    92% ████████████████████▌
Middlegame: 78% ███████████████▌
Endgame:    85% █████████████████▌
Overall:    84% █████████████████
```

**Verification:**
- Phase breakdown shows in accuracy summary
- Phases correctly identified based on move count
- Each phase has its own accuracy calculation

### 3.6 Redesign Analysis Screen Layout
**File:** `lib/screens/analysis/analysis_screen.dart`

**New Layout:**
```
┌─────────────────────────────────────────┐
│  AppBar (Analysis | Settings | More)    │
├─────────────────────────────────────────┤
│  ┌─────────┐  ┌──────────────────────┐ │
│  │         │  │                      │ │
│  │  Eval   │  │    Chess Board       │ │
│  │  Bar    │  │    (read-only)       │ │
│  │         │  │                      │ │
│  └─────────┘  └──────────────────────┘ │
├─────────────────────────────────────────┤
│  [<] [◄] [Move 12/40] [►] [>]        │
│  [◄ Mistake] [Mistake ►] [Practice]     │
├─────────────────────────────────────────┤
│  ▼ Engine Analysis                      │
│  1. e4  +0.3  ████████████             │
│  2. Nf3 +0.1  ██████                   │
│  3. Bb5 -0.4  ███                      │
├─────────────────────────────────────────┤
│  ▼ Current Move: Nf6                    │
│  Classification: Good (!)               │
│  Accuracy: 94%                          │
│  [Retry This Move]                      │
├─────────────────────────────────────────┤
│  ▼ Evaluation Graph                     │
│  [Interactive fl_chart graph]           │
├─────────────────────────────────────────┤
│  ▼ Game Summary                         │
│  Accuracy: 84% | Best: 12 | Blunders: 2│
│  Opening: 92% | Mid: 78% | End: 85%     │
├─────────────────────────────────────────┤
│  ▼ Move List                            │
│  1. e4    e5                            │
│  2. Nf3   Nc6                           │
│  3. Bb5   a6                            │
│  ...                                    │
├─────────────────────────────────────────┤
│  [Export PGN] [Share] [Copy FEN]        │
└─────────────────────────────────────────┘
```

Key changes:
- Collapsible sections (tap header to expand/collapse)
- Engine section always visible
- Move list at bottom (collapsible)
- Settings gear in AppBar (not popup menu)

---

## Phase 3 Verification Checklist

- [ ] Eval cache speeds up re-analysis
- [ ] 5 engine lines display correctly
- [ ] "Practice from here" works
- [ ] "Retry move" works
- [ ] Phase accuracy shows opening/mid/endgame
- [ ] Collapsible sections work
- [ ] All existing tests pass

Run: `flutter test` — expected: all passing
Run: `flutter analyze` — expected: 0 errors

---

## Phase 4: Player Rating System + Adaptive Difficulty (Days 11-14)

### 4.1 Implement Player Game ELO
**Files:**
- `lib/models/statistics_model.dart`
- `lib/providers/statistics_provider.dart`
- `lib/core/services/database_service.dart`

**Changes:**
1. Add to `StatisticsModel`:
```dart
final int currentGameElo;        // Player's game ELO (default 1500)
final List<EloSnapshot> eloHistory;  // Rating history for graph
final int gamesProvisional;      // Count of games in provisional period
static const int provisionalGames = 10; // First 10 games are provisional
```

2. Add `EloSnapshot` class:
```dart
class Elosnapshot {
  final int elo;
  final DateTime timestamp;
  final int gameId;
  
  const EloSnapshot({
    required this.elo,
    required this.timestamp,
    required this.gameId,
  });
}
```

3. Add ELO calculation to `StatisticsNotifier`:
```dart
Future<void> recordGameEloChange({
  required int botElo,
  required GameResult result,
}) async {
  const k = state.gamesProvisional < 10 ? 40 : 32; // Higher K during provisional
  
  final expectedScore = 1.0 / (1.0 + math.pow(10, (botElo - state.currentGameElo) / 400));
  final actualScore = result == GameResult.win ? 1.0 : result == GameResult.draw ? 0.5 : 0.0;
  
  final eloChange = (k * (actualScore - expectedScore)).round();
  final newElo = (state.currentGameElo + eloChange).clamp(100, 3200);
  
  // Record history
  final newHistory = List<EloSnapshot>.from(state.eloHistory)
    ..add(EloSnapshot(elo: newElo, timestamp: DateTime.now(), gameId: state.totalGames));
  
  state = state.copyWith(
    currentGameElo: newElo,
    gamesProvisional: state.gamesProvisional + 1,
    eloHistory: newHistory,
  );
  
  await _saveStatistics();
}
```

**Verification:**
- Player starts at 1500 ELO
- Winning against higher ELO bot gives more points
- Losing against lower ELO bot costs more points
- Provisional period uses K=40, then K=32

### 4.2 Adaptive Difficulty
**Files:**
- `lib/providers/game_session_viewmodel.dart`
- `lib/screens/home/home_screen.dart`

**Changes:**
1. Track consecutive wins/losses:
```dart
// In StatisticsModel:
final int consecutiveWins;
final int consecutiveLosses;
```

2. In home screen, suggest difficulty:
```dart
DifficultyLevel get suggestedDifficulty {
  final stats = ref.watch(statisticsProvider);
  final playerElo = stats.currentGameElo;
  
  // Find closest difficulty level to player ELO
  AppConstants.difficultyLevels.reduce((a, b) =>
    (a.elo - playerElo).abs() < (b.elo - playerElo).abs() ? a : b);
}
```

3. Show suggestion banner:
```
"Your rating is 1543. Recommended: Level 3 (Casual, 1500)"
[Play at this level] [Choose different]
```

4. Auto-adjust after streak:
```dart
if (stats.consecutiveWins >= 3) {
  suggestLevelUp();
} else if (stats.consecutiveLosses >= 3) {
  suggestLevelDown();
}
```

**Verification:**
- Difficulty suggestion appears on home screen
- Suggestion matches player ELO
- Streak detection works (3 wins → suggest harder)

### 4.3 Rating History Graph
**Files:**
- `lib/screens/stats/statistics_screen.dart`
- New: `lib/screens/stats/widgets/rating_graph.dart`

**Changes:**
1. Add rating graph to statistics screen
2. Use fl_chart line chart
3. X-axis: game number, Y-axis: ELO
4. Show trend line
5. Highlight provisional period in different color
6. Show min/max/average

**Verification:**
- Rating graph displays after playing games
- Correct min/max values shown
- Provisional period highlighted differently

### 4.4 Update Bot to Match Player Rating
**File:** `lib/providers/engine_provider.dart`

**Changes:**
1. Accept dynamic ELO instead of fixed difficulty
2. Map player ELO to closest Stockfish strength:
```dart
void setBotStrengthForElo(int targetElo) {
  // Find closest difficulty level
  final closest = AppConstants.difficultyLevels.reduce((a, b) =>
    (a.elo - targetElo).abs() < (b.elo - targetElo).abs() ? a : b);
  setSkillLevel(closest.elo);
}
```

**Verification:**
- Bot strength adjusts to match player ELO
- Challenging but beatable games

---

## Phase 4 Verification Checklist

- [ ] Player ELO starts at 1500 and changes after games
- [ ] ELO changes are proportional to opponent strength
- [ ] Rating history is recorded and graphed
- [ ] Adaptive difficulty suggestion works
- [ ] Bot strength matches player ELO
- [ ] All existing tests pass

Run: `flutter test` — expected: all passing
Run: `flutter analyze` — expected: 0 errors
