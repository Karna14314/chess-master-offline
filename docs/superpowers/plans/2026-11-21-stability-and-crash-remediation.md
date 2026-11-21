# Stability & Crash Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permanently resolve the top 4 production crash/ANR failure modes reported in Google Play Console (native `Position::is_draw` SIGSEGV, `PlatformTaskQueue` input dispatching timeouts, `SCREEN_OFF` broadcast timeout, and `DartMessenger` OOM) and bring the test suite to 100% green.

**Architecture:** Enforce a strict protocol-barrier synchronization model for Stockfish UCI interactions (mandating search termination via `bestmove` before issuing position mutations), throttle high-frequency engine stream output and UI state notifications, hook lifecycle pause events to cancel long-running full-game analysis, and bound native/JVM heap footprints (capping Hash tables to 16MB/32MB).

**Tech Stack:** Dart 3, Flutter, Riverpod, Stockfish 17 (FFI / UCI), `package:test` / `flutter_test`.

**Spec:** `docs/chessmaster_stability_and_ux_audit.md` and Google Play Console incident audit.

## Global Constraints

- Never send `position` or `ucinewgame` to Stockfish while worker search threads are active.
- Never treat `readyok` as a guarantee that worker search threads have stopped; only `bestmove` confirms search completion.
- Never flood the Flutter UI isolate with unthrottled stdout line emissions or regex matches during batch/deep analysis.
- When Android lifecycle state changes to `paused` or `hidden`, immediately halt active analysis and free ephemeral search states.
- Maintain Hash memory limits strictly at 16MB (live play) and 32MB (analysis) on mobile.

## Review Focus

1. **Native Thread Race in `_stopCurrentSearchAndWait`:** If `_searchInFlight` is true, the engine must block until `bestmove` is read before allowing any subsequent `position` or `ucinewgame` command.
2. **`stopAnalysis()` direct write collision:** Calling `stopAnalysis()` must not write raw commands that interleave with queued commands or leave unmonitored searches running.
3. **Event Loop Starvation in `analyzeFullGame`:** Full-game analysis across 60+ moves must yield to the Dart event loop between plies so Android input events are processed.
4. **Lifecycle Interruption:** Backgrounding or turning off the screen (`SCREEN_OFF`) while `analyzeFullGame()` is running must cancel the analysis loop cleanly without hanging the main thread.
5. **Move Classification Regression:** Ensure `classifyMoveCpl` correctly preserves mate miss logic and passes all label tests.

---

### Task 1: Fix `classifyMoveCpl` Mate-Handling & Clean Failing Tests

**Files:**
- Modify: `lib/models/analysis_model.dart:536-554`
- Modify: `test/engine_threefold_repetition_test.dart:83-94,140-146`
- Test: `test/move_classification_labels_test.dart`
- Test: `test/engine_threefold_repetition_test.dart`

- [ ] **Step 1:** Run `test/move_classification_labels_test.dart` to verify the failure:
  `flutter test test/move_classification_labels_test.dart`
- [ ] **Step 2:** In `lib/models/analysis_model.dart`, fix the mate handling in `classifyMoveCpl`:
  When `isMateBefore` is true and `actualMove.toLowerCase() != bestMove?.toLowerCase()`, if `isMateAfter` is true (or mate was lost), classify as `MoveClassification.miss` unless centipawn loss exceeds 200 (which is blunder).
- [ ] **Step 3:** Re-run `test/move_classification_labels_test.dart` and verify it passes.
- [ ] **Step 4:** In `test/engine_threefold_repetition_test.dart`, update the test cases to pass realistic board FENs that match the played move sequences so `_movesLeadToFen` validates properly.
- [ ] **Step 5:** Run `flutter test test/engine_threefold_repetition_test.dart` and verify all tests pass.
- [ ] **Step 6:** Commit the fixes:
  `git commit -am "fix(analysis): restore mate miss classification and threefold repetition test inputs"`

---

### Task 2: Eliminate Native SIGSEGV Races in `StockfishService`

**Files:**
- Modify: `lib/core/services/stockfish_service.dart:1860-1940`
- Test: `test/stockfish_crash_prevention_test.dart`
- Test: `test/remediation_audit_test.dart`

- [ ] **Step 1:** In `lib/core/services/stockfish_service.dart`, refactor `_stopCurrentSearchAndWait()`:
  - If `_searchInFlight` is true (or `_isEngineBusy`), always require `bestmove` to be received before completing.
  - Do NOT complete on `readyok` alone when a search was in flight; Stockfish UCI emits `readyok` while worker threads are still running.
  - Implement a hard failsafe timeout: if `bestmove` does not arrive within 1500ms, kill the engine isolate and cleanly restart.
- [ ] **Step 2:** Refactor `stopAnalysis()` in `lib/core/services/stockfish_service.dart`:
  - Invalidate `_activeSearchId++`.
  - Enqueue the `stop` command through the serialized execution pipeline rather than firing unmonitored raw isolate writes that race with `_commandQueue`.
- [ ] **Step 3:** Refactor `newGame()` in `lib/core/services/stockfish_service.dart`:
  - Ensure any in-flight search is completely stopped and awaited before `ucinewgame` is sent.
  - Wait for `isready`/`readyok` after `ucinewgame` before clearing the command queue.
- [ ] **Step 4:** Run `flutter test test/stockfish_crash_prevention_test.dart` to verify all race prevention and engine lifecycle scenarios pass.
- [ ] **Step 5:** Commit:
  `git commit -am "fix(engine): enforce bestmove barrier in stopCurrentSearchAndWait to prevent SIGSEGV"`

---

### Task 3: Mitigate UI Thread Starvation & `PlatformTaskQueue` ANRs

**Files:**
- Modify: `lib/core/services/stockfish_service.dart:1500-1615`
- Modify: `lib/providers/analysis_provider.dart:600-650,880-920`
- Test: `test/analysis_screen_test.dart`
- Test: `test/full_game_analysis_test.dart`

- [ ] **Step 1:** In `lib/core/services/stockfish_service.dart`, optimize `_handleEngineStdoutLine` and the analysis stream listener:
  - Fast-path check `trimmedLine.startsWith('info depth')` before running regular expressions.
  - Throttle `onUpdate` callbacks to a minimum interval of 250ms or completed depth increments ($\ge 8$), preventing microtask event floods on the main isolate.
- [ ] **Step 2:** In `lib/providers/analysis_provider.dart`, inside `analyzeFullGame()`:
  - Add an asynchronous cooperative yield between plies: `await Future<void>.delayed(const Duration(milliseconds: 16));` (1 frame interval) so the Android main thread and Flutter PlatformTaskQueue can process touch inputs and Choreographer frame callbacks without triggering ANR timeouts.
- [ ] **Step 3:** Run `flutter test test/full_game_analysis_test.dart` and verify game analysis completes smoothly.
- [ ] **Step 4:** Commit:
  `git commit -am "perf(analysis): throttle engine output parsing and yield between plies to prevent ANRs"`

---

### Task 4: Fix `SCREEN_OFF` Broadcast Timeout & Background Lifecycle Handling

**Files:**
- Modify: `lib/core/services/stockfish_lifecycle_observer.dart:25-55`
- Modify: `lib/providers/analysis_provider.dart`
- Test: `test/lifecycle_test.dart` (or create unit test for lifecycle stop)

- [ ] **Step 1:** In `lib/providers/analysis_provider.dart`, expose a public static or notifier method `cancelRunningAnalysis()` that aborts any active `analyzeFullGame()` immediately and resets `_isAnalyzing = false`.
- [ ] **Step 2:** In `lib/core/services/stockfish_lifecycle_observer.dart`, handle `AppLifecycleState.paused` and `AppLifecycleState.hidden`:
  - Call `AnalysisNotifier.cancelRunningAnalysis()` to immediately abort full-game analysis passes.
  - Call `StockfishService.instance.stopAnalysis()` to halt any bot move or position search.
  - Evict puzzle and eval caches to release heap memory.
- [ ] **Step 3:** Add/run unit tests to verify that lifecycle transitions halt analysis and engine activity cleanly.
- [ ] **Step 4:** Commit:
  `git commit -am "fix(lifecycle): cancel active full game analysis on pause/hidden to prevent broadcast ANRs"`

---

### Task 5: Cap Memory Footprint to Prevent `OutOfMemoryError`

**Files:**
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/core/services/stockfish_service.dart:405-410,1800-1815`
- Test: `test/engine_initialization_test.dart`

- [ ] **Step 1:** In `lib/core/constants/app_constants.dart`, define:
  - `static const int livePlayHashMb = 16;` (reduced from 32MB)
  - `static const int analysisHashMb = 32;` (reduced from 64MB)
- [ ] **Step 2:** In `lib/core/services/stockfish_service.dart`, update `initialize()` and `_analysisHashMb` to use these safer limits on mobile platforms.
- [ ] **Step 3:** In `lib/providers/analysis_provider.dart` `dispose()`, ensure `_stockfish?.newGame()` or TT clear is scheduled so memory is released when leaving the analysis screen.
- [ ] **Step 4:** Run `flutter test test/engine_initialization_test.dart` to verify initialization with new Hash parameters.
- [ ] **Step 5:** Commit:
  `git commit -am "perf(memory): cap Hash table memory to 16MB/32MB to prevent JVM/native OOM"`

---

### Task 6: Full Verification & Test Suite Cleanliness

- [ ] **Step 1:** Run `flutter test` across the entire project.
- [ ] **Step 2:** Verify that all tests pass (or any legacy UI mock test failures are cleanly resolved).
- [ ] **Step 3:** Run `flutter analyze` to ensure 0 errors and 0 warnings.
