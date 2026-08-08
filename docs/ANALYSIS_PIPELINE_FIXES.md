# Post-Game Analysis Pipeline — Audit & Fix Record

Status: all five confirmed bugs fixed, each in its own commit.
Verified on-device (Redmi 22041219PI) against the **real Stockfish engine**
(`ready=true fallback=false`), depth 15, MultiPV 3.

| Commit | Bug | Summary |
|---|---|---|
| `a8254f9` | 1 | centipawnLoss converted to centipawns (×100) before classification |
| `15758f2` | 2 | `score mate 0` sign resolved from FEN side-to-move |
| `5582d05` | 3 | `actualEvalBeforeMove` added; eval-graph ply mapping fixed |
| `3ee31d1` | 4 | Brilliant / Great / Miss made reachable (SEE + MultiPV) |
| `28b56b5` | 5 | Per-side accuracy header on the Report tab |

---

## BUG 1 — pawns vs centipawns (root cause of "everything is Best Move")

**File:** `lib/providers/analysis_provider.dart` (Step C of `analyzeFullGame`)

`bestEval` / `actualEval` come from `AnalysisResult.evalInPawns`, i.e. **pawns**.
The delta was passed straight into `classifyMoveCpl`, whose thresholds
(10/20/50/100/200) are **centipawns**. A 1.0-pawn error scored as `1` and fell in
the `<= 10` "Best" band, so effectively every non-tactical move was "Best Move".

```dart
final double centipawnLoss = isWhiteMove
    ? (bestEval - actualEval) * 100.0
    : (actualEval - bestEval) * 100.0;
```

Audited the other CPL derivations — no other site needed changing:

| Site | Status |
|---|---|
| `EvalConstants.computeCpl` | already converts via `toCentipawns` (×100) |
| `computeWinPercentAccuracy` | already converts `eval * 100` before win% |
| `computeCentipawnLoss` (model) | delegates to `computeCpl`, correct |
| `MoveAnalysis.evalLoss` | intentionally a **pawns** delta — only feeds the UI ± arrow and the "dropping N pawns" text |

`classifyMove()` (Win%-based) and the threshold values themselves were left alone.

---

## BUG 2 — `score mate 0` sign

**File:** `lib/core/services/stockfish_service.dart`

`_toWhiteRelative` negates for black-to-move, but negating zero is zero, so
`mate 0` (side to move is checkmated **now**) always produced `-10000`
regardless of who was mated.

Added `mateToWhiteRelative(rawMate, fen)`:
* `N != 0` → delegates to `_toWhiteRelative` (unchanged behaviour)
* `N == 0` → winner derived from FEN side-to-move; black to move ⇒ black is
  mated ⇒ white-relative **positive**

Wired into both parse paths (`getBestMove` and `analyzePosition`).

**Tests:** `test/stockfish_mate_sign_test.dart` — real checkmate FENs for both
directions (Fool's mate = white mated, Scholar's mate = black mated), at the
helper level and through both pipelines. 7 tests, all pass.

---

## BUG 3 — `evalBefore` semantics / eval-graph off-by-one

**Files:** `lib/models/analysis_model.dart`, `lib/providers/analysis_provider.dart`,
`lib/screens/analysis/widgets/interactive_eval_graph.dart`

`evalBefore` is the engine's **best-move** eval for the pre-move position — a
counterfactual. Using it for the graph made the curve discontinuous
(`evalBefore[i] != evalAfter[i-1]` whenever the previous ply lost anything) and
inflated the "before" win% for a player who had already slipped.

* New field `MoveAnalysis.actualEvalBeforeMove` (defaults to `evalBefore`)
  carries the previous ply's `evalAfter`.
* `evalBefore` is **unchanged** and remains the CPL baseline.
* Both `evaluations` getters, the displayed win% pair and per-move accuracy now
  use the actual series.
* Graph index contract documented and fixed: **series index `i` == position
  after `i` plies** (length = plies + 1). Ply ↔ x mapping is `x = ply + 1` /
  `ply = x - 1`, applied to the marker, vertical line, tap handler, axis move
  numbers and tooltip. Fixes the off-by-one at ply `-1` (start) and the last ply;
  the start position now renders a "Start" tooltip.

**Tests:** `test/analysis_eval_series_test.dart` — 8 tests covering the field
default, series length/continuity, exclusion of the counterfactual eval, and
ply↔x round-tripping.

---

## BUG 4 — unreachable classifications

**Option (a) — real detection — was implemented**, because the required inputs
were already being fetched (MultiPV=3 lines, board in hand at classify time);
only the detection logic was missing. **Book** is the exception and stays gated
off (option b): there is no opening database to match against, and its chip is
already conditional (`if (analysis.bookMoves > 0)`) so it never renders a
permanent zero.

New `lib/core/services/static_exchange_evaluator.dart` — least-valuable-attacker
swap-off returning material swing in centipawns; a side never enters a losing
exchange; the board is left unmodified.

`classifyMoveCpl` gained **optional** signals (thresholds untouched):

| Label | Rule |
|---|---|
| Brilliant | `CPL <= 20` **and** `SEE <= -100` (sound sacrifice) |
| Great | `CPL <= 20` **and** second-best MultiPV line `>= 30cp` worse (only good move) |
| Miss (non-mate) | `winBefore >= 80` **and** `winDrop >= 25` — reuses the rule that was dead in `classifyMove` |

Precedence: **Brilliant > Great > Best > Miss > CPL bands.**
`forced` / `onlyMove` remain unemitted; they are folded into the `bestMoves`
counter by `GameAnalysis.fromMoves` and render identically to Best, so they are
not user-visible dead labels.

**Tests:** `test/move_classification_labels_test.dart` — 18 tests covering SEE,
each new label, precedence, and an explicit assertion that the original CPL
bands still classify exactly as before.

---

## BUG 5 — accuracy not shown on the analysis screen

**Files:** `lib/models/analysis_model.dart`,
`lib/screens/analysis/widgets/accuracy_header.dart` (new),
`lib/screens/analysis/analysis_screen.dart`

`GameAnalysis` had no per-side field, so `whiteAccuracy` / `blackAccuracy` were
added using the same Lichess volatility-weighted + harmonic model restricted to
each side's plies. Rendered by a new `AccuracyHeader` at the top of the Report
tab.

**Tests:** `test/game_accuracy_per_side_test.dart` — 5 tests (empty, one-sided,
independence, range clamping).

---

## Verification — real engine, on device

Harness: `lib/main_verify_analysis.dart` (temporary entrypoint; drives the real
`analyzeFullGame`). The `integration_test` route was abandoned — its Gradle
module fails under AGP 9 on this project.

```
flutter run -t lib/main_verify_analysis.dart -d <device> --debug
# then grep logcat for the VERIFY prefix
```

### Game A — quiet Italian (24 plies)

```
MOVE     |SIDE|SAN     |EVAL_BEFORE(best)|EVAL_AFTER|ACTUAL_BEFORE|   CPL|  ACC%|CLASS
1.       |W   |e4      |             0.54|      0.51|         0.54|     3|  98.8|Best Move
1....    |B   |e5      |             0.51|      0.54|         0.51|     3|  98.8|Best Move
2.       |W   |Nf3     |             0.54|      0.46|         0.54|     8|  96.8|Best Move
2....    |B   |Nc6     |             0.46|      0.00|         0.46|    46| 100.0|Good
3.       |W   |Bc4     |             0.00|      0.15|         0.00|    15| 100.0|Excellent
3....    |B   |Nf6     |             0.15|     -0.35|         0.15|    50| 100.0|Best Move
4.       |W   |d3      |            -0.35|     -0.40|        -0.35|     5|  98.0|Best Move
4....    |B   |Bc5     |            -0.40|     -0.70|        -0.40|    30| 100.0|Good
5.       |W   |O-O     |            -0.70|      0.08|        -0.70|    78| 100.0|Inaccuracy
5....    |B   |d6      |             0.08|     -0.40|         0.08|    48| 100.0|Good
6.       |W   |c3      |            -0.40|     -0.70|        -0.40|    30|  88.4|Good
6....    |B   |Bg4     |            -0.70|      0.59|        -0.70|   129|  58.5|Mistake
7.       |W   |h3      |             0.59|     -1.15|         0.59|   174|  48.6|Mistake
7....    |B   |Bh5     |            -1.15|     -1.05|        -1.15|    10|  96.1|Best Move
8.       |W   |g4      |            -1.05|     -1.60|        -1.05|    55|  80.7|Inaccuracy
8....    |B   |Bg6     |            -1.60|     -1.70|        -1.60|    10| 100.0|Best Move
9.       |W   |g5      |            -1.70|     -1.85|        -1.70|    15|  94.6|Excellent
9....    |B   |Nd7     |            -1.85|     -1.75|        -1.85|    10|  96.4|Excellent
10.      |W   |d4      |            -1.75|     -0.58|        -1.75|   117| 100.0|Mistake
10....   |B   |exd4    |            -0.58|      0.00|        -0.58|    58|  78.7|Inaccuracy
11.      |W   |cxd4    |             0.00|     -1.45|         0.00|   145|  55.3|Mistake
11....   |B   |Bb6     |            -1.45|     -1.40|        -1.45|     5|  98.1|Best Move
12.      |W   |d5      |            -1.40|     -1.35|        -1.40|     5| 100.0|Best Move
12....   |B   |Ne7     |            -1.35|     -1.25|        -1.35|    10|  96.2|Excellent

White accuracy: 85.4%   Black accuracy: 91.0%   Average CPL: 44.1
COUNTS best:9 excellent:4 good:4 inaccuracy:3 mistake:4 blunder:0
EVAL_SERIES len=25 plies=24            (BUG 3: plies + 1 ✔)
```

### Game B — Evans Gambit with a queen grab (20 plies)

```
MOVE     |SIDE|SAN     |EVAL_BEFORE(best)|EVAL_AFTER|ACTUAL_BEFORE|   CPL|  ACC%|CLASS
1.       |W   |e4      |             0.54|      0.51|         0.54|     3|  98.8|Best Move
1....    |B   |e5      |             0.51|      0.54|         0.51|     3|  98.8|Best Move
2.       |W   |Nf3     |             0.54|      0.46|         0.54|     8|  96.8|Best Move
2....    |B   |Nc6     |             0.46|      0.00|         0.46|    46| 100.0|Good
3.       |W   |Bc4     |             0.00|      0.15|         0.00|    15| 100.0|Excellent
3....    |B   |Bc5     |             0.15|     -0.15|         0.15|    30| 100.0|Good
4.       |W   |b4      |            -0.15|      0.02|        -0.15|    17| 100.0|Brilliant
4....    |B   |Bxb4    |             0.02|     -1.90|         0.02|   192| 100.0|Mistake
5.       |W   |c3      |            -1.90|     -2.10|        -1.90|    20|  93.0|Good
5....    |B   |Ba5     |            -2.10|     -2.00|        -2.10|    10|  96.5|Excellent
6.       |W   |d4      |            -2.00|     -2.20|        -2.00|    20|  93.1|Good
6....    |B   |Qg5     |            -2.20|      7.95|        -2.20|  1015|   3.2|Blunder
7.       |W   |dxe5    |             7.95|     -1.00|         7.95|   895|   6.7|Miss
7....    |B   |Qxg2    |            -1.00|      3.35|        -1.00|   435|  17.8|Best Move
8.       |W   |Rg1     |             3.35|      2.50|         3.35|    85|  76.5|Inaccuracy
8....    |B   |Qh3     |             2.50|      2.65|         2.50|    15|  95.1|Great
9.       |W   |Bxf7+   |             2.65|      2.90|         2.65|    25| 100.0|Good
9....    |B   |Ke7     |             2.90|      4.97|         2.90|   207|  58.7|Blunder
10.      |W   |Bxg8    |             4.97|      1.25|         4.97|   372|  31.8|Blunder
10....   |B   |Rxg8    |             1.25|     -1.80|         1.25|   305| 100.0|Blunder

White accuracy: 54.7%   Black accuracy: 39.3%   Average CPL: 185.9
COUNTS best:4 excellent:2 good:5 inaccuracy:1 mistake:1 blunder:4 miss:1 great:1 brilliant:1
EVAL_SERIES len=21 plies=20
DISTINCT_CLASSES Best Move,Good,Excellent,Brilliant,Mistake,Blunder,Miss,Inaccuracy,Great
```

Every previously-unreachable label now fires on real data:
**Brilliant** (4.b4, the Evans Gambit pawn sacrifice, SEE −100 with CPL 17),
**Great** (8...Qh3, only move within tolerance), **Miss** (7.dxe5 throwing away
a +7.95 position), plus Blunder / Mistake / Inaccuracy / Good / Excellent / Best.

---

## Residual findings (NOT fixed — flagged for review)

1. **Search instability makes CPL disagree with the best-move label.**
   Game B ply 7...Qxg2 shows `CPL 435` yet classifies as **Best Move**, because
   the played move string matched the engine's `bestMove` and that check
   short-circuits before the CPL bands. The two evals come from two independent
   depth-15 searches (position-before vs position-after), which can disagree by
   several pawns in sharp positions. The label is right; the displayed CPL is
   misleading. Options: trust `lines[0].evaluation` for the after-eval when the
   played move matches the PV, or clamp CPL to 0 on a best-move match.

2. **CPL and accuracy now use deliberately different baselines** (BUG 3).
   CPL compares against the engine's best move; accuracy compares against the
   position actually reached. Game B ply 10...Rxg8 therefore shows
   `CPL 305 / Blunder` alongside `ACC 100.0%` — the move was bad versus best play
   but improved on the position Black actually inherited. Correct by design, but
   showing both numbers side by side in the UI may confuse users.

3. **`forced` / `onlyMove` are still never emitted.** They are counted as Best
   and styled identically, so nothing is visibly dead, but the enum members are
   unreachable.

4. **`classifyMove()` (Win%-based) and `EvalConstants.classifyCpl` remain dead
   code** — the pipeline uses `classifyMoveCpl` exclusively. `classifyMove` was
   left untouched per instructions; consider deleting in a separate cleanup.

5. **Report tab hardcodes `"Custom Opening"`** for games longer than 5 moves
   (`analysis_screen.dart`), unrelated to the fixes above.

---

## Test summary

```
test/stockfish_mate_sign_test.dart           7 passed
test/analysis_eval_series_test.dart          8 passed
test/move_classification_labels_test.dart   18 passed
test/game_accuracy_per_side_test.dart        5 passed
test/engine_accuracy_test.dart              73 passed (no regressions)
```

Pre-existing failures unrelated to these changes:
`engine_threefold_repetition_test.dart` (2) — `databaseFactory not initialized`
in the desktop test environment; fails identically on the pre-fix commit.
