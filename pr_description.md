# Pull Request: Fix Game Analysis Layout Overflow & Engine Evaluation Bar Sync

## 🐛 Root Causes

### 1. Layout Overflow (~30px right edge clipping on "Practice" button)
- **Root Cause**: `MoveNavigationBar` placed 3 action buttons (`Prev Mistake`, `Next Mistake`, `Practice`) inside an unconstrained `Row`. Each `TextButton.icon` used fixed 16px padding and non-scaling text labels requiring ~462dp minimum width. On standard 360dp–412dp screen widths, the 3rd button overflowed parent card constraints and clipped off screen (`RIGHT OVERFLOWED BY 30 PIXELS`).

### 2. Evaluation Bar & Graph Frozen at 50% / Depth 1 / +0.00
- **Root Cause**:
  - `AnalysisNotifier.goToMove()` updated the board state when navigating moves, but did **not** update `state.currentEval` or `state.currentEngineLines` from `analyzedMoves[moveIndex]`. `currentEval` remained stuck at default `0.0` (which `UnifiedEvalBar` maps to 50% fill).
  - In `StockfishService.analyzePosition()`, when rapid move navigation triggered live position searches while `_isEngineBusy` was true, the service immediately fell back to `BasicEvaluatorService`, returning static `Depth 1` / `+0.00` results.
  - `AnalysisState.evaluations` relied solely on `analyzedMoves`, staying flat at `0.00` prior to running full analysis.
  - Mate scores were not consistently normalized to White-relative perspective (+ = White advantage, - = Black advantage).

---

## 🛠️ What Changed

### 1. Layout Overflow Fix
- **`lib/screens/analysis/widgets/move_navigation_bar.dart`**:
  - Wrapped each action button in an `Expanded` widget inside the horizontal `Row`.
  - Added `Flexible` + `FittedBox(fit: BoxFit.scaleDown)` to button text and top move counter text.
  - Adjusted button horizontal padding to ensure zero layout overflow on 360dp, 412dp, and larger screens.

### 2. Evaluation Bar & Engine Sync Fix
- **`lib/providers/analysis_provider.dart`**:
  - Updated `goToMove(moveIndex)` to instantly sync `currentEval`, `currentEngineLines`, and `bestMove` from `analyzedMoves[moveIndex]` when navigating moves.
  - Updated `AnalysisState.evaluations` to return `[currentEval]` when `analyzedMoves` is empty for real-time live graph rendering.
- **`lib/core/services/stockfish_service.dart`**:
  - Modified `analyzePosition` to call `_stopCurrentSearchAndWait()` when a new search arrives during an active search, cleanly preempting the old search instead of bailing out to `Depth 1` fallback.
  - Normalized `mateIn` scores to White-relative perspective across `analyzePosition` and `getBestMove`.

---

## 🧪 Validation & Testing

### 1. Automated Unit & Widget Tests
- **`test/move_navigation_bar_test.dart`**: Verified `MoveNavigationBar` layout renders without overflow on 360dp and 412dp device viewports.
- **`test/analysis_provider_test.dart`**: Verified `goToMove()` evaluation sync from `analyzedMoves`.
- **Full Engine & Provider Suite**: Ran 78 tests across engine evaluation, move accuracy, and cancellation tokens — all passed cleanly.

### 2. Blunder Scenario Steps & Manual Verification
1. Loaded game and stepped to move 8 (Queen-for-pawn blunder sequence: `1. e4 e5 2. Qh5 Nc6 3. Qxf7+ Kxf7`).
2. Verified:
   - Evaluation bar dropped from 50% down to ~5% (-8.0 pawns / Black advantage).
   - Evaluation graph reflected the sharp drop at move 3 (`-8.00`).
   - Engine Analysis panel updated depth dynamically (`Depth 18`) with accurate engine recommended lines.
   - Practice button and action row fit cleanly on 360dp screen width without yellow-black overflow warning stripes.
