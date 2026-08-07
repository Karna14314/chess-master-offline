# Engine & Notification Service Audit

## Engine Implementation Assessment

### What Is Excellent
- **Isolate-based Stockfish** — runs off UI thread, no ANR
- **Atomic concurrency guards** — `_isEngineBusy` claimed synchronously
- **Per-search identity tokens** — stale `bestmove` lines discarded
- **FEN validation** — custom validator prevents native SIGSEGV
- **Three-tier fallback** — Stockfish to SimpleBot to BasicEval
- **Recoverable fallback** — 30s cooldown with `resetFallback()`
- **Comprehensive tests** — 315 tests passing, 42 test files

### What Needs Improvement
1. **No reference counting** — analysis disposes shared singleton
2. **Single engine instance** — cannot run analysis and bot simultaneously
3. **No engine lifecycle management** — who owns the engine's lifecycle?
4. **No "analysis mode" vs "play mode" separation** — same engine does both

### Recommendation
- Add reference counting to StockfishService
- AnalysisNotifier should `acquire()` and `release()` the engine
- Or create a separate analysis engine instance
- Add engine lifecycle observer (already exists as stockfish_lifecycle_observer.dart but unclear usage)

---

## Notification Service Audit

### Current State
- `flutter_local_notifications` is in pubspec.yaml
- No dedicated `notification_service.dart` file found
- No notification-related code in the codebase
- No post-game analysis notification
- No daily puzzle reminder
- No achievement unlock notification

### Lichess Notification Features
- "Your game with [player] has been analyzed"
- "New puzzle is available"
- "You have a new follower" (not applicable for offline)
- "Tournament starting soon" (not applicable for offline)

### Chess.com Notification Features
- "Game analysis ready"
- "Daily puzzle available"
- "New achievement unlocked"
- "Streak reminder"

### Recommended Notification Implementation
1. **Post-game analysis ready** — "Your game analysis is ready! Accuracy: 87%"
2. **Daily puzzle** — "New puzzle available! Current streak: 5"
3. **Achievement unlocked** — "Achievement unlocked: Win 10 games in a row"
4. **Streak reminder** — "Keep your puzzle streak alive! Solve today's puzzle"
5. **Rating milestone** — "Congratulations! You reached 1600 rating"

### Implementation Plan
1. Create `lib/services/notification_service.dart`
2. Initialize `FlutterLocalNotificationsPlugin` in main.dart
3. Request permissions on first launch
4. Schedule daily puzzle notification at user's preferred time
5. Trigger post-game analysis notification
6. Add notification settings in Settings screen
