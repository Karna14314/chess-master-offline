# Implementation Plan — ChessMaster Offline Optimization

**Date:** August 7, 2026
**Estimated Duration:** 6 phases, ~3-4 weeks total
**Approach:** Each phase ends with test verification before proceeding

---

## Phase 1: Critical Bug Fixes (Days 1-2)

### 1.1 Fix Broken `pow()` in statistics_provider.dart
**File:** `lib/providers/statistics_provider.dart`

**Changes:**
1. Remove the custom `pow()` function at lines 126-134
2. Add `import 'dart:math' as math;` at top
3. Replace all `pow(10, ...)` calls with `math.pow(10, ...)`

**Affected code:**
```dart
// Line 98: pow(10, -ratingDiff / 400) → math.pow(10, -ratingDiff / 400)
// Line 103: pow(10, -ratingDiff / 400) → math.pow(10, -ratingDiff / 400)
```

**Verification:**
- Run existing puzzle tests
- Verify puzzle rating changes are proportional to rating difference
- Test: Puzzle at same rating → ±16 change (was flat ±16 before, should be ~±16 for equal)
- Test: Puzzle 400 points harder → ~±24 change (was ±16, should be higher)

### 1.2 Fix Double-Counted Puzzle Rating
**Files:**
- `lib/providers/puzzle_provider.dart`
- `lib/providers/statistics_provider.dart`

**Changes:**
1. In `PuzzleNotifier._onPuzzleCompleted()`, remove rating computation (lines 687-706)
2. PuzzleNotifier should only compute `ratingChange` as a display value
3. Move all persistence logic to `StatisticsNotifier.recordPuzzleAttempt()`
4. Unify clamp range to `400-3200` (more standard range)

**Detailed steps:**
```
1. In puzzle_provider.dart _onPuzzleCompleted():
   - Remove lines 687-706 (rating calculation block)
   - Remove `currentRating: newRating` from copyWith (line 711)
   - Keep only state change: streak, isPlayerTurn
   - Pass puzzleRating to statsNotifier

2. In statistics_provider.dart recordPuzzleAttempt():
   - Add `hintsUsed` parameter
   - Apply 0.5 multiplier if hintsUsed > 0
   - Clamp to 400-3200

3. In puzzle_provider.dart _onPuzzleCompleted():
   - Change statsNotifier call to pass hintsUsed
```

**Verification:**
- Test that completing a puzzle updates DB correctly
- Test that reloading shows consistent rating
- Test hint penalty is applied

### 1.3 Fix Analysis Disposing Global Engine
**File:** `lib/providers/analysis_provider.dart`

**Changes:**
1. Remove `_stockfish?.dispose()` from `dispose()` method (line 524)
2. Replace with just stopping analysis:
```dart
@override
void dispose() {
  _stockfish?.stopAnalysis();  // Stop any running analysis
  // DO NOT dispose the singleton engine
  super.dispose();
}
```

**Verification:**
- Navigate to analysis, then go back
- Start a new bot game — engine should respond immediately
- Test that engine status is preserved across navigation

### 1.4 Fix Analysis Menu Provider
**File:** `lib/screens/analysis/analysis_menu_screen.dart`

**Changes:**
1. Replace `import 'package:chess_master/providers/game_provider.dart';` with game session provider
2. Change line 18 from:
```dart
final activeGame = ref.watch(gameProvider);
```
to:
```dart
final gameSession = ref.watch(gameSessionProvider);
final hasActiveGame = gameSession != null &&
    gameSession.moveHistory.isNotEmpty &&
    !gameSession.isRecorded;
```
3. Update all references from `activeGame` to `gameSession`
4. Pass `gameSession.moveHistory` and `gameSession.startingFen` to AnalysisScreen

**Verification:**
- Play a game, then navigate to Analysis tab
- "Analyze Current Game" card should appear
- Tapping it should load the game moves

### 1.5 Fix Timer Selection for Bot Games
**File:** `lib/providers/game_session_viewmodel.dart`

**Changes:**
1. Remove lines 40-43 that force `timeControls[0]` for bot games
2. Instead, support timed bot games:
```dart
void startNewGame({...}) async {
  // Keep the user-selected time control for ALL game modes
  // Timer will run for the human player's turn in bot games
```
3. Update `_makeBotMove()` to pause timer during bot thinking
4. Timer already pauses (line 201) and resumes (line 253) — this is correct
5. Add timer timeout handling for bot games in `game_screen.dart`

**Also fix in `game_screen.dart` line 118:**
```dart
// CURRENT (BROKEN):
if (gameState.gameMode == GameMode.bot) return;

// FIXED: Allow timeout handling for bot games too
// Remove this early return entirely
```

**Verification:**
- Select "10+0 Rapid" for bot game
- Timer should count down during player turn
- Bot should still respond correctly
- Timeout should end the game

### 1.6 Fix PGN Export
**File:** `lib/screens/analysis/analysis_screen.dart`

**Changes:**
1. Add `[Result]` tag to PGN output
2. Add proper PGN headers
3. Fix `_buildPgn()` method:
```dart
String _buildPgn(AnalysisState state) {
  if (state.originalMoves.isEmpty) return "";
  final sb = StringBuffer();
  sb.writeln('[Event "ChessMaster Game"]');
  sb.writeln('[Site "ChessMaster Offline"]');
  sb.writeln('[Date "${DateTime.now().toIso8601String().split('T')[0]}"]');
  sb.writeln('[White "Player"]');
  sb.writeln('[WhiteElo "${state.playerElo ?? "?"}"]');
  sb.writeln('[Black "${state.botName ?? "Bot"}"]');
  sb.writeln('[BlackElo "${state.botElo ?? "?"}"]');
  
  // Determine result from game session or analysis
  final result = state.gameResult ?? '*';
  sb.writeln('[Result "$result"]');
  sb.writeln();
  
  // Move list
  for (int i = 0; i < state.originalMoves.length; i++) {
    if (i % 2 == 0) {
      sb.write('${(i ~/ 2) + 1}. ');
    }
    sb.write('${state.originalMoves[i].san} ');
  }
  sb.write(result);
  return sb.toString().trim();
}
```

**Verification:**
- Export PGN after a completed game
- Import the PGN into Lichess or Chess.com — should parse correctly

---

## Phase 1 Verification Checklist

- [ ] All 315 existing tests pass
- [ ] Puzzle rating changes are proportional to difficulty
- [ ] Analysis screen accessible from active game
- [ ] Engine not disposed when leaving analysis
- [ ] Timer works in bot games
- [ ] PGN export includes [Result] tag

Run: `flutter test` — expected: 315+ tests passing
Run: `flutter analyze` — expected: 0 errors

---

## Phase 2: Lichess Win% Accuracy Model (Days 3-5)

### 2.1 Implement Win% Formula
**File:** `lib/core/constants/app_constants.dart` — update `EvalConstants`

**New methods to add:**
```dart
/// Convert centipawn evaluation to Win% using Lichess formula
/// Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1)
static double centipawnsToWinPercent(double centipawns) {
  return 50.0 + 50.0 * (2.0 / (1.0 + exp(-0.00368208 * centipawns)) - 1.0);
}

/// Convert Win% to centipawns (inverse function)
static double winPercentToCentipawns(double winPercent) {
  if (winPercent >= 100.0) return 10000.0;
  if (winPercent <= 0.0) return -10000.0;
  return -ln((100.0 / (winPercent - 50.0) - 1.0) / 2.0) / 0.00368208;
}

/// Compute move accuracy from Win% before/after the move
/// Accuracy% = 103.1668 * exp(-0.04354 * winDiff) - 3.1669
static double accuracyFromWinPercentDiff(double winDiff) {
  if (winDiff <= 0) return 100.0; // Move did not lose anything
  final raw = 103.1668 * exp(-0.04354 * winDiff) - 3.1669;
  return raw.clamp(0.0, 100.0);
}

/// Compute game accuracy using volatility-weighted mean + harmonic mean
static double gameAccuracy(List<double> moveAccuracies, List<double> winPercents) {
  if (moveAccuracies.isEmpty) return 0.0;
  if (moveAccuracies.length == 1) return moveAccuracies.first;
  
  final windowSize = (winPercents.length / 10).round().clamp(2, 8);
  
  // Calculate volatility (standard deviation) for each window
  final weights = <double>[];
  for (int i = 0; i < winPercents.length - 1; i++) {
    final start = (i - windowSize ~/ 2).clamp(0, winPercents.length - windowSize);
    final window = winPercents.sublist(start, start + windowSize);
    final mean = window.reduce((a, b) => a + b) / window.length;
    final variance = window.map((w) => (w - mean) * (w - mean)).reduce((a, b) => a + b) / window.length;
    final stdDev = sqrt(variance);
    weights.add(stdDev.clamp(0.5, 12.0));
  }
  
  // Pad weights to match moveAccuracies length
  while (weights.length < moveAccuracies.length) {
    weights.add(weights.isEmpty ? 1.0 : weights.last);
  }
  
  // Volatility-weighted mean
  double weightedSum = 0;
  double weightTotal = 0;
  for (int i = 0; i < moveAccuracies.length; i++) {
    weightedSum += moveAccuracies[i] * weights[i];
    weightTotal += weights[i];
  }
  final weightedMean = weightedSum / weightTotal;
  
  // Harmonic mean (penalizes bad moves more)
  double harmonicSum = 0;
  for (final acc in moveAccuracies) {
    harmonicSum += 1.0 / acc.clamp(1.0, 100.0);
  }
  final harmonicMean = moveAccuracies.length / harmonicSum;
  
  // Final: average of weighted and harmonic
  return (weightedMean + harmonicMean) / 2.0;
}
```

### 2.2 Update AnalysisNotifier to Use Win%
**File:** `lib/providers/analysis_provider.dart`

**Changes in `analyzeFullGame()`:**
1. Before analyzing, convert all centipawn evaluations to Win%
2. Compute move accuracy using Win% difference
3. Store both Win% and centipawn values in MoveAnalysis
4. At the end, compute game accuracy using volatility-weighted + harmonic mean

**Add new field to MoveAnalysis:**
```dart
final double winPercentBefore;
final double winPercentAfter;
```

**Verification:**
- Compare accuracy values with Lichess for the same game
- A move that drops Win% from 50% to 40% should score ~70% accuracy
- A move that drops Win% from 50% to 10% should score ~20% accuracy
- A move that keeps Win% at 50% should score 100%

### 2.3 Update Eval Bar to Show Win%
**File:** `lib/screens/analysis/widgets/unified_eval_bar.dart`

**Changes:**
1. Accept `winPercent` parameter instead of (or in addition to) raw eval
2. Fill height proportional to Win% (0% = all black, 50% = half, 100% = all white)
3. Display Win% number (e.g., "53%") instead of "+0.5"
4. Color gradient: losing positions show more black/dark, winning show more white/bright
5. Animate transitions between positions

**Verification:**
- Eval bar fills correctly for equal positions (~50%)
- Eval bar nearly full white for winning positions (>80%)
- Win% number matches expected winning chances

---

## Phase 2 Verification Checklist

- [ ] All existing tests pass
- [ ] Win% formula produces correct values for known positions
- [ ] Move accuracy matches Lichess for sample games
- [ ] Game accuracy uses volatility weighting
- [ ] Eval bar shows Win% and animates

Run: `flutter test` — expected: all passing
Run: `flutter analyze` — expected: 0 errors
