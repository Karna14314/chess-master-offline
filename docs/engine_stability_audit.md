# Engine Stability Audit & Fix Log

> **Purpose:** Living document for the Engine Stability Fix Loop.
> Every issue below is discovered against the *current* code state, fixed in strict
> priority order (P0 → P3), verified with tests before moving on, and logged here.
>
> Created: 2026-08-01
> Status: Fix loop in progress

---

## Issue Summary

| ID | Severity | File | Line(s) | One-line description |
|----|----------|------|---------|----------------------|
| P0-1 | Critical | `lib/core/models/chess_models.dart` | 62-73 | `bestmove (none)` / `0000` pass `isValid`, then `_makeBotMove` plays a garbage move or silently hangs |
| P0-2 | Critical | `lib/core/services/stockfish_service.dart` | 596-638 | Bestmove listener attached *before* `_stopCurrentSearchAndWait()`; a stale `bestmove` from a prior search can complete a new search's completer |
| P1 | High | `lib/providers/game_session_viewmodel.dart` / `stockfish_service.dart` | 71 / 643 | Threefold repetition never detected: board rebuilt from FEN each ply, engine gets FEN-only position |
| P2 | Medium | `lib/core/services/stockfish_service.dart` | 330-365, 415-442, 596-635, 781-857, 937-959 | `_outputController` subscriptions not guaranteed cancelled on every exit path |
| P3-a | Low | `lib/providers/engine_provider.dart:163` + `lib/core/services/stockfish_service.dart:584-587` | — | `setSkillLevel` fired twice per bot move (provider + service `elo` path) |
| P3-b | Low | `lib/screens/settings/settings_screen.dart:319`, `lib/screens/settings/about_screen.dart:82` | — | Stale "Stockfish 16 / 16.1" labels; actual engine is Stockfish 17 |
| P3-c | Low | `stockfish_service.dart` / `game_provider.dart` / `lightweight_engine_service.dart` | 304-325, 1044-1046 | Dead code: `_configureEngine()`, `_waitForReady()`, `_stopEngineIsolate()`; partially-used `game_provider`; production-unused `LightweightEngineService` |

---

## P0-1 — `bestmove (none)` / `0000` accepted as a legal move

**Current buggy behavior**
When Stockfish has no legal move (checkmate, stalemate, or a draw it recognizes), it
reports `bestmove (none)` (and some builds report `bestmove 0000`).
`BestMoveResult.isValid` is:

```dart
bool get isValid => bestMove.isNotEmpty && bestMove.length >= 4;
```

`(none)` is length 6 → `isValid == true`. `parsedMove` then yields
`from = "(n"`, `to = "one"`, `promotion = ")"`. `_makeBotMove` calls `makeMove(...)`
with that garbage, `chess.Chess.move()` returns `false`, and `_makeBotMove` silently
does nothing — the bot's turn never resolves, the clock was already paused, and the
game hangs.

**Root cause**
The validity check only guards emptiness/length; the UCI "no legal move" sentinels
`(none)` and `0000` are not rejected. `_makeBotMove` (`game_session_viewmodel.dart:197`)
has no branch for "engine reported no legal move".

**Planned fix**
1. `BestMoveResult`: reject the sentinels in `isValid`, make `parsedMove` return
   `('', '', null)` for them, and add `bool get isNoMove`.
2. `_makeBotMove`: when the engine returns `(none)`/`0000` (or an unparseable move),
   re-check the board for checkmate / stalemate / draw and record the result instead
   of silently doing nothing. Never play a garbage move, never leave the bot turn hung.

**Tests**
- Unit: `BestMoveResult(bestMove: '(none)')` → `isValid == false`, `isNoMove == true`,
  `parsedMove == ('', '', null)`; same for `0000`; valid moves unaffected.
- Service: inject `bestmove (none)` through the output stream → result flags `isNoMove`.
- Integration: forced-mate position where the bot is to move — the bot move path
  completes the game with a checkmate result instead of hanging.

---

## P0-2 — Bestmove listener race in `getBestMove`

**Current buggy behavior**
In `getBestMove`, the bestmove listener is attached (line ~597) *before*
`_stopCurrentSearchAndWait()` (line ~638). If a previous search is still winding down,
its terminating `bestmove` line is delivered to the broadcast stream after the new
listener has subscribed. The new listener consumes the stale line and completes the new
search's completer with the *old* move (and possibly an empty/partial evaluation) before
the new position is even sent.

**Root cause**
1. Listener attach ordering: listener subscribed before the previous search is stopped.
2. No per-search identity token: any `bestmove` line matches any pending completer.
3. `_isEngineBusy` is claimed late (line 657), after several `await`s, so two callers can
   both pass the busy guard and run two searches at once.

**Planned fix**
1. Claim the engine slot synchronously (`_isEngineBusy = true`) immediately after the
   busy guard, so overlapping calls are rejected atomically.
2. Attach the bestmove listener only after `_stopCurrentSearchAndWait()` completes.
3. Add a per-search id token (`_activeSearchId`); listeners discard `bestmove` lines whose
   token does not match the current search.
4. Ensure `_searchInFlight` (true only between `go` and `bestmove`) drives
   `_stopCurrentSearchAndWait`, so it never waits on a non-existent search.

**Tests**
- Overlapping two calls: first call claims the engine, second returns fallback without
  hanging; the first call completes with its own injected `bestmove`, not the other's.
- Search-token: after a search completes, a late/duplicate `bestmove` line does not
  corrupt the next search.

---

## P1 — Threefold repetition never detected

**Current buggy behavior**
A threefold-repetition draw can never trigger, in the app or the engine:

* App side: `GameSessionViewModel.makeMove` (`game_session_viewmodel.dart:71`) rebuilds
  `chess.Chess.fromFEN(currentSession.fen)` on every ply, so the board's internal history
  is always one move. `chess.Chess.in_threefold_repetition` replays history and can never
  count 3 occurrences.
* Engine side: the only position command is `position fen <currentFen>`
  (`stockfish_service.dart:643` and `:869`). Stockfish is never told the starting FEN or
  the move list, so it cannot detect repetition either.

**Root cause**
No persistent board state in the viewmodel and FEN-only position setup with the engine.

**Planned fix**
1. ViewModel: replace the per-move `fromFEN(currentSession.fen)` rebuild with a board
   reconstructed from `startingFen` + full `moveHistory` (same pattern `undoMove` already
   uses at line 296), so history (and therefore repetition) is preserved.
2. Service: add optional `startingFen` + `moves` (UCI) to `getBestMove`/`analyzePosition`
   and emit `position fen <startingFen> moves <uci...>` when provided.
3. Plumb session `startingFen` + `moveHistory` (as UCI) through `EngineNotifier.getBotMove`
   and `getHint`, and from `_makeBotMove`/`useHint`.

**Tests**
- ViewModel: play a known perpetual (e.g. knight shuffle back to the start position 3×)
  and assert the session completes with `GameResult.draw` / `Threefold repetition`.
- Service: unit-test the position command builder
  (`position fen <start> moves e2e4 e7e5 ...`).
- Reloaded-session variant: restore a session from `fromMap` with the same move history
  and repeat the assertion.

---

## P2 — Stream subscription lifecycle leaks

**Current buggy behavior**
Several methods subscribe to `_outputController` without a guaranteed cancel on every exit
path:
* `_waitForReadyOk` (330-365) — cancels on `readyok`/timeout/catch, but relies on scatter
  and does not use `finally`.
* `_waitForOutputPattern` (415-442) — same pattern.
* `getBestMove` listener (596-635) — an early return at line 651 cancels, and the timeout
  handler cancels, but the `finally` at 687 does not cancel the subscription (the listener
  is only cancelled inside the `bestmove` branch).
* `analyzePosition` listener (781-857) — same.
* `_stopCurrentSearchAndWait` (937-959) — cancel only on timeout/catch.

Because `_outputController` is a broadcast controller, leaked subscriptions accumulate and
are never GC'd until the app exits.

**Root cause**
Subscription cancellation is not centralized and not guaranteed in `finally` on all paths.

**Planned fix**
Refactor each subscription site so the subscription is tracked and cancelled in a `finally`
block covering the whole method body (including early returns and timeout handlers).

**Tests**
- Timeout path (search + `_waitForReadyOk`) leaves zero listeners on the output stream
  (`@visibleForTesting` accessor for `hasListener`).
- 20× forced-timeout stress test: repeat the timeout path and assert no listener leak and
  no crash on any iteration.

---

## P3-a — `setSkillLevel` sent twice per bot move

**Current buggy behavior**
`EngineNotifier.getBotMove` calls `_service.setSkillLevel(difficulty.elo)`
(`engine_provider.dart:163`) *and* passes `elo` into `getBestMove`, which calls
`setSkillLevel(elo)` again plus a `_waitForReadyOk` (`stockfish_service.dart:584-587`).
Redundant UCI traffic on every move; contradicts the roadmap's Phase 3 claim that strength
config was moved to `resetForNewGame`.

**Planned fix**
Keep the provider-level call (which already runs once per game via `resetForNewGame`) and
remove the redundant per-move `setSkillLevel`/`_waitForReadyOk` from `getBestMove`; the
`elo` parameter is no longer needed on the service path (or keep it but stop re-sending).

---

## P3-b — Stale engine version labels

**Current buggy behavior**
`settings_screen.dart:319` reports "Stockfish 16"; `about_screen.dart:82` reports
"Stockfish 16.1". The bundled engine is Stockfish 17 (`stockfish_chess_engine ^0.8.2`).

**Planned fix**
Update both labels to "Stockfish 17".

---

## P3-c — Dead code

**Current state**
* `_configureEngine()` (`stockfish_service.dart:304-308`) — never called.
* `_waitForReady()` (`:311-325`) — never called.
* `_stopEngineIsolate()` (`:1044-1046`) — never called; `_killEngineIfRunning` is used.
* `game_provider.dart` `GameNotifier` — used only by `analysis_menu_screen.dart:18`
  (`ref.watch(gameProvider)`); the live game flow uses `gameSessionProvider`. NOT removed;
  only flagged, since removing it would break the analysis menu and many tests.
* `LightweightEngineService` — unused in production (`lib/`), but exercised by
  `lightweight_engine_test.dart`, `bug_fixes_test.dart`, and a benchmark. Marked as dead in
  production rather than deleted so the existing tests remain green.

**Planned fix**
Delete `_configureEngine()`, `_waitForReady()`, `_stopEngineIsolate()`. Add deprecation
notes to `LightweightEngineService` and `GameNotifier`; do not delete (external references).

---

## Fix Log

_Every completed fix is appended here with the verification command(s) and a summary of the
output._

| # | Issue | Fix summary | Verification command | Result |
|---|-------|-------------|----------------------|--------|
| 1 | P0-1 | Rejected `(none)`/`0000` in `BestMoveResult.isValid`/`parsedMove`, added `isNoMove`; `_makeBotMove` now re-checks game-end conditions when the engine reports no legal move instead of silently hanging; extracted shared `_terminalResult` helper; added `triggerBotMoveForTesting()` hook. Also hardened `AchievementNotifier` against post-dispose use (debug `mounted` throw). | `flutter test test/engine_no_legal_move_test.dart` + regression (achievements, stockfish_service, game_undo, engine_evaluation, engine_difficulty) | 7/7 new tests pass; 46 regression tests pass |
| 2 | P0-2 | Reworked the search pipeline in `stockfish_service.dart`: atomic `_isEngineBusy` claim (no await between check and claim), bestmove listener attached only after `_stopCurrentSearchAndWait()`, per-search `_activeSearchId` token discards stale `bestmove` lines, `_searchInFlight` drives stop-wait, all subscriptions cancelled in `finally`. Added test hooks (`setReadyForTesting`, `emitEngineLineForTesting`, `hasOutputListenersForTesting`, injectable timeouts). | `flutter test test/engine_search_race_test.dart` + full engine suite | 5/5 new tests pass; 192 engine tests pass |
| 3 | P1 | Threefold repetition now works end-to-end: `GameSessionViewModel._reconstructBoard` rebuilds the board from `startingFen` + full `moveHistory` (with a FEN fallback for inconsistent/legacy sessions) instead of `fromFEN(currentSession.fen)` each ply; the engine is now told the full move list via `buildPositionCommand` (`position fen <start> moves <uci...>`) from both `getBestMove` and `analyzePosition`, plumbed through `EngineNotifier.getBotMove`/`getHint` and `_makeBotMove`/`useHint`. | `flutter test test/engine_threefold_repetition_test.dart` + engine/game regression | 6/6 new tests pass (3 command-builder unit + 1 send-path capture + 2 viewmodel incl. reloaded-session); 211 regression tests pass |
| 4 | (pre-existing) | Fixed a broken pre-existing widget test: `test/widget_test.dart` never mocked SharedPreferences nor pumped past the onboarding `FutureBuilder`, so `MainScreen`/`BottomNavigationBar` never rendered and the test always failed. Now sets `has_completed_onboarding: true` and `pumpAndSettle()`s. | `flutter test test/widget_test.dart` | 1/1 passes (was failing before this fix loop touched it) |
| 5 | P2 | Refactored every `_outputController` subscription site so the subscription is tracked and cancelled in a `finally` covering all exit paths: `_waitForReadyOk`, `_waitForOutputPattern`, and `_stopCurrentSearchAndWait` (the `getBestMove`/`analyzePosition` listeners were already `finally`-cancelled in P0-2). Timeout handlers now complete the completer (instead of racing a cancel) and the subscription is cancelled once in `finally`. Also added `isEngineBusyForTesting` accessor. Fixed a pre-existing broken SimpleBot eval test whose FEN contained no mate-in-1 (comment claimed Qxf7# but the queen was on d1 and the search exceeded the 900 ms time limit); replaced with a library-verified mate-in-1 (`Re1-e8#`, king boxed by its own pawns). | `flutter test test/engine_listener_lifecycle_test.dart` + full engine suite | 4/4 new tests pass (search timeout, ready-ok timeout, analysis timeout, 20× stress); 234 engine/widget regression tests pass |
| 6 | P3-a | Removed the duplicate per-move `setSkillLevel`/`_waitForReadyOk` call from `StockfishService.getBestMove`: the `elo:` parameter is gone from the public signature and `EngineNotifier.getBotMove` no longer passes `difficulty.elo`. Strength is now configured exactly once per game via `setSkillLevel` in `resetForNewGame`/`startGame` (unchanged). Updated all three mock/override `getBestMove` implementations (widget_test, analysis_benchmark_test, engine_no_legal_move_test). | `flutter test test/engine_difficulty_test.dart test/engine_no_legal_move_test.dart test/engine_search_race_test.dart test/engine_threefold_repetition_test.dart test/engine_listener_lifecycle_test.dart test/widget_test.dart test/analysis_benchmark_test.dart` + engine regression | 36/36 pass; 184 additional engine tests pass |
| 7 | P3-b | Updated stale engine labels to the bundled Stockfish 17: `settings_screen.dart:319` ("Stockfish 16") and `about_screen.dart:82` ("Stockfish 16.1"). | `flutter analyze` | No references to old labels remain (no test asserts the labels) |
| 8 | P3-c | Deleted dead code in `stockfish_service.dart`: `_configureEngine()`, `_waitForReady()`, `_stopEngineIsolate()` (and the now-unreferenced `_killEngineGracefully()`), plus unused fields `_stockfish` and `_isEngineBinaryReady` (never read). Added doc-comment deprecation notes to `GameNotifier` (`game_provider.dart`) and `LightweightEngineService` (kept, external references). Also fixed 7 pre-existing analyzer warnings unrelated to the engine loop: stale `_StatsCardLoading`/`_StatsCardError` widgets and an unused `chess` import in the puzzle screens, an unreachable `default:` in `puzzle_provider`, an unused `_transpositionTable` field, and two `game_history_screen` lints (unawaited `ref.refresh` → `ref.invalidate`, unnecessary `?.`). | `flutter analyze` | 0 warnings / 0 errors (only pre-existing `info`-level `avoid_print` in scripts/benchmarks remain) |
| 9 | (pre-existing) | Fixed two more pre-existing broken tests that surfaced in the full suite: (1) `cross_promotion_test.dart` asserted a "Mahjong Master Offline" tile that no longer exists in `MoreScreen` — removed the stale assertion (screen shows Block Puzzle Master + Sudoku Master Offline). (2) `puzzle_logic_test.dart` failed with an unhandled `MissingPluginException` because `AudioService.instance` eagerly constructs `AudioPlayer`s, whose async create throws in a plain `test()` with no host platform — added mock handlers for the `xyz.luan/audioplayers` and `.global` method channels in `setUp`. | `flutter test` (full suite) | Full suite green: 315/315 |
| 10 | (flaky, observed) | One pre-existing SimpleBot determinism test (`engine_search_optimization_test.dart` "search is consistent across repeated calls") failed once under full-suite load but passes in isolation and in subsequent full runs — pre-existing flake unrelated to the engine loop. Documented, no code change. | `flutter test test/engine_search_optimization_test.dart` + full suite | Passes in isolation and in final full run |

---

## Verification Summary

_Appended at the end of the loop: `flutter test`, `flutter analyze`, `flutter build apk --debug`._
