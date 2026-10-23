# ChessMaster Offline — Stability Stabilisation (v1.0.92)

**Branch:** `fix/stability-1.0.92` (from `master`)  
**PR:** draft, targets `master`  
**Goal:** Fix production crashes (SIGSEGV) and ANRs reported in Play Console v1.0.92. Bug fixes only — no new features, no UI changes, no refactors beyond what the fixes need.

> Status: Phase 0 (audit) complete. Baseline verification run; two engine-safety fixes applied (getBestMove now sends `startingFen`+`moves` for repetition detection; sanitizeFen test assertion corrected to match documented clamp behavior).

---

## 1. How Stockfish is integrated

| Item | Finding | Evidence |
|------|---------|----------|
| Packaging | Third-party pub package `stockfish_chess_engine: ^0.8.2` (FFI binding to the Stockfish native binary). NOT vendored C++; no native `cpp`/`cc` sources under `android/`. | `pubspec.yaml:21`; `android/` contains no `.cpp/.cc/.c` files |
| Native kept by ProGuard | `stockfish.**` classes kept | `android/app/proguard-rules.pro:15` |
| Threading model | Engine runs in a **separate Dart Isolate** (`_stockfishIsolateEntrypoint`). Commands flow `main isolate → SendPort → engine isolate → Stockfish.stdin`; output flows `Stockfish.stdout → ReceivePort → _outputController broadcast stream → main isolate listeners`. | `stockfish_service.dart:1734` (`Isolate.spawn`), `:1949` (`stockfish.stdin = command`), `:1812` (`_outputController.add(line)`) |
| Service layer | `StockfishService` singleton + `EngineNotifier` Riverpod `StateNotifier`. All engine I/O is async via ports; nothing blocks the Dart main/UI isolate synchronously. | `stockfish_service.dart:51` (`class StockfishService`), `engine_provider.dart:84` (`class EngineNotifier`) |
| Output consumption | `_outputController` is a **broadcast** stream. Consumers are internal to `stockfish_service.dart` (search/analysis listeners, `_waitForReadyOk`, `_stopCurrentSearchAndWait`). No UI widget subscribes per info-line; `EngineStatusIndicator` watches `statusNotifier` (a `ValueNotifier`), not `outputStream`. | `stockfish_service.dart:94,137`; `engine_status_indicator.dart:13` |
| Flutter SDK constraint | `sdk: ^3.7.0-0` (Dart 3.x). Platform and UI threads are still distinct in this Flutter line; UI-isolate jank does not automatically merge into the Android main ANR bucket. | `pubspec.yaml:7` |

## 2. Mapped engine entry points and lifecycle

| Entry point | Dart method | What it sends / does | File:line |
|-------------|-------------|----------------------|-----------|
| init / UCI handshake | `StockfishService.initialize()` | Spawn isolate → `init` → `uci` (wait `uciok`) → setoptions Threads/Hash/UCI_LimitStrength → `isready` (wait `readyok`) | `stockfish_service.dart:224` |
| ucinewgame | `StockfishService.newGame()` | `ucinewgame` (via serialized `_executionQueue`) | `stockfish_service.dart:1700` |
| position | `buildPositionCommand()` + `_sendCommand('position fen ...')` | `position fen <sanitizedFen>` or `position fen <start> moves <uci...>`; validated FEN + legal move list | `stockfish_service.dart:854,1041,1477` |
| go | `_sendCommand('go movetime N')` / `'go depth N'` / `'go nodes N'` | Time/depth/node bounded search | `stockfish_service.dart:1064,1067,1504` |
| stop | `StockfishService.stopAnalysis()` | `stop` + `isready` to engine port (sync, fire-and-forget) | `stockfish_service.dart:1649` |
| stop-and-wait | `_stopCurrentSearchAndWait()` | `stop` + `isready`, wait for `bestmove`/`readyok` (3s timeout, kill+fallback on stall) | `stockfish_service.dart:1665` |
| dispose | `StockfishService.dispose()` | `quit` + `dispose` to isolate, kill isolate, clear queue, null ports | `stockfish_service.dart:1710` |
| app pause/hidden | `StockfishLifecycleObserver.didChangeAppLifecycleState` | `service.stopAnalysis()` + `PuzzleNotifier.evictCache()` | `stockfish_lifecycle_observer.dart:32-41` |
| app detached | same observer | `service.stopAnalysis()` + cache evict | `stockfish_lifecycle_observer.dart:47-53` |
| app resume/inactive | same observer | debug log only (no engine restart; resume is lazy via `initialize()`/`resetForNewGame`) | `stockfish_lifecycle_observer.dart:44-46` |
| observer registration | `main()` | `StockfishLifecycleObserver.ensureRegistered()` at startup; `ensureUnregistered()` **never called** | `main.dart:17`; `stockfish_lifecycle_observer.dart:20` |
| service dispose wiring | None in production | `EngineNotifier.dispose()` (engine_provider.dart:492) calls only `stopAnalysis()`, **not** `service.dispose()`. `StockfishService.dispose()` has no production caller. Isolate leaks until process exit. | `engine_provider.dart:492-496` |

Live-play resource defaults (stability-oriented, already in place):
- `livePlayThreads = 1`, `livePlayHashMb = 16` (`stockfish_service.dart:1576-1577`)
- Analysis: `maxAnalysisThreads = 1`, `analysisHashMb = 64` (`:1592-1593`)
- Difficulty depth/thinkTime caps in `AppConstants.difficultyLevels` (depth 1..22, thinkTimeMs 300..2500) (`app_constants.dart:23-94`)

## 3. Hypothesis audit

Verdicts: **confirmed** = evidence shows the issue exists today / fix is present and adequate; **refuted** = evidence shows the cause cannot occur; **unknown** = no conclusive evidence either way. Confidence is subjective (high/medium/low).

### SIGSEGV clusters (`is_draw` ×10, `search<NonPV>` ×2)

| # | Hypothesis | Evidence (file:line) | Verdict | Confidence |
|---|------------|----------------------|---------|------------|
| H1 | `position`/`go`/`ucinewgame` sent while a search is running, without `stop` + awaiting `bestmove` | `getBestMove` calls `_stopCurrentSearchAndWait()` before `position`/`go` (`:957`, `:1041-1068`). `analyzePosition` calls `_stopCurrentSearchAndWait()` before `position`/`go` (`:1275`, `:1477-1504`). BUT `newGame()` (`ucinewgame`), `setSkillLevel`, `setMaxStrength` are enqueued on `_executionQueue` **without** first stopping an in-flight search (`:1700`, `:1552`, `:1566`). `EngineNotifier.resetForNewGame` fires `stopAnalysis()` (non-awaited stop) then queues `setSkillLevel`+`newGame` (`engine_provider.dart:470-478`). | **Partially mitigated** — `go`/`position` are stop-wait guarded; `ucinewgame` during an in-flight search is serialized behind the current search but not preceded by an awaited stop. Residual risk low but not zero. | medium |
| H2 | `dispose`/`quit` during in-flight search; use-after-dispose; double init; multiple instances; re-init on resume | `_isDisposed` guards on every engine entry (`getBestMove :903`, `analyzePosition :1216`, `setSkillLevel :1553`). `dispose()` is idempotent and deduped via `_disposeFuture` (`:1710-1713`). Isolate death/exit handlers disable engine + fallback (`:1768`, `:1784`). `initialize()` returns early if already ready (`:234`) and retry-resets state (`:354`). **No production caller** of `service.dispose()`; notifier dispose only stops analysis (`engine_provider.dart:492`). | **Confirmed mitigated** for use-after-dispose/double-init/multiple-instances (guards + serialization present). **Unverified** that full isolate tear-down happens on app exit (leak, not crash). | high (guards) / low (tear-down wiring) |
| H3 | Invalid FEN or illegal move list (undo, promotion, castling, repetition history) sent to engine | `_isValidFen` (board structure, king counts, adjacency, castling, ep, halfmove/fullmove) (`:668-831`). `sanitizeFen` clamps halfmove/fullmove (`:835-849`). `_areMovesLegal` replays UCI moves via `chess.Chess.move()` (`:604-635`). `buildPositionCommand` rejects illegal sequences, falls back to FEN-only (`:854-877`). `getBestMove`/`analyzePosition` validate before sending (`:897`, `:1166`). | **Confirmed mitigated** — FEN + move-list validation present and exercised. | high |
| H4 | Search-thread stack overflow (Android default stack small). Threads/Hash/depth/skill/movetime | Live play pinned to `Threads=1`, `Hash=16MB` (`:1576-1577`); analysis `Threads=1`, `Hash=64MB` (`:1592-1593`). Max depth 22 (`app_constants.dart:90`). No explicit pthread stack-size configuration. | **Unknown** — no code evidence of stack overflow; small Threads/Hash mitigate it. Cannot confirm/crash without a device. | low |
| H5 | Concurrent callers (AI move + hint + analysis) hitting engine at once | `_isEngineBusy` atomic claim before search (`getBestMove :947`, `analyzePosition :1259`); second caller returns fallback. `_executionQueue` serializes all commands (`:26-49`). | **Confirmed mitigated** — concurrency guards present; overlapping callers degrade to fallback rather than racing native code. | high |

### ANR clusters

| # | Hypothesis | Evidence (file:line) | Verdict | Confidence |
|---|------------|----------------------|---------|------------|
| A1 | Engine `info` lines handled on UI isolate; every line triggers `setState` (output flood) | `_outputController` listeners are internal to `stockfish_service.dart` only. UI does **not** subscribe per info-line. `analysis_provider._analyzeCurrentPosition` `onUpdate` calls `state = state.copyWith(...)` but is throttled: `now.difference(lastUiUpdate).inMilliseconds >= 100` (`:1396-1397`) ≈ up to 10 UI updates/sec, above the task's ~5/sec (200ms) target. | **Partially mitigated** — no per-line UI setState; live-analysis progressive updates are throttled but at 100ms, not 200ms. Tighten to ~200ms to reduce UI-thread pressure. | medium |
| A2 | Blocking engine call (sync FFI, dispose/join, waiting for readyok) on main isolate | Engine I/O is entirely asynchronous via Dart Isolate ports (`send`/`listen`). `_waitForReadyOk`/`_stopCurrentSearchAndWait` are `async` with timeouts, never blocking the UI isolate. No synchronous FFI. | **Refuted** — engine I/O never blocks the Dart main/UI isolate. | high |
| A3 | Heavy sync Dart work on UI isolate (move gen, PGN parsing, JSON/asset loading, DB) | `goToMove` rebuilds `chess.Chess` from `startingFen` + history (`game_session_viewmodel.dart:101-113`). `analysis_provider.analyzeFullGame` loops plies with `OpeningService` asset lookups (`:504`) and sqflite DB cache reads/writes (`:339`, `:1028`) — DB calls are async. `board.pgn()` called in `makeMove` (`game_session_viewmodel.dart:187`). | **Unknown / partially mitigated** — work is bounded per move and mostly async/cached, but PGN generation and board rebuilds run on the UI isolate per navigation/move. No evidence of an unbounded synchronous block. | medium |
| A4 | Memory/GC pressure: unbounded lists, retained engine lines, streams/listeners never closed | `_outputController` broadcast controller is **never closed** (`stockfish_service.dart:94`; no `close()` anywhere). Subscriptions are cancelled in `finally` on all search paths (`:992`, `:1434`, `:1534-1538`, `:1693`). `lines` lists bounded by `multiPv` (≤3). No unbounded accumulation found. | **Partially confirmed** — broadcast controller never closed (minor, lives for process lifetime); no unbounded list growth found. | medium |
| A5 | Engine still running when app backgrounded ("No focused window" ANRs) | `StockfishLifecycleObserver` stops search on `paused`/`hidden`/`detached` (`stockfish_lifecycle_observer.dart:32-53`). Registered in `main.dart:17`. Resume is lazy (no auto restart). | **Confirmed mitigated** — search stopped on background/detach. | high |

### Additional notes
- Existing prior fix work is present in-tree (documented in `docs/engine_stability_audit.md`): sentinel `(none)`/`0000` rejection, per-search tokens, `_isEngineBusy` atomic claim, finally-cancelled subscriptions, `setSkillLevel` removed from per-move path, threefold repetition via `position fen <start> moves ...`, Stockfish-17 labels, dead-code removal. These map to H3/H5/H2 mitigations above.
- Residual gaps to address in Phases 1–2: (a) `ucinewgame`/`setSkillLevel` not preceded by an awaited stop during an in-flight search (H1); (b) live-analysis UI throttle at 100ms instead of ~200ms (A1); (c) `_outputController` never closed (A4); (d) `StockfishService.dispose()` not wired to app/notifier teardown (H2 tear-down); (e) add a watchdog restart-on-hang (A2-adjacent); (f) tests for every behaviour changed.

## 4. Plan

- Phase 1: Engine safety layer — single serialized controller with state machine (idle/searching/stopping/disposed), stop-then-await-bestmove before position/go/ucinewgame, idempotent timed dispose, generation token, FEN/move validation, safe Threads/Hash/movetime/depth defaults. Tests with a fake engine.
- Phase 2: ANR fixes — engine I/O/parsing already off UI isolate; throttle `info` to ~5 UI updates/sec, keep latest line; stop search on paused/inactive; move heavy sync work off UI isolate; fix leaks (close broadcast controller); watchdog restart-on-hang. Tests for each.
- Phase 3: Native hardening — Stockfish is a pub package (no vendored native to patch); ensure unsafe call sequences from Phase 1 cannot reach the engine; SIGSEGV cannot be caught from Dart — prevention + restart-on-hang only.
- Phase 4: Verification gate (`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`) and `docs/SESSION_FINAL.md`.

## 5. Baseline verification findings (this sandbox)

Flutter SDK was installed at `/tmp/kilo/flutter-sdk` (Flutter 3.47.7, Dart 3.13.5); this sandbox has **no Java or Android SDK**, so `flutter build apk --debug` cannot run.

| Gate step | Result | Notes |
|-----------|--------|-------|
| `flutter pub get` | PASS | `vector_math` upgraded 2.2.0 → 2.4.3 by the tool |
| `flutter analyze` | PASS | 0 warnings, 0 errors (106 info-level `avoid_print` in tests/tools) |
| `flutter test` | 474 pass / 6 fail | 6 failures are **pre-existing on master, unrelated to v1.0.92 crashes/ANRs**: `move_classification_labels` ×3 (contradicts `analysis_calibration` win%/CPL precedence — irreconcilable without breaking other tests), `statistics` K-factor ×1, `midgame_controls` ×2 (UI mismatch: test expects tooltip buttons `Undo Move`/`Engine Hint`/`Flip Board`/`Resign Game` that don't exist; `Flip Board`/`Resign Match` are popup menu items). Fixing these requires either breaking other tests or prohibited UI changes, so they are left as-is and documented. |
| `flutter build apk --debug` | NOT RUNNABLE | No Android SDK / NDK in this sandbox |

Two engine-related baseline failures were fixed in this branch:
- `getBestMove` now sends `position fen <start> moves <uci...>` (via `buildPositionCommand`) when `startingFen`+`moves` are provided, so Stockfish can detect repetition draws (`stockfish_service.dart` position command).
- `test/engine_threefold_repetition_test.dart`: corrected a `sanitizeFen` halfmove-clock assertion that contradicted the documented clamp-preserve behavior (test passed `fen` halfmove=1 but expected halfmove=0).

> Note on verification: native crashes (SIGSEGV) and ANRs cannot be reproduced in CI and cannot be exercised on a real device from this sandbox, so they are explicitly NOT-verified. The gate steps that *can* run here (`pub get`, `analyze`, `test`) are reported above; `build apk` is blocked by missing Android SDK.

