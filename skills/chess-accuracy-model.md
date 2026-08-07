# Chess Accuracy Model Skill

## Purpose
Implements the Lichess/WinPercent-based accuracy calculation system for chess move analysis, replacing the inferior CPL (Centipawn Loss) based approach.

## Formulas

### 1. Centipawns to Win Percentage
Converts engine evaluation (in centipawns) to a human-interpretable win probability.

```dart
double centipawnsToWinPercent(double centipawns) {
  const MULTIPLIER = -0.00368208;
  return 50.0 + 50.0 * (2.0 / (1.0 + exp(MULTIPLIER * centipawns)) - 1.0);
}
```

**Properties:**
- Input: -10000 to +10000 centipawns
- Output: 0.0 to 100.0 (percentage)
- 50% = equal position
- >50% = advantage for side to move (from White's perspective in Lichess)
- Sigmoid/logistic curve shape
- Calibrated against 2300+ Lichess rapid games

**Reference:** github.com/lichess-org/lila/blob/master/modules/analyse/src/main/WinPercent.scala

### 2. Move Accuracy from Win% Difference
Calculates how accurate a single move was based on win probability change.

```dart
double accuracyFromWinPercentDiff(double winDiff) {
  if (winDiff <= 0) return 100.0; // Move did not lose anything (or engine found it later)
  const a = 103.1668;
  const k = -0.04354;
  const b = -3.1669;
  final raw = a * exp(k * winDiff) + b;
  return raw.clamp(0.0, 100.0);
}
```

**Properties:**
- winDiff = winPercentBefore - winPercentAfter (positive = lost chances)
- 0% diff = 100% accuracy (perfect move)
- Large diff = low accuracy
- Non-linear: small losses in close positions hurt more

### 3. Game Accuracy (Volatility-Weighted + Harmonic Mean)
Combines per-move accuracies into a single game score that matches player intuition.

```dart
double gameAccuracy(List<double> moveAccuracies, List<double> winPercents) {
  if (moveAccuracies.isEmpty) return 0.0;
  if (moveAccuracies.length == 1) return moveAccuracies.first;
  
  // Window size: ~10% of game length, clamped to [2, 8]
  final windowSize = (winPercents.length / 10).round().clamp(2, 8);
  
  // Calculate volatility (standard deviation of Win%) for each move
  final weights = <double>[];
  for (int i = 0; i < winPercents.length - 1; i++) {
    final start = (i - windowSize ~/ 2).clamp(0, winPercents.length - windowSize);
    final end = start + windowSize;
    final window = winPercents.sublist(start, end);
    final mean = window.reduce((a, b) => a + b) / window.length;
    final variance = window.map((w) => (w - mean) * (w - mean)).reduce((a, b) => a + b) / window.length;
    final stdDev = sqrt(variance);
    weights.add(stdDev.clamp(0.5, 12.0));
  }
  
  // Pad weights to match moveAccuracies length
  while (weights.length < moveAccuracies.length) {
    weights.add(weights.isEmpty ? 1.0 : weights.last);
  }
  
  // Volatility-weighted mean: important moments count more
  double weightedSum = 0;
  double weightTotal = 0;
  for (int i = 0; i < moveAccuracies.length; i++) {
    weightedSum += moveAccuracies[i] * weights[i];
    weightTotal += weights[i];
  }
  final weightedMean = weightedSum / weightTotal;
  
  // Harmonic mean: penalizes bad moves more than arithmetic mean
  double harmonicSum = 0;
  for (final acc in moveAccuracies) {
    harmonicSum += 1.0 / acc.clamp(1.0, 100.0);
  }
  final harmonicMean = moveAccuracies.length / harmonicSum;
  
  // Final: average of weighted and harmonic means
  return (weightedMean + harmonicMean) / 2.0;
}
```

**Why this approach:**
- **Volatility weighting**: Moments where the evaluation swings a lot are more important. A blunder in a quiet position matters less than one in a sharp tactical battle.
- **Harmonic mean**: Naturally penalizes outliers (bad moves). One 10% accuracy move hurts more than five 90% moves help.
- **Combined average**: Balances both approaches for a score that feels right to players.

### 4. Move Classification
Classifies moves based on Win% change, not centipawn change.

```dart
enum MoveClassification {
  blunder, miss, mistake, inaccuracy, book,
  good, excellent, best, great, brilliant,
  forced, onlyMove
}

MoveClassification classifyMove({
  required double winPercentBefore,
  required double winPercentAfter,
  required double evalBefore,
  required double evalAfter,
  required bool isWhiteMove,
  required String? bestMove,
  required String actualMove,
}) {
  final winDiff = winPercentBefore - winPercentAfter;
  final accuracy = accuracyFromWinPercentDiff(winDiff);
  
  // Special cases
  if (actualMove == bestMove) return MoveClassification.best;
  if (winDiff <= 0) {
    // Move did not lose anything
    return accuracy >= 95 ? MoveClassification.excellent : MoveClassification.good;
  }
  
  // Normal classification by win% lost
  if (winDiff >= 20) return MoveClassification.blunder;     // Lost 20%+ win probability
  if (winDiff >= 10) return MoveClassification.mistake;     // Lost 10-20%
  if (winDiff >= 5) return MoveClassification.inaccuracy;   // Lost 5-10%
  return MoveClassification.good;                           // Lost <5%
}

// Detecting special moves
bool isBrilliantMove({
  required double winPercentBefore,
  required double winPercentAfter,
  required String actualMove,
  required String? bestMove,
  required List<String> alternativeMoves,
  required double materialBefore,
  required double materialAfter,
  required bool isWhiteMove,
}) {
  // Conditions for "brilliant":
  // 1. Material was sacrificed (eval dropped due to material loss)
  // 2. But position actually improved or stayed good
  // 3. It was NOT the engine's top choice (creative find)
  // 4. A safer alternative was available
  
  final materialDiff = materialBefore - materialAfter;
  final sacrificedMaterial = isWhiteMove ? materialDiff > 0 : materialDiff < 0;
  final isTopChoice = actualMove == bestMove;
  final winDiff = winPercentBefore - winPercentAfter;
  final stayedStrong = winDiff < 5; // Did not lose much win probability
  
  return sacrificedMaterial && stayedStrong && !isTopChoice;
}

bool isGreatMove({
  required String actualMove,
  required String? bestMove,
  required List<String> topMoves,
  required double winPercentBefore,
  required double winPercentAfter,
}) {
  // "Great" = the only move that maintains a difficult position
  // All other moves lose significantly
  if (actualMove == bestMove) return false;
  
  final winDiff = winPercentBefore - winPercentAfter;
  if (winDiff > 5) return false; // Lost too much to be "great"
  
  // Check if all other top moves lose significantly
  // This requires engine analysis of alternatives at depth+2
  return false; // Placeholder - needs multi-PV analysis
}

bool isMissedMove({
  required String? bestMove,
  required String actualMove,
  required double winPercentBefore,
  required double winPercentAfter,
}) {
  // "Miss" = there was a concrete winning tactic and player did not find it
  // Detected when: best move leads to forced win, but actual move does not
  return false; // Placeholder - needs mate detection logic
}
```

## Implementation Notes

1. **Cache Win% values**: Convert centipawns to Win% once per position and store it.
2. **Handle mate scores**: When eval is a mate score (e.g., "mate in 5"), set Win% to 99.9 or 0.1 accordingly.
3. **Opening book**: First ~6 moves in known openings should be classified as "book" not graded.
4. **Uncertainty bonus**: Lichess adds +1% to each move accuracy to account for engine imperfection at limited depth.
5. **Game phase detection**: Opening = first 15% of moves, Endgame = last 25%, Middlegame = rest.

## Testing Strategy

1. **Known positions**: Test Win% for positions with known evaluations
2. **Sample games**: Compare full game accuracy with Lichess for the same PGN
3. **Edge cases**: All-book game (100%), all-blunders (0%), single-move game
4. **Consistency**: Ensure accuracy is always between 0 and 100

## References
- Lichess accuracy page: lichess.org/page/accuracy
- Lichess source: github.com/lichess-org/lila (AccuracyPercent.scala, WinPercent.scala)
- Chess.com: support.chess.com/en/articles/8708970
