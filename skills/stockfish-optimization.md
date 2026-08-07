# Stockfish Engine Optimization Skill

## Purpose
Best practices for integrating Stockfish into a Flutter/Dart mobile chess application, optimized for offline mobile play with proper resource management.

## Architecture Patterns

### 1. Isolate-Based Engine (Recommended)
Run Stockfish in a dedicated Dart Isolate to prevent UI jank.

```dart
// Stockfish runs in its own isolate
// Communication via SendPort/ReceivePort
// All UCI commands go through a command queue
// Output is streamed back via StreamController
```

**Why isolates:**
- Stockfish search is CPU-intensive
- Blocking the UI thread causes dropped frames (ANR on Android)
- Isolates run on separate threads automatically

### 2. Reference Counting
Prevent premature disposal when multiple screens use the engine.

```dart
class StockfishService {
  int _refCount = 0;
  
  void acquire() => _refCount++;
  
  void release() {
    _refCount--;
    if (_refCount <= 0) {
      dispose();
    }
  }
}
```

### 3. Search Token Pattern
Prevent stale results from abandoned searches.

```dart
int _activeSearchId = 0;

Future<BestMoveResult> getBestMove(...) async {
  final searchId = ++_activeSearchId;
  // ... start search ...
  
  // Check if this search is still the active one
  if (searchId != _activeSearchId) {
    return null; // Stale result, discard
  }
  // ... process result ...
}
```

### 4. Atomic Busy Flag
Prevent overlapping searches.

```dart
bool _isEngineBusy = false;

Future<BestMoveResult?> safeSearch(...) async {
  // Atomic claim (no await between check and set)
  if (_isEngineBusy) return null;
  _isEngineBusy = true;
  
  try {
    return await _doSearch();
  } finally {
    _isEngineBusy = false;
  }
}
```

## Mobile Optimization

### 1. Engine Options for Mobile
```
setoption name Threads value 2        // Mobile CPUs: 2 threads max
setoption name Hash value 64          // 64MB hash (memory-constrained)
setoption name UCI_LimitStrength value true   // For difficulty levels
setoption name UCI_Elo value 1500     // Dynamic based on difficulty
```

### 2. Search Constraints
- **Bot play**: `go movetime N` (time-bounded, responsive)
- **Analysis**: `go depth N` (depth-bounded, thorough)
- **Never combine**: Use one or the other, not both simultaneously

### 3. FEN Validation
Always validate FEN before sending to Stockfish to prevent native crashes (SIGSEGV).

```dart
bool _isValidFen(String fen) {
  final parts = fen.split(' ');
  if (parts.length < 6) return false;
  
  // Validate board: 8 ranks, exactly 8 squares per rank
  final ranks = parts[0].split('/');
  if (ranks.length != 8) return false;
  
  for (final rank in ranks) {
    int squares = 0;
    for (final char in rank.split('')) {
      if (RegExp(r'[1-8]').hasMatch(char)) {
        squares += int.parse(char);
      } else if (RegExp(r'[prnbqkPRNBQK]').hasMatch(char)) {
        squares += 1;
      } else {
        return false;
      }
    }
    if (squares != 8) return false;
  }
  
  // Validate side to move
  if (parts[1] != 'w' && parts[1] != 'b') return false;
  
  // Validate castling (simplified check)
  if (!RegExp(r'(-|K?Q?k?q?)').hasMatch(parts[2])) return false;
  
  return true;
}
```

### 4. Three-Tier Fallback
```
Primary: Stockfish (strongest, requires binary)
Fallback 1: SimpleBot (pure Dart, moderate strength, no native deps)
Fallback 2: BasicEvaluator (static eval, weakest but always available)
```

**Recovery:** After fallback, periodically retry Stockfish init (30s cooldown).

### 5. Memory Management
- Dispose isolate when app goes to background
- Recreate on foreground (lazy re-init)
- Limit hash size to prevent OOM on low-end devices
- Clear analysis cache periodically

## Difficulty Implementation

### UCI_Elo Mapping
Stockfish supports `UCI_LimitStrength` with `UCI_Elo` range 1320-3190.

| Level | ELO | Depth | Think Time | Description |
|-------|-------|-------|------------|-------------|
| 1 | 1320 | 1 | 300ms | Beginner — frequent blunders |
| 2 | 1400 | 3 | 500ms | Novice |
| 3 | 1500 | 5 | 700ms | Casual |
| 4 | 1600 | 8 | 1000ms | Intermediate |
| 5 | 1700 | 10 | 1200ms | Club Player |
| 6 | 1850 | 12 | 1500ms | Advanced |
| 7 | 2000 | 14 | 1800ms | Expert |
| 8 | 2200 | 18 | 2000ms | Master |
| 9 | 2500 | 20 | 2200ms | Grandmaster |
| 10 | 2800 | 22 | 2500ms | Maximum |

**Note:** `UCI_Skill Level` is NOT used when `UCI_LimitStrength` is active.

### Minimum Think Time
Always enforce a minimum think time (300ms) to prevent instant replies:
```dart
const minThinkTime = Duration(milliseconds: 300);
final elapsed = DateTime.now().difference(searchStartTime);
if (elapsed < minThinkTime) {
  await Future.delayed(minThinkTime - elapsed);
}
```

### Adaptive Difficulty
Match bot ELO to player ELO for challenging but winnable games:
```dart
DifficultyLevel getAdaptiveDifficulty(int playerElo) {
  // Find closest difficulty level
  return AppConstants.difficultyLevels.reduce((a, b) =>
    (a.elo - playerElo).abs() < (b.elo - playerElo).abs() ? a : b);
}
```

## Analysis Optimization

### 1. Eval Caching
Cache evaluations in SQLite to avoid recomputing:
```sql
CREATE TABLE analysis_cache (
  fen TEXT NOT NULL,
  depth INTEGER NOT NULL,
  multipv INTEGER NOT NULL,
  evaluation REAL NOT NULL,
  engine_lines TEXT NOT NULL,
  is_mate BOOLEAN DEFAULT 0,
  mate_in INTEGER,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  PRIMARY KEY (fen, depth, multipv)
);
```

**Cache lookup:**
```dart
Future<AnalysisResult?> getCachedEval(String fen, int depth, int multiPv) async {
  // Return cached eval if depth >= requested depth
  // This allows deeper cached results to serve shallower requests
  final result = await db.query('analysis_cache',
    where: 'fen = ? AND depth >= ? AND multipv >= ?',
    whereArgs: [fen, depth, multiPv],
    orderBy: 'depth DESC',
    limit: 1);
  // ... parse and return
}
```

### 2. Incremental Analysis
For full-game analysis, build up results incrementally:
```dart
// First pass: quick analysis (depth 12)
// Second pass: deeper analysis for interesting positions (depth 18+)
// Third pass: deep analysis for critical moments (depth 22+)
```

### 3. Event Loop Yielding
Prevent ANR during long analysis by yielding periodically:
```dart
for (int i = 0; i < moves.length; i++) {
  // Yield every 5 moves
  if (i % 5 == 0 && i > 0) {
    await Future.delayed(Duration.zero);
  }
  // ... analyze move ...
}
```

### 4. State Batching
Batch UI updates to reduce rebuilds:
```dart
// Update every 10 moves instead of every move
if ((i + 1) % 10 == 0 || i == moves.length - 1) {
  state = state.copyWith(
    analysisProgress: (i + 1) / moves.length,
    analyzedMoves: List.from(analyzedMoves),
  );
}
```

## Error Handling

### 1. Engine Timeout
```dart
final result = await engine.analyzePosition(...)
  .timeout(Duration(seconds: 10), onTimeout: () {
    throw TimeoutException('Engine analysis timed out');
  });
```

### 2. Isolate Crash Recovery
```dart
// If isolate dies, restart it
void _restartIsolate() {
  _engineIsolate?.kill();
  _engineIsolate = null;
  _engineCommandPort = null;
  _isReady = false;
  // Next call to initialize() will restart
}
```

### 3. FEN Validation
Always validate before sending to Stockfish. Invalid FEN can cause native SIGSEGV.

### 4. Graceful Degradation
If Stockfish fails:
1. Try restarting isolate
2. Fall back to SimpleBotService
3. Fall back to BasicEvaluatorService
4. Show user-friendly error message

## Testing Strategy

### Unit Tests
- Test UCI command parsing
- Test Win% formula accuracy
- Test FEN validation
- Test ELO calculation
- Test cache hit/miss logic

### Integration Tests
- Test full game analysis flow
- Test bot move generation
- Test concurrent search prevention
- Test fallback chain

### Performance Tests
- Measure time per move at each difficulty level
- Verify no ANR during full game analysis
- Memory usage profiling
- Battery consumption profiling

## References
- Stockfish UCI protocol: official-stockfish.github.io/docs/uci-protocol.html
- Stockfish repo: github.com/official-stockfish/Stockfish
- Lichess analysis: github.com/lichess-org/lila/tree/master/modules/analyse
- Dart isolates: dart.dev/language/isolates
