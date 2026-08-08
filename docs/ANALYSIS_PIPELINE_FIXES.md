# Analysis Pipeline — Session Fixes & Open Items

Authoritative record for the post-game analysis feature (Stockfish/UCI).
Consolidates the correctness pass, the performance pass, and everything left
open. Supersedes the fix list previously held here; the measurement detail
behind the performance work lives in `ANALYSIS_PERF_PLAN.md`.

Branch: `master` · All commits pushed · Head at time of writing: `967eac9`

---

## Fixed this session

| # | Commit | Summary |
|---|---|---|
| 1 | `a8254f9` | CPL unit conversion (pawns → centipawns) |
| 2 | `15758f2` | `score mate 0` sign resolved from FEN side-to-move |
| 3 | `5582d05` | `actualEvalBeforeMove` + eval-graph ply mapping |
| 4 | `3ee31d1` | Brilliant/Great/Miss made reachable (SEE + MultiPV) |
| 5 | `28b56b5` | Per-side accuracy header on the Report tab |
| 6 | `c1c35d3` | Audit docs + on-device verification harness |
| 7 | `ca1ca1b` | Isolate ready-signal race causing silent fallback-engine use |
| 8 | `967eac9` | Batch analysis depth 15→12, MultiPV 3→1 (named constants) |

Supporting commits from the same session (performance pass):
`191662f` carry-forward, `70edc5b` TT retention, `af3f3fb` + `73bbea0`
Threads/Hash, `d10abbb` incremental aggregates, `b6cf25e` per-ply progress,
`159ca8f` nodes-limited search option, `0757dc3` completed-iteration capture,
`80ba71d` + `d7dbd32` perf docs.

### 1. `a8254f9` — CPL pawns → centipawns
**Broken:** `bestEval`/`actualEval` are `evalInPawns`, but `classifyMoveCpl`'s
thresholds (10/20/50/100/200) are centipawns. The pawn delta was passed
straight through, so a 1.0-pawn error scored as `1` and landed in the `<= 10`
"Best" band — effectively every non-tactical move was labelled Best Move.
**Changed:** multiply the delta by 100 — `analysis_provider.dart:589-591`.
**Verified:** on-device run produced a real spread (Best/Excellent/Good/
Inaccuracy/Mistake/Blunder) where previously everything was Best Move.

### 2. `15758f2` — `score mate 0` sign
**Broken:** `_toWhiteRelative` negates for black-to-move, but negating zero is
zero, so `mate 0` (side to move is checkmated *now*) always produced −10000
regardless of who was mated.
**Changed:** added `mateToWhiteRelative()` deriving the winner from the FEN
side-to-move for N == 0 — `stockfish_service.dart:505-522`; wired into both
parse paths (`getBestMove`, `analyzePosition`).
**Verified:** `test/stockfish_mate_sign_test.dart`, 7 tests, real checkmate
FENs both directions (Fool's mate = white mated, Scholar's = black mated).

### 3. `5582d05` — `actualEvalBeforeMove` + graph mapping
**Broken:** `evalBefore` holds the engine's *best-move* eval — a counterfactual,
not the position actually reached. Using it for the graph made the curve
discontinuous and inflated "before" win% for a player who had already slipped.
The graph also treated series index as ply index, off-by-one at ply −1 and last.
**Changed:** new `MoveAnalysis.actualEvalBeforeMove` (`analysis_model.dart:57-70`),
both `evaluations` getters rebuilt from the actual series, and ply↔x mapping
`x = ply + 1` / `ply = x - 1` applied to marker, vertical line, tap handler,
axis labels and tooltip — `interactive_eval_graph.dart`.
**Verified:** `test/analysis_eval_series_test.dart`, 8 tests.

### 4. `3ee31d1` — Brilliant/Great/Miss reachable
**Broken:** `classifyMoveCpl` could only emit best/miss/blunder/excellent/good/
inaccuracy/mistake. Brilliant, Great and Book were never produced, though the
UI rendered chips for them.
**Changed:** new `StaticExchangeEvaluator` (`core/services/static_exchange_evaluator.dart`)
plus optional signals on `classifyMoveCpl` (`analysis_model.dart:397-470`):
Brilliant = CPL ≤ 20 ∧ SEE ≤ −100; Great = CPL ≤ 20 ∧ second line ≥ 30cp worse;
Miss = win% before ≥ 80 ∧ drop ≥ 25. Book stays gated off (no opening DB).
**Verified:** `test/move_classification_labels_test.dart`, 18 tests, including
an assertion that the original CPL bands classify exactly as before. On-device
Game B fired Brilliant (Evans Gambit sac), Great, and Miss on real data.

### 5. `28b56b5` — Per-side accuracy header
**Broken:** overall accuracy was computed but only surfaced in the game-over
dialog; `GameAnalysis` had no per-side field.
**Changed:** `whiteAccuracy`/`blackAccuracy` using the same Lichess model
restricted to each side's plies (`analysis_model.dart`), rendered by new
`screens/analysis/widgets/accuracy_header.dart` at the top of the Report tab.
**Verified:** `test/game_accuracy_per_side_test.dart`, 5 tests.

### 6. `c1c35d3` — Docs + verification harness
Added `lib/main_verify_analysis.dart`, the on-device entrypoint that drives the
real `analyzeFullGame` and prints the per-move table. The `integration_test`
route was abandoned — its Gradle module fails under AGP 9 on this project.

### 7. `ca1ca1b` — Isolate ready-signal race
**Broken:** the isolate sent `engine_ready` immediately after the `Stockfish()`
constructor while the engine was still `StockfishState.starting`. The main
thread then sent `uci`, the write was rejected (`Bad state: Stockfish is not
ready`), and `initialize()` waited the full 5s for a `uciok` that could never
arrive. Every retry failed identically and the service latched to the fallback
evaluator on cold start.
**Changed:** announce readiness only when state actually reaches `ready`, and
surface error/disposed instead of timing out — `stockfish_service.dart:1447-1478`.
**Why it matters beyond tests:** this silently affected real users on cold
start, and it invalidated a full config sweep that ran on the fallback
evaluator while producing plausible-looking numbers. Caught only by checking
the init log.
**Verified:** cold-start init now succeeds first attempt, zero fallback retries.

### 8. `967eac9` — Batch depth 15→12, MultiPV 3→1
**Changed:** hardcoded `depth: 15, multiPv: 3` at both batch call sites replaced
with `AppConstants.batchAnalysisDepth` / `batchAnalysisMultiPv`
(`app_constants.dart:128-153`, `analysis_provider.dart:534-535,603-604`).
**Measured** on-device, 24-ply game, real engine:

| Config | Full game | Per position |
|---|---|---|
| d15/MPV3/T1 (was) | 131.8s | 5273ms |
| d15/MPV1/T1 | 48.1s | 1924ms |
| **d12/MPV1/T1 (shipped)** | **17.3s** sweep · **20.4s** real pipeline | 850ms |
| d10/MPV1/T4 | 6.6s | 266ms |

End-to-end through the real pipeline: **131.8s → 20.4s, 6.5x faster**, with
`searchesPerPly=1.04` and unchanged classification counts.

---

## Known issues — NOT fixed, tracked for next session

### 1. Non-determinism in Stockfish evaluation  ← **next priority**
The same position can yield different evals, and therefore different labels,
across runs. `analyzePosition` resolves on whichever `info` line arrived before
`bestmove` rather than at a fixed work budget, so the captured result depends
on timing; `_stopCurrentSearchAndWait` can also cut a search short on its 2s
timeout.

**Measured:** two cold-cache runs of the *unmodified pre-session baseline*
produced White 88.5%/Black 92.1%/CPL 55.1 versus White 94.4%/Black 98.2%/CPL
31.0. A `go nodes 150000` probe mismatched on **22 of 25 positions** on
immediate re-run, including a sign flip (+0.27 → −0.27).

**Why not fixed:** it is a correctness problem and each pass this session was
explicitly scoped (correctness pass, then performance pass). A partial fix
landed in `0757dc3` — `bestmove` now publishes the deepest *completed* MultiPV
iteration rather than whatever was mid-flight — but it is **not validated**;
the determinism re-run never completed cleanly.

**To fix:** switch the batch pass to `go nodes N` (the `nodes:` parameter
already exists on `analyzePosition`, added in `159ca8f`, off by default), then
prove it with a repeat-run comparison. Note the earlier probe showed node
limiting alone was *not* sufficient — the capture path had to be fixed too, so
both changes need validating together.

**Everything below depends on this being fixed first.**

### 2. d10 vs d12 depth tradeoff — unresolved
d10/MPV1/T4 = 6.6s versus shipped d12/MPV1/T1 = 20.4s. d10 meets the <10s
target, but there is currently no trustworthy way to quantify what accuracy it
costs, because the reference it would be compared against is itself unstable
(#1). "d10 is fine" and "d10 is worse but noise hides it" are indistinguishable
in the present data.

**To resolve:** re-run the agreement sweep **through the real pipeline**, not
`lib/main_sweep.dart` — the standalone harness passes `bestMove: null`, dropping
the best-move-match shortcut, and compares raw CPL bands, which amplifies small
eval jitter into band flips. Its 13-17% agreement figures are not meaningful.

### 3. Tiered / two-pass analysis — not implemented
Proposed: a fast nodes-limited pass over all plies, escalating to a deeper
search only where the cheap-pass eval swing sits near a CPL threshold.

**Measured (unreliable, see #1):** at `nodes=150000` the cheap pass differed
from d15 by 92cp mean / 317cp worst, and a CPL<5 or CPL>400 confidence gate
left **79% of plies** in the gray zone — with 2 of its 5 confident calls wrong.
That measurement predates the capture fix and was taken against a
non-deterministic reference, so it should be re-taken rather than trusted.

**Needs:** #1 fixed to define "near boundary" reliably, then a run logging
cheap-pass and escalated-pass evals side by side to calibrate the trigger width.

### 4. Great-move detection is dormant
Great requires MultiPV ≥ 2 to compare against the second-best line
(`secondBestCentipawnLoss`). The shipped config uses MultiPV 1, so the input is
always null and Great never fires. The chip is conditional (`greatMoves > 0`)
so it hides rather than showing a permanent zero — **working as intended, not a
regression**. Documented at the threshold constant in `analysis_model.dart`.

Restoring globally costs ~2.2x (17.3s → 38.7s at d12, measured). Better option
for later: run MPV 2-3 only on plies flagged by the tiered approach (#3) — the
same selective-deeper-search mechanism.

### 5. Two cosmetic/UX inconsistencies (low priority)
- **CPL can contradict its label.** e.g. `CPL 435` displayed next to "Best
  Move": the best-move string match short-circuits before the CPL bands are
  reached, and the two evals came from independent searches that disagreed in a
  sharp position. The label is right; the adjacent number is confusing.
- **CPL and accuracy use different baselines by design.** CPL compares against
  best play, accuracy against the position actually reached, so a move can show
  "Blunder" alongside "ACC 100.0%". Correct behaviour, confusing presentation.
  Prefer a tooltip/footnote over a logic change.

### 6. `forced` / `onlyMove` still unreachable
Same category Brilliant/Great were in before this session: the enum members
exist and the UI has arms for them, but nothing emits them. They are folded
into the `bestMoves` counter and render identically to Best, so nothing is
visibly broken. Deferred by explicit instruction.

### 7. `classifyMove()` and `EvalConstants.classifyCpl()` are dead code
The live pipeline uses `classifyMoveCpl()` exclusively. Both were left
untouched throughout this session per instruction. Note `classifyCpl` uses a
≤5 "best" band while the live path uses ≤10 — a real inconsistency waiting to
mislead someone. Candidate for removal or consolidation.

### 8. Threads=4 showed no speedup — unexplained
d12/T1 = 17.3s versus d12/T4 = 17.9s; four threads were marginally *slower*.
This contradicts typical Stockfish Lazy SMP scaling and is flagged as
suspicious rather than accepted. Both tested points were shallow, where a
search may complete before helper threads contribute; thread-pool overhead
eating the gain is equally consistent with the data.

**Clean test, not yet run:** T1 vs T4 at d15, where searches run ~5s and there
is room for parallelism to show. Only worth revisiting if depth increases again.

Related: `73bbea0` pins batch analysis to Threads=1 because Lazy SMP is
non-deterministic — a measured T3 run changed labels (blunders 0 → 2). Since
T4 buys no speed, that constraint currently costs nothing.

---

## Suggested next-session order

1. **Fix determinism** (`go nodes N` + validate the `0757dc3` capture fix
   together) — unblocks everything else.
2. **Re-run the real-pipeline agreement sweep**: d10 vs d12 vs d15 against a
   stable reference.
3. **Decide** — stay at d12, drop to d10, or build tiered escalation — with
   trustworthy numbers.
4. **Revisit Great-move and tiered MultiPV escalation together**; they are the
   same underlying mechanism (selective deeper search on a subset of plies).

---

## Test baseline

```
382 passing
3 failing  — pre-existing, environment-only:
  engine_no_legal_move_test.dart          (1)
  engine_threefold_repetition_test.dart   (2)
```

All three fail identically on the pre-session commit (`databaseFactory not
initialized` — sqflite has no desktop binding in the test environment) and are
unrelated to this work.

Tests added this session: `stockfish_mate_sign_test.dart` (7),
`analysis_eval_series_test.dart` (8), `move_classification_labels_test.dart`
(18), `game_accuracy_per_side_test.dart` (5),
`game_analysis_accumulator_test.dart` (6).

## Temporary harnesses (not part of the app)

`lib/main_verify_analysis.dart` · `lib/main_verify_nodes.dart` ·
`lib/main_sweep.dart` — on-device measurement entrypoints, run via
`flutter run -t <file>` or by temporarily swapping into `lib/main.dart`. Safe
to delete; retained so the measurements above can be reproduced.
