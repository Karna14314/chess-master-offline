# Implementation Plan — Analysis Fixes & Crash Stability

**Date:** August 8, 2026
**Scope:** Fix analysis performance, classification accuracy, loading states, UI upgrades, AND native crash stability

---

## Phase 0: Crash Stability (CRITICAL — Do First)

### Problem
Play Console shows SIGSEGV crashes in `libstockfish_chess_engine.so`:
- `Stockfish::Position::is_draw` — most frequent
- `Stockfish::Search::Worker::search/qsearch`
- `Stockfish::Eval::NNUE::FeatureTransformer`
- `Stockfish::TranspositionTable::probe`

All are native segmentation faults — the engine accessed invalid memory.

### Root Cause Hypothesis
1. **Invalid FEN** — FEN string with wrong piece placement, missing fields, or impossible position passed to native code
2. **Engine state corruption** — Using engine after stop/dispose, or concurrent access
3. **Position object lifetime** — Position modified or freed while search is running
4. **Stale search running** — Old search still processing when new `go` command sent

### Fixes

#### Fix 0.1: Strengthen FEN Validation
- Current `_isValidFen()` exists but may miss edge cases
- Add: piece count validation (max 9Q/9B/9R/9N per side), king count (exactly 1 each), no pawns on rank 1/8, side-to-move not giving impossible check
- Add FEN sanitization before every `position` command

#### Fix 0.2: Engine Lifecycle Guards
- Add `_isDisposed` flag — block all engine calls after dispose
- Add `_engineReady` flag — block calls before `readyok`
- Ensure `stopAnalysis()` waits for `bestmove` before allowing new search

#### Fix 0.3: Thread Safety
- Ensure all engine calls go through a single serialized queue
- No concurrent `analyzePosition` / `getBestMove` calls
- Proper cleanup: stop isolate → clear ports → null reference

#### Fix 0.4: Native Crash Recovery
- Wrap all engine calls in try/catch (already done)
- Add isolate death detection → restart isolate on crash
- If isolate dies >3 times in 60s, fall back to BasicEvaluator permanently

---

## Phase 1: Cache Performance

### Fix 1.1: Standardize Analysis Depth
- Change `_analyzeCurrentPosition()` from depth 18 → depth 15
- Change `multiPv` from 5 → 3 (consistent with full-game pass)
- Result: cache hits on every navigation after full-game analysis

### Fix 1.2: Don't Cache Fallback Results
- Current `_getCachedOrAnalyze` only caches Stockfish results (OK)
- Verify: ensure BasicEvaluator fallback is never tagged as "depth 15"
- Add `actualDepth` field to cache to distinguish real depth from requested

### Fix 1.3: Warm Up Cache During Full-Game
- Already caches each position during full-game analysis (good)
- After full-game completes, all subsequent navigations are instant

---

## Phase 2: Classification Accuracy

### Fix 2.1: Tighten Win% Thresholds
```dart
// Current (too lenient):
≤1.0 → best, ≤4.0 → excellent, ≤8.0 → good, ≤15.0 → inaccuracy, ≤25.0 → mistake

// New (Lichess-aligned):
≤2.0 → best, ≤5.0 → excellent, ≤10.0 → good, ≤20.0 → inaccuracy, ≤40.0 → mistake, >40 → blunder
```

### Fix 2.2: Fix Mate Score Handling
- Convert `mateIn` to centipawns: `eval = (mateIn > 0 ? 10000 : -10000) - mateIn * 10`
- Makes `|eval| > 1000` mateThreshold reachable
- Mate branch in classifyMove() becomes functional

### Fix 2.3: Update Tests
- Adjust expected classifications in `test/engine_accuracy_test.dart`
- Add mate-specific test cases

---

## Phase 3: Loading States & Spinners

### Fix 3.1: Fix Progress Bar Stuck (DONE in baseline commit)

### Fix 3.2: Empty Game Guard
- When `moves.isEmpty` or `moves.length < 4`, show "Not enough moves to analyze"
- Don't start `analyzeFullGame()`, don't show spinner

### Fix 3.3: Immediate fullAnalysis Emission
- Emit `fullAnalysis` after the loop completes regardless of move count
- Remove the `% 5` condition for final emission (already does `|| i == moves.length - 1`)
- Ensure it fires even for 1-move games

---

## Phase 4: UI Upgrades

### Fix 4.1: Wire InteractiveEvalGraph
- Import in `analysis_screen.dart`
- Add to Report tab (Tab 2) layout

### Fix 4.2: UCI → SAN Conversion
- Populate `EngineLine.sanMoves` by applying PV to a temp board
- Display SAN in `EngineRecommendations`

### Fix 4.3: Wire Settings Toggles
- Read `showWinPercent` → pass to `UnifiedEvalBar`
- Read `autoAnalyzeAfterGame` → auto-trigger analysis on game over

### Fix 4.4: Opening Name (Simplified)
- Use first 4 half-moves to detect common openings (Italian, Sicilian, etc.)
- Fallback to "Unknown Opening"
- Remove "Custom Opening" placeholder

### Fix 4.5: Practice Mode
- For now: remove or replace with "Coming Soon" tooltip
- Future: spawn bot at position for practice

---

## Phase 5: Testing & Validation

### Unit Tests
- Classification thresholds (all boundary cases)
- Mate score conversion
- FEN validation edge cases
- Cache hit/miss logic
- Empty game handling

### Integration Tests
- Full game analysis end-to-end
- Navigation after analysis
- Cancel during analysis
- Re-enter analysis screen

### Stability Tests
- Rapid start/stop analysis (10x)
- Invalid FEN handling
- Memory leak check (analysis → leave → re-enter 10x)

---

## Execution Order

| Order | Phase | Priority | Est. Time |
|-------|-------|----------|-----------|
| 1 | Phase 0: Crash Stability | CRITICAL | 45 min |
| 2 | Phase 1: Cache Performance | HIGH | 20 min |
| 3 | Phase 2: Classification Accuracy | HIGH | 25 min |
| 4 | Phase 3: Loading States | HIGH | 15 min |
| 5 | Phase 4: UI Upgrades | MEDIUM | 40 min |
| 6 | Phase 5: Testing | HIGH | 30 min |
| 7 | Build & Install | HIGH | 15 min |
| **Total** | | | **~3 hours** |
