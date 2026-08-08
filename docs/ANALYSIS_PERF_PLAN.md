# Analysis Pipeline — Performance & Progress-Display Plan

Scope: **performance and progress display only.** Classification logic was fixed
and verified in a prior pass (`docs/ANALYSIS_PIPELINE_FIXES.md`) and must come
out of this pass byte-identical in behaviour.

Correctness gate for every fix: the 24-ply Game A verification must produce the
**same per-move classifications and the same final accuracy numbers** as the
pre-perf baseline. Speed may change; numbers may not.

---

## Baseline (measured on-device, Redmi 22041219PI, real engine, cold cache)

```
ENGINE ready=true fallback=false initMs=2027
TICK t= 28029ms progress= 21% plies= 5/24 perPlyMs=5606 ACC=85.8
TICK t= 55829ms progress= 42% plies=10/24 perPlyMs=5560 ACC=91.1
TICK t= 85609ms progress= 63% plies=15/24 perPlyMs=5956 ACC=90.4
TICK t=115396ms progress= 83% plies=20/24 perPlyMs=5957 ACC=91.3
TICK t=135314ms progress=100% plies=24/24 perPlyMs=4980 ACC=94.3
TOTAL_ELAPSED_MS=135317 plies=24 avgPerPlyMs=5638 totalSearches=48
```

Warm cache for comparison: 910 ms total, 38 ms/ply (149× faster) — the pipeline
is almost entirely cache-dependent today.

Final numbers that must not change:
`White 85.4% · Black 91.0% · avgCPL 44.1`
`COUNTS best:9 excellent:4 good:4 inaccuracy:3 mistake:4 blunder:0`
`DISTINCT_CLASSES Best Move,Good,Excellent,Inaccuracy,Mistake`

---

## Root causes (from the audit)

| # | Cause | Evidence |
|---|---|---|
| 1 | 2 searches/ply, ~50% redundant | `analysis_provider.dart:497` re-searches the FEN already searched at `:563` on the previous iteration |
| 2 | TT flushed between plies | `stockfish_service.dart:956-957` `ucinewgame` fires whenever `wasStopped` |
| 3 | No analysis-specific engine tuning | `stockfish_service.dart:249-251` Threads=1 / Hash=32MB used for depth-15 MultiPV-3 batch work |
| 4 | Batch loop on UI isolate | loop, SQLite, SEE, `fromMoves` all main-thread |
| 5 | `fromMoves` is O(n) per tick → O(n²) | `analysis_model.dart` full walk on every emission |
| 6 | Progress emits every 5 plies | `analysis_provider.dart:665` causes 99.5 → 82.2 jumps |

---

## Sequential plan

Implemented in this order so each commit is independently revertable and the
correctness gate can be run between stages.

### FIX 1 — carry the "after" result forward (highest priority)
Hold the just-computed "after" `(eval, lines, isMate)` in a loop variable and
reuse it as the next ply's "before", skipping both cache lookup and engine call.
Fresh search only on ply 0. Existing cache path retained as the fallback for
branches / re-runs / jump-to-ply. Instrument searches-per-ply.

### FIX 2 — suppress `ucinewgame` during batch runs
Thread an `isBatchAnalysis` flag through `analyzePosition` →
`_stopCurrentSearchAndWait`. Keep `ucinewgame` for new sessions, live play and
non-sequential jumps. Watch for stale evals in verification.

### FIX 3 — `setAnalysisStrength()` / `setLivePlayStrength()`
Raise Threads/Hash for batch analysis, restore afterwards including on the
cancellation path. Conservative, capped off `Platform.numberOfProcessors`.

**→ Verification run A** (cold cache, 24 plies): timing + correctness gate.

### FIX 5 — incremental aggregates
Running sums/counts so each tick is O(1) amortized. Public
`GameAnalysis.fromMoves(List)` stays working for full recomputation.
Done before FIX 6 because per-ply emission is only affordable once ticks are cheap.

### FIX 6 — per-ply progress + "Accuracy so far" label
Emit every ply (every 2 for >40 plies). Label distinguishes in-progress from
final in `game_accuracy_summary.dart`.

### FIX 4 — move the loop off the UI isolate (assessed last)
Feasibility risk: `StockfishService` is a singleton owning an
`Isolate`/`ReceivePort`/`Stream`, none of which are sendable across isolates,
and the engine's own isolate is already spawned from the main isolate.
`compute()` cannot host a loop that awaits that engine. Assess and, if the
migration is not safely possible, scope down to offloading the genuinely
pure work and document the limitation rather than force an unsafe refactor.

**→ Verification run B**: tick cadence + per-tick correctness.

---

## Status

| Fix | State |
|---|---|
| 1 | pending |
| 2 | pending |
| 3 | pending |
| 4 | pending (feasibility assessment) |
| 5 | pending |
| 6 | pending |
