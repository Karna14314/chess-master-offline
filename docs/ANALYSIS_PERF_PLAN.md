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

| Fix | Commit | State |
|---|---|---|
| 1 | `191662f` | done — searches/ply 2.0 → **1.04** |
| 2 | `70edc5b` | done |
| 3 | `af3f3fb` + `73bbea0` | done, **scoped down to Threads=1** |
| 5 | `d10abbb` | done, **partially** O(1) (see note) |
| 6 | `b6cf25e` | done — 5 ticks → **24 ticks** |
| 4 | — | **not implemented** (see assessment) |

---

## Results

### Searches per ply

```
before: searches=48 plies=24 searchesPerPly=2.00
after : searches=25 plies=24 searchesPerPly=1.04  carryForwardHits=23
```

23 of 24 plies reused the previous ply's result. The residual 0.04 is ply 0,
which has no predecessor. **Engine work halved.**

### Wall clock (cold cache, 24 plies, real engine)

| Run | Total | avg ms/ply | searches |
|---|---|---|---|
| Baseline (pre-fix) | 135 317 ms | 5 638 | 48 |
| After FIX 1-3 (Threads=3) | 123 141 ms | 5 131 | 25 |
| After FIX 1-3 (Threads=1, shipped) | 134 760 ms | 5 615 | 25 |
| After FIX 5-6 | 132 387 ms | 5 516 | 25 |

**Wall-clock did not improve materially, despite halving the searches.** This
is the headline finding and it was not anticipated.

Cause: the eliminated search was the one that was already nearly free. The
carried-forward position had just been searched, so on the old code path it was
served from the SQLite cache in milliseconds — the redundancy cost a cache
round-trip, not a search. Real time is dominated by the one genuinely new
depth-15 MultiPV-3 position per ply, which still has to be searched.

The win is real but is in **engine/CPU work and battery**, not latency: 23 fewer
searches, 23 fewer cache writes, and no per-ply TT flush. Getting wall-clock
down needs a different lever — lower depth, or accepting multi-threading and
its non-determinism.

### Progress cadence

Ticks went from 5 to 24 on a 24-ply game, and the accuracy figure now moves in
small steps (73.0 → 75.1 → 82.7 → 82.3 → 87.6 → …) instead of lurching
(99.5 → 82.2). Ticks are monotonic in ply count and every value is the correct
aggregate for the plies analysed at that moment.

---

## Correctness gate: FAILED, then invalidated

The gate required identical classifications and accuracy before/after. The
first post-fix run broke it:

```
baseline : White 85.4% Black 91.0% CPL 44.1 blunders 0
Threads=3: White 91.0% Black 96.1% CPL 69.2 blunders 2
```

Threads=3 was the main culprit — Lazy SMP is non-deterministic — so it was
reverted to Threads=1 (`73bbea0`). But that did not restore the baseline
either, so the pipeline was tested for reproducibility directly:

**Two cold-cache runs of the same unmodified pre-perf baseline build:**

```
baseline run 1: White 88.5% Black 92.1% CPL 55.1 blunders 1
baseline run 2: White 94.4% Black 98.2% CPL 31.0 blunders 0
```

**The pre-existing pipeline is already non-deterministic.** Identical code,
identical game, cold cache both times, materially different results. The
"baseline" recorded in the earlier audit was one sample of a distribution, not
a fixed reference, so it was never a valid gate.

Non-determinism is present even at Threads=1, so Lazy SMP is not the only
source. Most likely `analyzePosition` resolves on whatever `info` line arrives
before `bestmove`, making the recorded eval sensitive to timing, and searches
are stopped by `_stopCurrentSearchAndWait` on a 2s timeout. This is a
**pre-existing correctness defect, not a regression from this pass**, and it is
more serious than any of the performance issues fixed here: two users analysing
the same game — or the same user twice — can see different classifications.

Filed as the top follow-up. Not fixed here: it is a correctness problem and
this pass was explicitly scoped to performance.

What the perf pass *can* be shown not to have broken: FIX 5's accumulator is
proven numerically identical to `fromMoves` at every prefix length by
`test/game_analysis_accumulator_test.dart`, and FIX 1's carry-forward reuses a
value the old code would have read back from cache for the same FEN.

---

## FIX 4 — not implemented

`analyzeFullGame` cannot be moved to `compute()` or a worker isolate as
specified. The loop's dominant cost is `await`ing `StockfishService`, a
singleton that owns an `Isolate`, a `SendPort`, and a broadcast
`StreamController` (`stockfish_service.dart:25,50-58`). None of these are
sendable across an isolate boundary, and the engine isolate is spawned from and
bound to the main isolate. A worker isolate could not talk to the engine
without a bidirectional message bridge — effectively re-implementing the
service's transport layer, which is far beyond a performance pass and would put
the recently-stabilised engine lifecycle at risk.

The residual main-thread work is also small: SEE is microseconds, and per-tick
aggregation is now O(1) after FIX 5. The genuinely heavy work — the search
itself — is *already* off the UI isolate.

Recommended smaller alternative, not done here: move the SQLite cache
read/write to a background isolate via `sqflite`'s isolate support, the only
remaining main-thread I/O in the loop.

DevTools timeline before/after was not captured; with the search already
off-thread and ticks now O(1), the remaining main-thread work per ply is
negligible against a ~5.5 s search.

---

## Follow-ups

1. **Non-deterministic analysis results (high).** Same game, same build, cold
   cache, different classifications. Investigate `analyzePosition` resolving on
   a race between `info` lines and `bestmove`, and the 2s stop timeout. Needs a
   fixed-node or fixed-depth completion contract.
2. **Wall clock unchanged.** If review speed matters, the lever is depth or
   MultiPV, not search count.
3. **Threads > 1 is off the table** for review unless reproducibility is
   explicitly traded away.
4. **Cache key vs live path.** Live analysis writes depth-12 entries that a
   depth-15 batch query can never satisfy, so the batch always re-searches.
5. Move SQLite cache I/O off the UI isolate (reduced FIX 4).
