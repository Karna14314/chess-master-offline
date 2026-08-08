# Analysis Screen — Performance, Accuracy & UI Audit

**Date:** August 8, 2026
**Scope:** Analysis feature — latency, move classification correctness, loading states, UI/UX
**Trigger:** User report — "analysis takes too much delay, classifications are wrong (all great), classification loads so much time, UI needs upgrade like chess.com"

---

## 1. Symptom Summary

| Symptom | User Impact | Root Cause |
|---------|-------------|------------|
| Analysis very slow | 10-30s wait before any result appears | Cache depth mismatch → every lookup re-runs engine at depth 18 |
| All moves classified as "Great"/"Best" | Analysis is useless — no actionable feedback | evalBefore/prevEval mismatch (FIXED in baseline commit) |
| Classification tab loads forever | Report tab shows infinite spinner | fullAnalysis emission logic + no empty-game guard |
| UI feels basic | Looks unlike modern chess apps (Lichess/Chess.com) | Missing eval graph, raw UCI display, no opening names, unstyled tabs |

---

## 2. Root Cause Analysis

### 2.1 Cache Depth Mismatch (Performance)

**Severity: HIGH**
**File:** `lib/providers/analysis_provider.dart`

```
analyzeFullGame() uses:  depth=15, multiPv=3
_analyzeCurrentPosition() uses: depth=18 (AppConstants.analysisDepth), multiPv=5 (AppConstants.topEngineLinesCount)

getCachedEvaluation query: WHERE depth >= :requiredDepth AND multipv >= :requiredMultiPv
```

Full-game caches at (15, 3). Live lookup needs (18, 5). Cache never hits → every navigation triggers a full depth-18 MultiPV-5 search.

**Fix:** Standardize on a single analysis depth (15) and multiPv (3) for both passes. Cache at the standard depth.

### 2.2 Classification Thresholds Too Lenient (Accuracy)

**Severity: HIGH**
**File:** `lib/models/analysis_model.dart:354-366`

Current Win% thresholds:
```dart
winDiff ≤ 1.0  → best
winDiff ≤ 4.0  → excellent
winDiff ≤ 8.0  → good       // too lenient
winDiff ≤ 15.0 → inaccuracy  // too lenient
winDiff ≤ 25.0 → mistake
winDiff > 25.0 → blunder
```

At eval 1.0 pawns (common), a 30cp loss (0.3 pawns, one pawn slightly worse) gives winDiff ≈ 2.7% → classified "Excellent". Most intermediate moves fall under 8% → "Good" or better.

**Fix:** Use tighter thresholds matching Lichess: ≤2 best, ≤5 excellent, ≤10 good, ≤20 inaccuracy, ≤40 mistake, >40 blunder.

### 2.3 Mate Handling Dead Code (Accuracy)

**Severity: HIGH**
**File:** `lib/models/analysis_model.dart:315-338`

Mate branch checks `|eval| > mateThreshold (1000)`, but evals are stored in *pawns*. Stockfish mate scores arrive via `mateIn`, not as centipawn values. When only `score mate N` is present (no `score cp`), `EngineLine.evaluation` = `(eval ?? 0) / 100.0` = **0.0**. Mate positions look equal → classified as "best".

**Fix:** Convert mate scores to large centipawn values (e.g., `10000 - mateIn * 10`) when parsing Stockfish output, so the mate branch triggers correctly.

### 2.4 Infinite Spinner on Report Tab (Loading)

**Severity: HIGH**
**File:** `lib/providers/analysis_provider.dart`, `lib/screens/analysis/analysis_screen.dart`

- `fullAnalysis` only emitted when `(i+1) % 5 == 0 || i == moves.length - 1`
- For empty moves: `analyzeFullGame` returns early → `fullAnalysis` stays null → infinite spinner
- For 1-4 move games: same issue if condition never met

**Fix:** Emit `fullAnalysis` after the loop completes regardless. Add empty-game guard with "Not enough moves" message.

### 2.5 Progress Bar Stuck Spinning (Loading)

**Severity: MEDIUM**
**File:** `lib/providers/analysis_provider.dart:614-616`

`state.isAnalyzing = true` set before `try`. Cancellation via `return` exits without resetting `state.isAnalyzing`. `finally` only resets private `_isAnalyzing`.

**FIXED in baseline commit:** Added `if (state.isAnalyzing) state = state.copyWith(isAnalyzing: false)` in `finally`.

### 2.6 Eval Graph Missing (UI)

**Severity: MEDIUM**
**File:** `lib/screens/analysis/widgets/interactive_eval_graph.dart`

Widget exists but is orphaned — never imported or instantiated. Was part of the layout during the 3-tab rewrite but got dropped.

**Fix:** Wire into Report tab (Tab 2).

### 2.7 Raw UCI Instead of SAN (UI)

**Severity: MEDIUM**
**File:** `lib/core/models/chess_models.dart`, `lib/screens/analysis/widgets/engine_recommendations.dart`

`EngineLine.sanMoves` declared but never populated. Engine lines display `e2e4` instead of `Nf3`.

**Fix:** Convert PV moves to SAN using the `chess` package's board state after applying moves.

### 2.8 Settings Toggles Not Wired (UI)

**Severity: LOW**
**File:** `lib/providers/settings_provider.dart`, `lib/screens/analysis/analysis_screen.dart`

`showWinPercent` and `autoAnalyzeAfterGame` settings exist but are never read by AnalysisScreen.

**Fix:** Wire into widget tree.

### 2.9 Opening Name Faked (UI)

**Severity: LOW**
**File:** `lib/screens/analysis/analysis_screen.dart:368`

`state.fullAnalysis!.moves.length > 5 ? "Custom Opening" : null` — placeholder, not real.

**Fix:** Implement simplified opening detection from first 6 moves or skip.

### 2.10 Practice Mode Stub (UI)

**Severity: LOW**
**File:** `lib/screens/analysis/analysis_screen.dart`

"NavigationBar Practice button leads to a screen that only displays the FEN string.

**Fix:** Either implement (spawn bot at position) or remove button.

---

## 3. Issues Not Found (Validated OK)

| Check | Status |
|-------|--------|
| Engine timeout fallback polluting cache | OK — `_getCachedOrAnalyze` only caches Stockfish results; `analyzeFullGame` catches fallback separately |
| Provider autoDispose | OK for now — `dispose()` stops engine; but state persists across screens (minor) |
| `great`/`brilliant`/`book` unreachable | Confirmed — `classifyMove()` never returns these; dead enum values |
| Two competing accuracy models | Confirmed — Win% in analysis vs CPL in game_session_viewmodel; but analysis screen self-consistent now |

---

## 4. Metrics & Benchmarks

| Metric | Current | Target |
|--------|---------|--------|
| Full-game analysis (20 moves) | ~20-30s (depth 15) | ~10-15s (with caching) |
| Per-move navigation | ~2-3s (depth 18 cache miss) | <200ms (depth 15 cache hit) |
| Classification accuracy | ~80% moves "best/good" | ~40% best/good, real distribution |
| Time-to-first-result | 10-30s | <2s (progressive emission) |
| Report tab load | Infinite for <5 moves | Instant (immediate emission) |

---

## 5. References

- `lib/providers/analysis_provider.dart` — state management & pipeline
- `lib/models/analysis_model.dart` — `classifyMove()`, accuracy computation
- `lib/core/constants/app_constants.dart` — `EvalConstants`, thresholds, `MoveClassification` enum
- `lib/core/services/stockfish_service.dart` — engine UCI integration
- `lib/screens/analysis/analysis_screen.dart` — main screen layout
- `lib/screens/analysis/widgets/` — all analysis widgets
- `test/engine_accuracy_test.dart` — classification tests
- `skills/chess-accuracy-model.md` — intended Lichess Win% model spec
