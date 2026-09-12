# ChessMaster — Stability, Crash, Journey & Home UX Remediation Audit Document

**Document Status:** Live Audit & Implementation Source of Truth
**Target Version:** 1.0.85 (85)
**Date:** September 2024

---

## Executive Summary

This document serves as the comprehensive audit and technical remediation record for ChessMaster Android production release 1.0.84 (84). The remediation addresses critical native crashes reported in Play Console (`Stockfish::Position::is_draw(int) const` `SIGSEGV`), business logic flaws in the 100-level Journey mode, false completion reporting in the Daily Puzzle system, and layout regressions on the Home Screen viewport hierarchy.

### Summary of Audit & Key Findings
1. **Stockfish Native `SIGSEGV` Crash (`Position::is_draw`)**:
   - **Root Cause**: Command execution race condition. `analyzePosition` issued `_sendCommandDirect('ucinewgame')` bypassing the serialized command queue while native Stockfish worker threads were actively executing `search`/`qsearch`/`is_draw`. `ucinewgame` cleared and reallocated the `Position` state stack (`StateInfo`) concurrently while search threads accessed `st->previous`, resulting in dangling pointer dereferences and native `SIGSEGV`.
   - **Historical Alignment**: Prior crash signatures in v82, v77, and v67 (`Search::Worker::search`, `Search::Worker::qsearch`, `NNUE::update_accumulator`) share the same underlying concurrency and state mutation race condition during active native search threads.
   - **Fix Strategy**: Enforce command queue serialization for `ucinewgame`, issue `isready` and wait for `readyok` in `_stopCurrentSearchAndWait()` to guarantee search worker thread termination before mutating position/state, enforce lifecycle pause handling, and perform strict FEN/move sequence validation.

2. **100-Level Journey Mode Flaws**:
   - **Flaws Found**: Journey levels allowed users to trigger `skipPuzzle()` and `showSolution()`. Progress synchronization and persistence were not cleanly decoupled from standard puzzle modes.
   - **Fix Strategy**: Enforce business logic restrictions in `PuzzleNotifier` rejecting `skipPuzzle()` and `showSolution()` when `_mode == PuzzleFilterMode.journey`. Update UI to hide skip/solution options and render clear level status (Completed, Current Level, Locked). Ensure synchronous `SharedPreferences` persistence and Riverpod state updates on completion.

3. **Daily Puzzle False Completion Bug**:
   - **Flaws Found**: Solving ANY generic puzzle or Journey level invoked `streakProvider.notifier.markPuzzleSolvedToday()`, which set `isPuzzleSolvedToday = true`. The Home Screen and Daily Puzzle screen relied on this generic streak flag, falsely reporting that today's Daily Puzzle had been completed.
   - **Fix Strategy**: Decouple Daily Puzzle completion using a dedicated preference key (`daily_puzzle_last_solved_date`). Explicitly manage distinct states (Available, Completed, Error/Unavailable, Review). Standardize on local `yyyy-MM-dd` date formatting.

4. **Home Screen Viewport Information Hierarchy**:
   - **Flaws Found**: Consecutive stacked hero cards (Daily Streak/Puzzle Hero, Quick Play Hero, Puzzle Journey Hero) consumed ~600dp of vertical space, pushing primary Game Modes below the fold on standard devices.
   - **Fix Strategy**: Reorder sections so primary Game Modes (Play Bot, Daily Puzzle, Play Friend, Analyze Game) appear in the upper viewport directly beneath the header. Compact hero cards and streamline vertical padding and spacing for responsive display across all screen sizes.

---

## 1. Stockfish / Native Engine Crash Audit

### Production Version & Signature Analysis
- **Version**: 84 (1.0.84)
- **Primary Crash Frame**: `[split_config.arm64_v8a.apk!libstockfish_chess_engine.so] Stockfish::Position::is_draw(int) const`
- **Signal**: `SIGSEGV`

### Historical Crash Correlation Matrix

| Crash Signature | Version(s) | Current State | Root Cause Relationship | Still Possible in v84? | Evidence / Notes |
| --------------- | ---------- | ------------- | ----------------------- | ---------------------- | ---------------- |
| `Stockfish::Position::is_draw(int) const` | 84, 82, 77 | Confirmed | Concurrent state mutation during search | Yes (until fix applied) | Direct `ucinewgame` call bypassing command queue while search worker threads were running. |
| `Stockfish::Search::Worker::search<NodeType>` | 82, 77, 67 | Confirmed | Worker thread reading modified `Position` | Yes | Worker thread executed search on reset/freed `Position` data structure. |
| `Stockfish::Search::Worker::qsearch<NodeType>` | 82 | Confirmed | Worker thread reading modified `Position` | Yes | Quiescence search worker accessing invalidated `StateInfo`. |
| `Stockfish::Eval::NNUE::FeatureTransformer::update_accumulator` | 82 | Confirmed | Transposition table / Accumulator cache reset | Yes | NNUE accumulator refresh accessed invalidated board accumulator cache during out-of-order `ucinewgame`. |

### Detailed Technical Analysis & Trace
In C++ Stockfish, `Position::is_draw(int ply) const` inspects the linked list of `StateInfo` nodes (`st->previous`) to evaluate 50-move rule and threefold repetition.
When UCI `go` is issued, worker threads (`Search::Worker::search`) run concurrently in C++ native pthreads.
If the Dart caller invokes `analyzePosition()` while a search is running:
1. `_searchInFlight` was `true`.
2. `_stopCurrentSearchAndWait()` sent `stop` via `_commandQueue` (which added a 10ms processing delay).
3. `analyzePosition` immediately called `_sendCommandDirect('ucinewgame')`.
4. `_sendCommandDirect` bypassed `_commandQueue` and wrote `ucinewgame` directly to the stdin of the C++ Stockfish process.
5. C++ Stockfish executed `ucinewgame` on its main thread, clearing `Position` and `StateInfo` stack while worker threads were STILL executing `search()` and calling `pos.is_draw()`.
6. Search worker threads dereferenced dangling/freed pointers in `st->previous` -> **`SIGSEGV`**.

---

## 2. Stockfish Security & Robustness Audit

### Memory Safety & Threading Boundary Findings
- **Findings**:
  1. Out-of-order direct UCI commands (`_sendCommandDirect`) created native data races with `_commandQueue`.
  2. Search termination lacked explicit synchronization: sending `stop` did not wait for engine thread join via `isready`/`readyok`.
  3. FEN input validation lacked explicit move sequence legal checks for position strings containing `moves ...`.
  4. App lifecycle transitions (pause, hide, background, detach) sent asynchronous `stop` without awaiting thread quiescence, risking crashes when process was suspended by Android OS.

---

## 3. 100-Level Journey Mode Audit

- **ID**: JOURNEY-001
- **Severity**: High
- **Description**: Journey mode allowed users to skip levels or reveal solutions.
- **Root Cause**: `PuzzleNotifier` methods `skipPuzzle()` and `showSolution()` did not check `_mode == PuzzleFilterMode.journey`.
- **Fix**: Reject `skipPuzzle()` and `showSolution()` in business logic when in `journey` mode. Update UI to hide skip/solution buttons. Keep hints active.

- **ID**: JOURNEY-002
- **Severity**: High
- **Description**: Progress persistence and level unlocking were not cleanly updated on level completion.
- **Root Cause**: Level completion callbacks did not wait for synchronous `SharedPreferences` write and state refresh.
- **Fix**: Synchronously await `completeCurrentLevel()` in `JourneyNotifier`, persisting `journey_current_level`, `journey_solved_count`, and `journey_unlocked_milestones`.

---

## 4. Daily Puzzle Audit

- **ID**: DAILY-001
- **Severity**: High
- **Description**: Home Screen and Daily Puzzle screen showed "already completed today's daily puzzle" even when the user had only solved a non-daily puzzle.
- **Root Cause**: `markPuzzleSolvedToday()` in `streakProvider` set generic `isPuzzleSolvedToday = true` for ANY solved puzzle. Home screen and Daily Puzzle UI relied on `isPuzzleSolvedToday` as the indicator for the Daily Puzzle.
- **Fix**: Decouple Daily Puzzle completion using dedicated storage key `daily_puzzle_last_solved_date`. Standardize date comparison using local `yyyy-MM-dd`.

---

## 5. Home Screen UX Audit

- **ID**: HOME-001
- **Severity**: Medium
- **Description**: Core Game Modes were pushed below the fold by three consecutive stacked hero cards.
- **Root Cause**: Unbalanced vertical section stacking (`_buildDailyStreakAndPuzzleHero`, `_buildQuickPlayHero`, `_buildPuzzleJourneyCard` preceding `Game Modes`).
- **Fix**: Reorder layout so Game Modes appear in upper viewport. Streamline hero card heights and padding.

---

## 6. Implementation Checklist

| ID | Issue | Severity | Fix Implemented | Test Added | Verified | Status |
| -- | ----- | -------- | --------------- | ---------- | -------- | ------ |
| SF-001 | Out-of-order `ucinewgame` race in `analyzePosition` | Critical | Yes | Yes | Yes | Fixed |
| SF-002 | Lack of `isready`/`readyok` synchronization after `stop` | High | Yes | Yes | Yes | Fixed |
| SF-003 | FEN & move sequence legal validation | High | Yes | Yes | Yes | Fixed |
| JRN-001 | Block skip action in Journey mode business logic | High | Yes | Yes | Yes | Fixed |
| JRN-002 | Block solution reveal in Journey mode business logic | High | Yes | Yes | Yes | Fixed |
| JRN-003 | Persist Journey level progress & milestones reliably | High | Yes | Yes | Yes | Fixed |
| DLY-001 | Decouple Daily Puzzle completion state | High | Yes | Yes | Yes | Fixed |
| HOM-001 | Expose Game Modes in first viewport on Home Screen | Medium | Yes | Yes | Yes | Fixed |
