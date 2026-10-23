# ChessMaster Offline — Session Final (v1.0.92 Stability Stabilisation)

**Branch:** `fix/stability-1.0.92` (from `master` = `2efd82b`)  
**PR:** #86 — https://github.com/Karna14314/chess-master-offline/pull/86 (draft → ready)  
**Scope:** Bug fixes only — no new features, no UI changes, no refactors beyond what the fixes need.

---

## Short summary

Stabilised ChessMaster Offline (Flutter + Stockfish) against Play Console v1.0.92 production data (34 events: 22 ANR, 12 crash). Stockfish is integrated via the `stockfish_chess_engine: ^0.8.2` pub package (FFI) running in a **separate Dart Isolate** — it is NOT vendored C++, so there is no native source to patch. A SIGSEGV cannot be caught from Dart; the only options are prevention (serialized command queue, stop-then-await-bestmove, FEN/move validation, safe Threads/Hash/depth defaults) and restart-on-hang (`_stopCurrentSearchAndWait` kills a stalled engine and falls back). All engine access routes through `StockfishService` (the single controller), guarded by a generation token and disposed/idle-state checks.

Per-phase commits on `fix/stability-1.0.92`:
- `3e71186` docs: record v1.0.92 stability audit (Phase 0)
- `a2b877a` docs: complete Phase 0 audit with baseline verification findings
- `deb18ad` fix: harden engine safety layer (Phase 1)
- `e1d2448` fix: ANR hardening (Phase 2)

Phase 3 (native hardening) required no code change — confirmed no vendored native, no newer `stockfish_chess_engine` version, prevention + restart-on-hang only. Documented here rather than as a code commit.

---

## Files changed

| File | Change | Phase |
|------|--------|-------|
| `docs/STABILITY_PROGRESS.md` | Phase 0 audit + hypothesis verdicts + baseline verification findings | 0 |
| `docs/SESSION_FINAL.md` | This document | 4 |
| `lib/core/services/stockfish_service.dart` | `getBestMove` sends `position fen <start> moves <uci...>` via `buildPositionCommand` (repetition detection); `newGame()` stop-then-awaits bestmove before `ucinewgame`; analysis `onUpdate` throttled to ~5 UI updates/sec (200ms); `_outputController` closed on dispose and recreated in `resetTestState`; two `unawaited_return_in_try_block` lint fixes | 1, 2 |
| `test/engine_safety_race_test.dart` | New fake-engine race tests: dispose mid-search, newGame during in-flight search, rapid undo/new-game spam, concurrent-request busy fallback, re-init after dispose | 1 |
| `test/engine_threefold_repetition_test.dart` | Corrected a `sanitizeFen` halfmove-clock assertion that contradicted documented clamp-preserve behavior (test passed `fen` halfmove=1 but expected halfmove=0 output); the assertion still validates "moves segment omitted" | 0/1 |

---

## Exact verification commands and results

Run in this sandbox with Flutter installed at `/tmp/kilo/flutter-sdk` (Flutter 3.47.7, Dart 3.13.5). This sandbox has **no Java or Android SDK**, so `flutter build apk --debug` cannot execute.

```
export PATH="$PATH:/tmp/kilo/flutter-sdk/bin"
cd /workspace/app

flutter pub get          → PASS (vector_math 2.2.0 → 2.4.3 by the tool)
flutter analyze          → PASS: 0 warnings, 0 errors (104 info-level avoid_print in tests/tool)
flutter test             → 479 pass / 6 fail
flutter build apk --debug→ NOT RUNNABLE (no Android SDK / NDK in this sandbox)
```

### Test result detail

`flutter test`: **479 passed, 6 failed**. The 6 failures are **pre-existing on `master`, unrelated to v1.0.92 crashes/ANRs**, and could not be fixed within the task constraints ("no UI changes", and fixing them would break other passing tests):

| Test | Failure | Why not fixed |
|------|---------|---------------|
| `midgame_controls_test.dart` ×2 | Expects tooltip buttons `Undo Move` / `Engine Hint` / `Flip Board` / `Resign Game` that don't exist in the current UI (`Flip Board`/`Resign Match` are popup menu items; `Undo Move`/`Engine Hint` tooltips are absent) | Fixing requires UI changes, prohibited by task |
| `move_classification_labels_test.dart` ×3 | Win% vs CPL precedence contradicts `analysis_calibration_test.dart` (irreconcilable without breaking other passing tests) | Pre-existing test-suite contradiction, unrelated to crashes/ANRs |
| `puzzle_continuation_and_rating_test.dart` ×1 | `StatisticsModel.kFactor` expects 24/20/16; code returns 40/28/16 | Changing it broke `rating_progression_test.dart`; pre-existing, unrelated to crashes/ANRs |

`flutter analyze` was clean at baseline too (the 104 info-level `avoid_print` issues are pre-existing in tests/tool, not warnings/errors).

---

## Before / after for each Play Console cluster

### Crashes (SIGSEGV, libstockfish_chess_engine.so, arm64)

**1. `Stockfish::Position::is_draw(int)` — 10 events (largest cluster)**

- Before: invalid FEN or illegal move list (undo, promotion, castling, repetition history) could be sent to native Stockfish; `ucinewgame`/`position` could be sent while a search was running; stale results from old searches were accepted.
- After: `_isValidFen` + `sanitizeFen` (clamps halfmove/fullmove) validate every FEN before sending; `_areMovesLegal` rejects illegal UCI sequences; `buildPositionCommand` emits the full move list (`startingFen` + `moves`) so Stockfish detects repetition draws; stop-then-await-bestmove precedes every `position`/`go`; `newGame()` stop-then-awaits before `ucinewgame`; generation token (`_activeSearchId`) discards stale results from old searches; concurrency guard (`_isEngineBusy`) degrades overlapping callers to fallback.
- Status: mitigated in Dart. **Not CI-reproducible** (native SIGSEGV, no device).

**2. `Stockfish::Search::Worker::search<NonPV>` — 2 events**

- Before: unbounded threads/hash/depth on low-end phones; no stop-await before `go`.
- After: live play pinned to `Threads=1`, `Hash=16MB`; analysis `Threads=1`, `Hash=64MB`; depth capped at 22 (`AppConstants.difficultyLevels`); movetime/depth bounded per difficulty; stop-then-await before `go`; concurrency guard.
- Status: mitigated. **Not CI-reproducible.**

### ANRs

**1. `PlatformTaskQueue.dispatch` — "Input dispatching timed out" (16 events, top ANR; with and without "No focused window")**

- Before: engine `info` lines could flood the UI isolate (updates every 100 ms); engine could keep searching when backgrounded.
- After: all engine I/O runs on a separate Dart Isolate (no sync FFI, no main-thread block); analysis progressive UI updates throttled to ~5/sec (200 ms) keeping only the latest line; `StockfishLifecycleObserver` stops the search on `paused`/`hidden`/`detached` (lazy resume).
- Status: mitigated. **Not CI-reproducible.**

**2. `dart::StackFrame::VisitObjectPointers` (GC) — 2 events**

- Before: `_outputController` broadcast controller never closed; retained engine output.
- After: `_outputController` closed on `dispose()` and recreated fresh in `resetTestState()`; all search subscriptions cancelled in `finally` on every exit path (timeout/error/early-return); `lines` lists bounded by `multiPv` (≤3).
- Status: mitigated.

**3. Remaining ANRs** (`DartMessenger.dispatchMessageToQueue`, `MessageQueue.enqueueMessage` lock contention, `dart::DartEntry::InvokeFunction`): mitigated by async Isolate ports (no sync blocking on the UI isolate) and the info-throttle above.

**Ignored:** `com.oplus.scrollidentify.OplusScrollIdentify.markFlingEnd` (1 event) — Oppo OEM framework, per instructions.

---

## NOT-verified items

- **Native crashes (SIGSEGV) and ANRs cannot be reproduced in CI.** This sandbox has no physical device/emulator, no Android SDK, and the Stockfish native binary isn't loadable in tests (tests drive the service through `setReadyForTesting` + injected output). The fixes are prevention + restart-on-hang; correctness on real devices must be confirmed via manual QA and Android Vitals after release.
- **`flutter build apk --debug` could not run** (no Android SDK / NDK in this sandbox).
- **`flutter test` is not 100% green** due to the 6 pre-existing failures listed above (all unrelated to crashes/ANRs and not fixable within the "no UI changes" constraint without breaking other passing tests).

These are recorded in `docs/STABILITY_PROGRESS.md` per the workflow rule for items that can't be fixed.

---

## Manual QA checklist (on a physical/low-end phone)

1. Spam Undo while the AI is thinking (search running) — no crash, no ANR.
2. New-game spam (rapid `ucinewgame` during/between searches) — no crash.
3. Hint spam while a search is in flight — degrades to fallback, no hang.
4. Background the app mid-search, then resume — search stopped on pause, resumes safely.
5. Screen rotate mid-search — no crash, engine state intact.
6. Strongest difficulty level on a low-end device — bounded threads/hash/depth, no OOM/ANR.
7. Long game to 100+ moves — no memory growth, output controller not leaking, repetition detection works.
8. App killed/restarted mid-game — re-init after dispose works.

---

## Known gaps and next steps

- Watch Android Vitals on the next release to confirm the `is_draw` and `search<NonPV>` crash clusters and the `PlatformTaskQueue` ANR cluster drop off.
- The 6 pre-existing test failures (midgame UI ×2, classifyMoveCpl ×3, statistics ×1) are out of scope for this stabilisation; revisit separately if UI/classification/statistics work is planned.
- `stockfish_chess_engine` remains at `0.8.2` (no newer version flagged); if a native fix is released upstream, evaluate bumping the dependency.
- Consider moving heavy sync UI-isolate work (board rebuilds / PGN generation) off the main isolate if profiling shows per-move jank on low-end devices (audit found this bounded, not an unbounded block).

---

## Resume instructions

- Branch: `fix/stability-1.0.92` (tracking `origin/fix/stability-1.0.92`)
- Base branch: `master` (`2efd82b`)
- Last commit: `e1d2448` (Phase 2)
- PR: #86 (https://github.com/Karna14314/chess-master-offline/pull/86), currently DRAFT — mark ready after final QA.
- To continue: `git checkout fix/stability-1.0.92 && git pull --ff-only`, then run the verification gate (`flutter pub get`, `flutter analyze`, `flutter test`), and `gh pr ready` / `gh pr review` when ready to merge.
