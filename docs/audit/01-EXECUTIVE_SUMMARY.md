# ChessMaster Offline — Comprehensive Feature Audit

**Date:** August 7, 2026
**Version:** 1.0.53+53
**Auditor:** AI-Assisted Full Codebase Review

---

## Executive Summary

ChessMaster Offline is a mature Flutter/Dart Android chess application (~26k lines, 76 Dart files, 42 test files with 315 tests passing). The app features a sophisticated Stockfish 17 engine integration running in a dedicated isolate, three-tier fallback chain, and a full analysis suite.

**Current State:** The engine integration is genuinely impressive for an offline app — well-tested concurrency guards, FEN validation preventing native crashes, and atomic search claims. However, the accuracy model uses a flawed centipawn-loss approach (vs Lichess's industry-standard Win% model), the analysis feature has a broken entry point (wired to deprecated provider), and the rating system has a critical `pow()` bug that makes Elo calculations meaningless.

**Feature Parity Score:** ~45% of Lichess, ~35% of Chess.com

---

## Architecture Assessment

### Tech Stack
| Component | Implementation | Rating |
|-----------|---------------|--------|
| Framework | Flutter (Dart SDK ^3.7.0), Material 3 | Good |
| State Management | flutter_riverpod ^2.6.1 | Good |
| Chess Rules | chess ^0.8.1 (0x88 board) | Adequate |
| Engine | stockfish_chess_engine ^0.8.2 (Stockfish 17) | Excellent |
| Storage | sqflite ^2.4.1 + shared_preferences ^2.3.4 | Good |
| UI | google_fonts, flutter_svg, fl_chart ^0.70.2 | Good |
| CI/CD | GitHub Actions to Play Store | Good |

### Architecture Patterns
- **Provider Pattern:** Mixed usage of `gameProvider` (deprecated) and `gameSessionProvider` (current). Legacy provider still load-bearing in analysis menu.
- **Isolate-based Engine:** Stockfish runs off UI thread with bidirectional message-passing.
- **Singleton Services:** StockfishService, DatabaseService, AudioService all singletons.
- **Fallback Chain:** Stockfish to SimpleBotService to BasicEvaluatorService (recoverable with 30s cooldown).

---

## Critical Bugs (P0 — Fix Immediately)

### BUG-001: Broken `pow()` Implementation Corrupts Puzzle Elo
**Location:** `lib/providers/statistics_provider.dart:127-134`
**Severity:** CRITICAL — Makes puzzle rating system meaningless

```dart
// CURRENT (BROKEN):
double pow(double base, double exp) {
  int intExp = exp.abs().round();  // ROUNDS fractional exponent to integer!
  double result = 1;
  for (int i = 0; i < intExp; i++) {
    result *= base;
  }
  return exp < 0 ? 1 / result : result;
}
```

**Problem:** Elo requires `pow(10, x/400)` where `x/400` is fractional (e.g., 0.375). Rounding it to an integer means:
- For rating differences < 200: exponent rounds to 0 or 1, expectedScore always 0.5 or 0.25
- Result: Flat +/-16 rating change regardless of puzzle difficulty
- Also shadows `dart:math.pow`, creating two different computation paths

**Fix:** Remove the custom `pow()` function entirely. Import `dart:math` and use the built-in `pow()`.

### BUG-002: Double-Counted Puzzle Rating Updates
**Location:** `lib/providers/puzzle_provider.dart:663-728` + `lib/providers/statistics_provider.dart:87-117`
**Severity:** CRITICAL — Two code paths compute different ratings

**Problem:**
1. `PuzzleNotifier._onPuzzleCompleted()` computes new rating in its own state (clamp 100-3000)
2. Then calls `statsNotifier.recordPuzzleAttempt()` which independently computes AND persists a DIFFERENT rating (clamp 400-3200)
3. DB becomes source of truth on next load, silently discarding UI value

**Fix:** Single source of truth. Move all rating computation to StatisticsNotifier. PuzzleNotifier should only report the result (solved/failed + puzzleRating), not compute rating.

### BUG-003: Analysis Disposes Global Engine Singleton
**Location:** `lib/providers/analysis_provider.dart:522-526`
**Severity:** HIGH — Causes multi-second stalls after analysis

```dart
@override
void dispose() {
  _stockfish?.dispose();  // _stockfish is StockfishService.instance — THE GLOBAL SINGLETON!
  super.dispose();
}
```

**Problem:** Navigating away from analysis disposes the engine for the entire app. It self-heals via lazy re-init, but causes a 3-8 second stall on the next bot move.

**Fix:** AnalysisNotifier should NOT dispose the singleton. Just stop analysis. The engine lifecycle should be managed by the app's top-level lifecycle, not individual screens.

### BUG-004: Analysis Menu Wired to Deprecated Provider
**Location:** `lib/screens/analysis/analysis_menu_screen.dart:18`
**Severity:** HIGH — "Analyze Current Game" feature is unreachable

```dart
final activeGame = ref.watch(gameProvider);  // DEPRECATED — always empty in production
```

**Problem:** The live game flow uses `gameSessionProvider`, but analysis menu watches `gameProvider`. Since `gameProvider.moveHistory` is always empty, the "Analyze Current Game" card never appears.

**Fix:** Change to `ref.watch(gameSessionProvider)` and check for active session with non-empty moves.

### BUG-005: Timer Selection Silently Discarded for Bot Games
**Location:** `lib/providers/game_session_viewmodel.dart:40-43`
**Severity:** HIGH — Ignores user's time control choice

```dart
void startNewGame({...}) async {
  if (gameMode == GameMode.bot) {
    timeControl = AppConstants.timeControls[0];  // Force No Timer
  }
```

**Problem:** The user selects a time control (e.g., "10+0 Rapid"), but for bot games it's silently replaced with "No Timer". There is no UI indication that timed bot games are not supported.

**Fix:** Either (a) support timed bot games with the clock running for the human player, or (b) clearly indicate in the setup screen that timers only apply to local multiplayer.

---

## Accuracy Model Audit (vs Lichess)

### Current Model (CPL-Based)
```
CPL = (evalBefore - evalAfter) x 100
Accuracy = 100 x exp(-0.003 x CPL)
```

### Why It Is Wrong
Centipawns do not equal human winning chances:
- A +1 swing in an equal position (0.00 to +1.00) changes winning chances dramatically
- A +1 swing at +8.00 barely matters at all
- But both get the SAME accuracy penalty with CPL model

### Lichess Model (Win% Based) — The Gold Standard
```
// Step 1: Convert centipawns to Win% using a logistic curve
Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1)

// Step 2: Move accuracy from Win% change
Accuracy% = 103.1668 * exp(-0.04354 * (winPercentBefore - winPercentAfter)) - 3.1669

// Step 3: Game accuracy = avg(volatility-weighted mean, harmonic mean)
// Volatility = standard deviation of Win% in sliding windows
// Harmonic mean penalizes bad moves more than arithmetic mean
```

### Recommendation
Replace the CPL-based model with Lichess's Win% formula. It is open-source, well-documented, calibrated against 2300+ rated rapid games, and matches player intuition much better.
