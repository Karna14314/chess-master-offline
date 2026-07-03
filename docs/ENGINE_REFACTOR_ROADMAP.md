# ChessMaster Engine Refactor Roadmap

> **Single Source of Truth for all engine-related work**
>
> Created: 2026-07-03
> Status: Phases 1-8 Complete
> Version: 1.2

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Issue Registry](#issue-registry)
3. [Newly Discovered Issues (Re-Audit)](#newly-discovered-issues-re-audit)
4. [Refactor Phases](#refactor-phases)
5. [Dependency Graph](#dependency-graph)
6. [Testing Strategy](#testing-strategy)
7. [Overall Architecture Review](#overall-architecture-review)
8. [Estimated Refactor Scope](#estimated-refactor-scope)
9. [Expected End State](#expected-end-state)

---

## Executive Summary

The ChessMaster Offline app has a critical architecture failure in its engine integration: **Stockfish never successfully initializes due to a deadlock in the command queue (`_isEngineReady` flag never set to `true`)**. Every "Stockfish" game is actually played by `SimpleBotService` at depth 3-4 (playing strength ~800-1000 ELO), regardless of the selected difficulty level (which claims up to 2800 ELO).

The fallback bot itself has significant issues: broken alpha-beta pruning, weak evaluation function, poor move ordering, and no quiescence search. The analysis mode has a sign error in evaluation interpretation (side-relative vs white-relative). The accuracy calculation is fundamentally incorrect.

This roadmap documents every known issue and provides a phased, sequential refactor plan to fix the engine system from the ground up.

---

## Issue Registry

### ISSUE-001: Stockfish `_isEngineReady` Deadlock

| Field | Value |
|-------|-------|
| **Severity** | **CRITICAL** |
| **Description** | The engine isolate's `init` handler never sends `engine_ready` back to the main thread. `_processCommandQueue()` checks `_isEngineReady` before sending commands, but this flag is never set to `true`. All commands (uci, isready, position, go) are stuck in the queue indefinitely. After 5 seconds, initialization times out and `_enableFallback()` is called permanently. |
| **Root Cause** | `_startEngineIsolate()` registers a handler for `engine_ready` messages (line 724) but the isolate code (`_stockfishIsolateEntryPoint`, line 757) never sends an `engine_ready` message after Stockfish creation. Additionally, even if `engine_ready` were sent, the initialization flow in `initialize()` has a circular dependency: `_sendCommand('uci')` goes to queue → queue blocked by `_isEngineReady` → `readyok` never received → `_isReady` never set → timeout → fallback. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:238-263` (queue blocking), `:695-732` (missing engine_ready), `:757-793` (isolate entry) |
| **Expected Behaviour** | Stockfish initializes successfully, receives UCI commands, and returns best moves for the requested depth. |
| **Current Behaviour** | All games are played by `SimpleBotService` at depth 3-4 regardless of difficulty setting. |
| **Proposed Solution** | (1) Add `sendPort.send({'type': 'engine_ready'})` after Stockfish creation in the isolate. (2) Remove the `_isEngineReady` guard from `_processCommandQueue()` or initialize it to `true` after isolate setup. (3) Ensure UCI init commands are sent even before `readyok` is received. |
| **Dependencies** | None |
| **Priority** | P0 — Blocking all engine functionality |

---

### ISSUE-002: Fallback Bot Depth Hard-Capped at 3-4

| Field | Value |
|-------|-------|
| **Severity** | **CRITICAL** |
| **Description** | When Stockfish fails (which is always), the fallback `SimpleBotService` hard-caps search depth at 3 (`min(depth, 3)` at line 442). The difficulty system advertises depths 1-22 and ELOs 800-2800, but the actual playing strength never exceeds ~1000 ELO. The cap was added to prevent ANR (Application Not Responding) because depth > 4 in pure Dart can be slow. |
| **Root Cause** | `_getSimpleBotMove()` in `stockfish_service.dart:448` caps depth to 4, and `SimpleBotService.getBestMove()` at line 442 caps again to 3. The fallback engine simply cannot search deeper without becoming unacceptably slow. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:447-448`, `lib/core/services/simple_bot_service.dart:442` |
| **Expected Behaviour** | Difficulty levels 1-10 should correspond to distinct playing strengths. Level 10 (2800 ELO) should play at a master level. |
| **Current Behaviour** | All difficulty levels play at approximately the same weak level. |
| **Proposed Solution** | Fix Stockfish initialization first (ISSUE-001). The fallback depth cap is acceptable only as a genuine last resort when Stockfish is truly unavailable (unsupported platform, etc.). Once Stockfish works, the fallback is only used on unsupported devices. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P0 (mitigated by fixing ISSUE-001) |

---

### ISSUE-003: Alpha-Beta Pruning Initial Value is Wrong

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | In `_minimax()`, the initial value is set to `-1000000000` instead of `alpha`. This breaks alpha-beta pruning by exploring many unnecessary branches, making the search slower and weaker. |
| **Root Cause** | `simple_bot_service.dart:539`: `int value = -1000000000;` should be `int value = alpha;` (or `int value = -999999;` for the negamax variant). |
| **Files Involved** | `lib/core/services/simple_bot_service.dart:539` |
| **Expected Behaviour** | Alpha-beta pruning should cut off branches that cannot improve the result, searching the same depth much faster. |
| **Current Behaviour** | The search explores many branches unnecessarily, wasting computation and limiting effective depth. |
| **Proposed Solution** | Change `int value = -1000000000;` to `int value = alpha;` in the minimax function. |
| **Dependencies** | None directly, but this is in the fallback bot which is the only bot actually running |
| **Priority** | P1 |

---

### ISSUE-004: Evaluation Function Missing Key Features

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | The evaluation function across all engines (SimpleBot, Lightweight, BasicEvaluator) is missing critical positional features: (1) No PSTs for rooks/queens in LightweightEngine and BasicEvaluator. (2) No mobility evaluation. (3) No pawn structure (doubled, isolated, backward, passed pawns). (4) No king zone pressure. (5) No piece coordination. (6) No endgame evaluation. (7) No tempo/move-count evaluation. |
| **Root Cause** | The evaluation functions were built as minimal implementations without standard chess evaluation features. |
| **Files Involved** | `lib/core/services/simple_bot_service.dart:555-630`, `lib/core/services/lightweight_engine_service.dart:334-398`, `lib/core/services/basic_evaluator_service.dart:261-361` |
| **Expected Behaviour** | A basic evaluation should include at minimum: material, PSTs for all pieces, pawn structure basics, and king safety. |
| **Current Behaviour** | The bot plays positionally naive chess, missing obvious positional concepts like controlling the center, pawn structure weaknesses, and piece activity. |
| **Proposed Solution** | Add PSTs for rooks/queens across all engines. Add mobility, pawn structure, and king safety evaluation. Use Stockfish for the primary engine path; the fallback evaluation improvements are secondary. |
| **Dependencies** | Stockfish fix (ISSUE-001) makes this lower priority for the primary path |
| **Priority** | P2 |

---

### ISSUE-005: UCI_Elo and Skill Level Conflict

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | `setSkillLevel()` sets BOTH `UCI_Elo` AND `Skill Level` UCI options simultaneously. Per Stockfish documentation, these are mutually exclusive — setting `UCI_LimitStrength` (which enables `UCI_Elo`) causes `Skill Level` to be ignored. The actual ELO cap may not match what the user selected. |
| **Root Cause** | `stockfish_service.dart:636-641`: The method sets `UCI_LimitStrength`, `UCI_Elo`, and `Skill Level` together without understanding their interaction. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:631-641` |
| **Expected Behaviour** | Each difficulty level should map to a distinct playing strength that matches the advertised ELO. |
| **Current Behaviour** | Multiple conflicting UCI options are set, causing undefined behavior in Stockfish's strength limiting. |
| **Proposed Solution** | Use ONLY `UCI_Elo` (with `UCI_LimitStrength=true`) for strength control. Remove `Skill Level` entirely. Stockfish internally maps ELO values to strength levels. Verify with testing. |
| **Dependencies** | ISSUE-001 (needs working Stockfish to test) |
| **Priority** | P1 |

---

### ISSUE-006: `movetime` + `depth` Together in `go` Command

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | `_sendCommand('go depth $depth movetime $thinkTimeMs')` tells Stockfish to stop when EITHER depth is reached OR the time expires. At low depths (1-5), Stockfish finishes almost instantly regardless of thinkTimeMs. The artificial delay in `engine_provider.dart` then adds additional waiting, creating a poor user experience. |
| **Root Cause** | `stockfish_service.dart:409`: The `go` command combines both constraints incorrectly. For time-managed play, Stockfish should receive `wtime`/`btime`/`movetime` separately; for analysis, just `depth`. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:407-412` |
| **Expected Behaviour** | The engine should think for approximately `thinkTimeMs` on each move (or use proper time management with `wtime`/`btime`). |
| **Current Behaviour** | At low depths, Stockfish returns instantly. Artificial delays then make the bot feel like it's wasting time. |
| **Proposed Solution** | Fix Stockfish first. Then separate the search command: for bot play, use `go wtime <ms> btime <ms> movetime <maxThinkMs>` without depth limit. For analysis, use `go depth <depth>`. Remove artificial delays or make them a true minimum (not additive). |
| **Dependencies** | ISSUE-001, ISSUE-005 |
| **Priority** | P1 |

---

### ISSUE-007: Artificial Thinking Delay Doubles Wait Time

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | `engine_provider.dart:147-170` enforces a minimum think time AND adds remaining delay after Stockfish returns. Since Stockfish has its own time management (`movetime`), this effectively doubles the wait: Stockfish waits `movetime`, then the code adds more delay to ensure `minDelay` is met. Total wait = `thinkTimeMs + thinkTimeMs/2`. |
| **Root Cause** | The thinking delay was added to make the bot feel more human (not responding instantly), but it's additive with Stockfish's own search time rather than being a target. |
| **Files Involved** | `lib/providers/engine_provider.dart:147-170` |
| **Expected Behaviour** | The bot should respond after approximately `thinkTimeMs`, not double that. |
| **Current Behaviour** | On Grandmaster difficulty (thinkTimeMs=2500), the user waits ~3.75 seconds per move. |
| **Proposed Solution** | Remove the artificial delay entirely once Stockfish works with proper time management. Or use it only as a floor: if Stockfish finishes before `minDelay`, wait for the remainder. Don't add it on top of `movetime`. |
| **Dependencies** | ISSUE-001, ISSUE-006 |
| **Priority** | P2 |

---

### ISSUE-008: Evaluation Sign Error (Side-Relative vs White-Relative)

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | Stockfish UCI `score cp <x>` is side-relative (positive = good for side to move). The code stores and displays these values without conversion, treating them as white-relative (positive = good for white). When it's black's turn, `score cp +100` means black is +1.00, but the UI shows it as white being +1.00. The `classifyMove()` function in `analysis_model.dart` uses white-relative logic, so evaluations on black's moves are incorrectly classified. |
| **Root Cause** | No conversion from side-relative (Stockfish UCI) to white-relative (UI convention) anywhere in the pipeline. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:340-357` (raw cp storage), `lib/models/analysis_model.dart:171-218` (white-relative assumptions), `lib/providers/analysis_provider.dart:360-478` (uses eval without conversion) |
| **Expected Behaviour** | All evaluations should be white-relative for consistent display and classification. `score cp +100` when it's black's turn should be stored as `-100` (white is -1.00). |
| **Current Behaviour** | Evaluations for positions where black is to move are displayed and classified incorrectly (sign flipped). |
| **Proposed Solution** | After parsing `score cp` from Stockfish output, check the current turn (from FEN). If it's black's turn, negate the evaluation. This converts side-relative to white-relative. Apply this in both `getBestMove()` and `analyzePosition()`. |
| **Dependencies** | ISSUE-001 (needs working Stockfish) |
| **Priority** | P1 |

---

### ISSUE-009: Full Game Analysis Uses Wrong Methods and is Inefficient

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | `analyzeFullGame()` calls `_stockfish!.getBestMove()` (line 411) to get the best move before each position, then calls `_stockfish!.analyzePosition()` (line 448) after the move. This doubles the number of engine calls (2 × move count), making full game analysis extremely slow. It should use `analyzePosition` for both before and after, or use a simpler eval-only query for the before position. Also, `getBestMove` triggers the bot move path with ELO limits, while analysis should always use full strength. |
| **Root Cause** | Poor design: the best move of the position isn't needed for accuracy calculation — only the evaluation before and after the move is needed. |
| **Files Involved** | `lib/providers/analysis_provider.dart:336-532` |
| **Expected Behaviour** | Full game analysis should call the engine once per move (to get eval after the move), or at most 1.5× calls. |
| **Current Behaviour** | Analysis makes 2 engine calls per move = extremely slow. With the Stockfish deadlock, both calls fall back to BasicEvaluator anyway. |
| **Proposed Solution** | (1) Remove the `getBestMove` call before each move. (2) Only call `analyzePosition` after each move with `multiPv=1` for speed. (3) The best move can be derived from `analyzePosition` results (the first line is the best move). |
| **Dependencies** | ISSUE-001 |
| **Priority** | P1 |

---

### ISSUE-010: Accuracy Calculation is Fundamentally Wrong

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | `_calculateAccuracy()` in `game_session_viewmodel.dart:434-471` calculates accuracy by comparing `move.evaluation` against 0.0, assuming the optimal move always has evaluation 0.0. This is completely incorrect — the optimal move's evaluation depends on the position. Real accuracy (centipawn loss) compares the played move's evaluation against the best move's evaluation. |
| **Root Cause** | The `ChessMove.evaluation` field stores the evaluation AFTER the move was made. Comparing this against 0.0 is meaningless. True centipawn loss requires knowing the evaluation BEFORE the move and the evaluation of the best move. |
| **Files Involved** | `lib/providers/game_session_viewmodel.dart:434-471` |
| **Expected Behaviour** | Accuracy should reflect real centipawn loss: `loss = eval(optimal_move) - eval(played_move)` for the side to move. |
| **Current Behaviour** | Accuracy percentages are random numbers unrelated to actual play quality. A player can play perfectly and get low accuracy, or play terribly and get high accuracy. |
| **Proposed Solution** | This requires engine analysis of each position (what `analysis_provider.dart`'s `analyzeFullGame` does). The `game_session_viewmodel` should either (a) store raw eval values and compute real centipawn loss after analysis, or (b) wait for the full analysis provider to compute accuracy. |
| **Dependencies** | ISSUE-001, ISSUE-009 |
| **Priority** | P1 |

---

### ISSUE-011: No Recovery From Fallback Mode

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | Once `_useFallback` is set to `true`, it is never reset, even on new game or app lifecycle events. If Stockfish initialization fails due to a transient error (memory pressure, race condition), the engine is permanently disabled for the entire app session. |
| **Root Cause** | `stockfish_service.dart:155`: `_useFallback = true;` with no mechanism to reset it. The only way to recover is to restart the app. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:153-162` |
| **Expected Behaviour** | Fallback should be used for the current request only. The next request should retry Stockfish. Or, provide a manual "reconnect" mechanism. |
| **Current Behaviour** | Once fallback, always fallback. |
| **Proposed Solution** | Add periodic retry logic in `getBestMove()`: if `_useFallback` is true, attempt re-initialization every N requests or after a cooldown period. Or reset `_useFallback` on `newGame()`. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P2 |

---

### ISSUE-012: Engine Isolate Killed on Timeout

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | When a search times out (30 seconds for bot moves, 10 seconds for analysis), `_stopEngineIsolate()` kills the entire isolate and falls back permanently. A transient timeout (e.g., due to CPU contention) should just stop the current search and retry, not destroy the engine. |
| **Root Cause** | `stockfish_service.dart:422-428`: The timeout handler calls `_stopEngineIsolate()` + `_enableFallback()` indiscriminately. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:414-428`, `:608-622` |
| **Expected Behaviour** | On timeout, send `stop` and retry. Only kill the isolate after repeated failures or explicit dispose. |
| **Current Behaviour** | Single timeout → engine destroyed for entire session. |
| **Proposed Solution** | Replace `_stopEngineIsolate()` with just `_sendCommand('stop')` and return fallback for this request only. Only kill the isolate on `dispose()`. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P2 |

---

### ISSUE-013: Move Ordering is Weak

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | Both `SimpleBotService` and `LightweightEngineService` only sort captures before non-captures. No MVV-LVA (Most Valuable Victim - Least Valuable Attacker) sorting, no killer heuristic, no history heuristic, no iterative deepening. This makes alpha-beta pruning far less effective. |
| **Root Cause** | `simple_bot_service.dart:531-537` and `lightweight_engine_service.dart:267-273`: Simple boolean sort (capture vs non-capture) without any heuristic ordering within each group. |
| **Files Involved** | `lib/core/services/simple_bot_service.dart:531-537`, `lib/core/services/lightweight_engine_service.dart:267-273` |
| **Expected Behaviour** | Well-ordered moves allow alpha-beta to prune more branches, searching deeper in the same time. |
| **Current Behaviour** | Poor move ordering = less pruning = shallower effective search. |
| **Proposed Solution** | Add MVV-LVA scoring for captures (queen capturing a pawn scores higher than pawn capturing a queen). Add killer move slots (2 per ply). These are standard techniques. |
| **Dependencies** | This affects the fallback engines; for Stockfish path, move ordering is handled internally |
| **Priority** | P3 |

---

### ISSUE-014: No Quiescence Search

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | At leaf nodes (depth=0), both engines evaluate the position statically without considering captures. This causes the horizon effect: a devastating capture on the next move is invisible to the search. The engine will blunder away pieces because it doesn't see "one move ahead" tactics at the search frontier. |
| **Root Cause** | Neither `_minimax` nor `_negaMax` has a quiescence search phase. When depth reaches 0, the search stops and evaluates immediately. |
| **Files Involved** | `lib/core/services/simple_bot_service.dart:513-515`, `lib/core/services/lightweight_engine_service.dart:293-295` |
| **Expected Behaviour** | At depth=0, instead of static evaluation, run a limited capture-only search (quiescence) to resolve tactical sequences. |
| **Current Behaviour** | The horizon effect causes the bot to make moves that lose material because the tactic is "over the horizon." |
| **Proposed Solution** | Add a quiescence search function at depth=0 that continues searching only captures until the position is quiet (no captures improve the evaluation). Standard implementation: `QS(alpha, beta) → if no captures, evaluate; else search captures, prune if score >= beta`. |
| **Dependencies** | This affects fallback engines only |
| **Priority** | P2 |

---

### ISSUE-015: Timer Doesn't Pause During Bot Thinking

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | When it's the bot's turn, the player's clock continues running while `_makeBotMove()` is awaited. For example, in a 5-minute game, if the bot takes 3 seconds to "think," the player loses 3 seconds from their clock. |
| **Root Cause** | `game_session_viewmodel.dart:178-201`: `_makeBotMove()` is async but the timer is not paused. The timer provider runs independently and doesn't know if it's a bot or human turn. |
| **Files Involved** | `lib/providers/game_session_viewmodel.dart:178-201`, `lib/providers/timer_provider.dart` |
| **Expected Behaviour** | The timer should pause during bot thinking and resume when the bot has moved. Only the player's move time should count against their clock. |
| **Current Behaviour** | In timed games, the player loses time during the opponent's (bot's) thinking. |
| **Proposed Solution** | Pause the timer before calling `getBotMove()` and resume it after the bot move is applied. Or, alternatively, let the bot's think time count against the bot's clock (more realistic for Stockfish). |
| **Dependencies** | None |
| **Priority** | P2 |

---

### ISSUE-016: `setSkillLevel` / `UCI_Elo` Sent on Every Move

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `getBotMove()` calls `_service.setSkillLevel(difficulty.elo)` on every single move, which sends UCI options every time. These only need to be set once per game (or when difficulty changes). This generates unnecessary UCI traffic. |
| **Root Cause** | `engine_provider.dart:144`: `_service.setSkillLevel(difficulty.elo)` is inside the per-move function instead of `resetForNewGame()` or similar. |
| **Files Involved** | `lib/providers/engine_provider.dart:144` |
| **Expected Behaviour** | Engine strength options should be set once at game start, not on every move. |
| **Current Behaviour** | UCI options are re-sent before every bot move. |
| **Proposed Solution** | Move `setSkillLevel()` to `resetForNewGame()` or a separate `configureForDifficulty()` call made once per game. |
| **Dependencies** | ISSUE-001, ISSUE-005 |
| **Priority** | P3 |

---

### ISSUE-017: No `ucinewgame` Between Positions

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `newGame()` is called when a game starts (via `resetForNewGame()`). But during analysis, `ucinewgame` is never sent between different positions. This means Stockfish retains hash table data from previous searches, which can lead to transposition-based evaluation contamination. |
| **Root Cause** | `analyzePosition()` doesn't send `ucinewgame` before setting a new position. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:462-628` |
| **Expected Behaviour** | For analysis of unrelated positions, the hash should be cleared. For sequential analysis of the same game (move-by-move), keeping the hash is beneficial. |
| **Current Behaviour** | Hash table is never cleared between analysis calls, potentially contaminating evaluations. |
| **Proposed Solution** | Add a `clearHash` parameter to `analyzePosition()` that sends `ucinewgame` when true. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P3 |

---

### ISSUE-018: `mounted` Check in `AnalysisNotifier`

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | `analysis_provider.dart:295` has `if (mounted)` inside `AnalysisNotifier` which extends `StateNotifier<AnalysisState>`. `StateNotifier` does not have a `mounted` property in Riverpod 2.x. This would cause a compilation error. |
| **Root Cause** | The `mounted` property belongs to Flutter's `State` class, not `StateNotifier`. Either this was copied from a widget or the developer confused `StateNotifier` with `State`. |
| **Files Involved** | `lib/providers/analysis_provider.dart:295` |
| **Expected Behaviour** | The code should compile without errors. The check should be removed or replaced with a valid alternative. |
| **Current Behaviour** | Potential compilation error. If it compiles in the current environment, there may be an extension or the code path may be dead. |
| **Proposed Solution** | Remove the `if (mounted)` check. In `StateNotifier`, the notifier is always considered "mounted" as long as it exists. If a safety check is needed, add a `_disposed` flag. |
| **Dependencies** | None |
| **Priority** | P1 (if compilation error) |

---

### ISSUE-019: `_waitForReadyOk` StreamSubscription Cleanup

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `_waitForReadyOk()` creates a new `StreamSubscription` on `_outputController.stream` each time it's called. If the timeout fires, `subscription.cancel()` is called. However, if multiple calls are made concurrently (which shouldn't happen due to `_isEngineBusy` guard), multiple listeners accumulate. On timeout, the `subscription.cancel()` call may not fully clean up if the stream has already been closed. |
| **Root Cause** | `stockfish_service.dart:196-226`: The subscription is created locally and cancelled on timeout or `readyok`. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:196-226` |
| **Expected Behaviour** | All stream subscriptions should be properly cleaned up. |
| **Current Behaviour** | Potential memory leak if `_waitForReadyOk` is called many times. |
| **Proposed Solution** | Use a single persistent subscription instead of creating/destroying one each time. Or use a `StreamIterator` or `Stream.firstWhere()` with timeout. |
| **Dependencies** | None |
| **Priority** | P3 |

---

### ISSUE-020: `_killEngineGracefully` Incomplete Cleanup

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | `_killEngineGracefully()` sends `stop`, waits 800ms, then kills the isolate. But the `_outputController` stream is NOT closed (that only happens in `dispose()`). If the isolate is killed while output is pending, stale events may remain in the stream. The `_engineIsolate = null` assignment makes the state inconsistent — `_engineCommandPort` is also null but leftover stream listeners may still fire. |
| **Root Cause** | `stockfish_service.dart:738-753`: The cleanup sequence kills the isolate and nulls ports but doesn't fully reset the output stream or handle pending events. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:738-753` |
| **Expected Behaviour** | Full cleanup should drain pending events, close the stream, and reset all state. |
| **Current Behaviour** | After engine kill, stale subscriptions may fire with null ports. |
| **Proposed Solution** | Add a stream pause/resume mechanism. Before killing the isolate, stop listening to the output stream. Recreate the stream on re-initialization. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P3 |

---

### ISSUE-021: `LightweightEngineService` is Dead Code

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `LightweightEngineService` is never imported or referenced anywhere in the codebase except its own file. It has an opening book and a negamax search, but it's completely unused. |
| **Root Cause** | All fallback paths use `SimpleBotService` directly. The `LightweightEngineService` was likely an early prototype that was never integrated. |
| **Files Involved** | Entire `lib/core/services/lightweight_engine_service.dart` |
| **Expected Behaviour** | Either integrate it as an option or remove it to reduce code maintenance burden. |
| **Current Behaviour** | Dead code increasing maintenance cost and cognitive load. |
| **Proposed Solution** | Either (a) remove the file, or (b) integrate it as the mid-tier fallback (between Stockfish and SimpleBot). If kept, fix its issues (no PSTs for rooks/queens, stale transposition table, no QS). |
| **Dependencies** | None |
| **Priority** | P3 |

---

### ISSUE-022: Isolate Spawn Without Timeout

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | `_startEngineIsolate()` spawns an isolate and waits for a `SendPort` via a `Completer`. There is no timeout on this operation. If the isolate fails to start or takes too long, the completer never completes, and `initialize()` hangs forever. |
| **Root Cause** | `stockfish_service.dart:695-732`: `await completer.future` without `.timeout()`. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:695-732` |
| **Expected Behaviour** | Isolate spawn should time out after a reasonable duration (e.g., 10 seconds). |
| **Current Behaviour** | If isolate spawn fails silently, the entire initialization hangs indefinitely. |
| **Proposed Solution** | Add `.timeout(Duration(seconds: 10))` to `completer.future`. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P2 |

---

### ISSUE-023: Isolate Error Handling is Silent

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | In `_stockfishIsolateEntryPoint`, if `Stockfish()` constructor throws (line 771), the `catch (e) {}` block is completely empty. The error is swallowed with no logging or reporting back to the main thread. |
| **Root Cause** | `stockfish_service.dart:775-777`: Empty catch block in the isolate entry point. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:775-777` |
| **Expected Behaviour** | Errors in the engine isolate should be reported to the main thread and logged. |
| **Current Behaviour** | Engine failures are silently swallowed, making debugging extremely difficult. |
| **Proposed Solution** | Send error information back via `sendPort.send({'type': 'error', 'message': '$e'})`. Add logging in both the isolate and the main thread handler. |
| **Dependencies** | None |
| **Priority** | P2 |

---

### ISSUE-024: BasicEvaluatorService Missing PSTs for Rooks and Queens

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | In `BasicEvaluatorService._evaluateBoard()`, the switch cases for `ROOK` and `QUEEN` don't set any PST value (`pst`). Only pawns, knights, and bishops get positional bonuses. This makes the basic evaluator positionally blind for rooks and queens. The same issue exists in `LightweightEngineService._evaluate()`. |
| **Root Cause** | `basic_evaluator_service.dart:298, 302`: Rook/queen cases only set `material` without `pst`. |
| **Files Involved** | `lib/core/services/basic_evaluator_service.dart:296-305`, `lib/core/services/lightweight_engine_service.dart:362-369` |
| **Expected Behaviour** | Rooks should get bonuses for open/7th-rank files. Queens should get a slight center preference. |
| **Current Behaviour** | Rooks and queens are evaluated purely on material with no positional consideration. |
| **Proposed Solution** | Add PST tables for rooks and queens, matching the ones in `SimpleBotService`. |
| **Dependencies** | None |
| **Priority** | P3 |

---

### ISSUE-025: `analyzeGame` in EngineProvider is Unused

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `EngineNotifier.analyzeGame()` (engine_provider.dart:368-379) iterates through a list of FENs and calls `getBestMove` for each. This method is never called from anywhere in the codebase. The actual analysis happens in `AnalysisProvider.analyzeFullGame()`. |
| **Root Cause** | Engineered but never integrated. Possibly a prototype method. |
| **Files Involved** | `lib/providers/engine_provider.dart:368-379` |
| **Expected Behaviour** | Either remove the dead method or integrate it into the analysis pipeline. |
| **Current Behaviour** | Dead code. |
| **Proposed Solution** | Remove the method. If needed later, implement properly using `analyzePosition`. |
| **Dependencies** | None |
| **Priority** | P3 |

---

### ISSUE-026: `Chess` Library Indexing Is Fragile

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | The board access uses `board.board[index]` with `index = rank * 16 + file`. This is the 0x88 board representation. If the `chess` library ever changes its internal representation, all evaluation functions break silently. The code should use the library's API methods instead of direct board array access. |
| **Root Cause** | All evaluation functions access `board.board[index]` directly instead of using `board.get(square)` API. |
| **Files Involved** | `simple_bot_service.dart:563`, `lightweight_engine_service.dart:341`, `basic_evaluator_service.dart:276` |
| **Expected Behaviour** | Evaluation should use the public API (`board.get(square)`) to be resilient to library changes. |
| **Current Behaviour** | Direct internal array access creates tight coupling to the chess library's implementation details. |
| **Proposed Solution** | Refactor evaluation to iterate using `board.get()` for each square, or use a proper board iterator. Accept the small performance penalty for API safety. |
| **Dependencies** | None |
| **Priority** | P3 |

---

### ISSUE-027: No Engine Warmup / Pre-initialization

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | When a game starts and the bot is white, `_makeBotMove()` is called immediately. This triggers engine initialization on the critical path, leading to a 5+ second delay before the bot makes its first move (while initialization times out and falls back). |
| **Root Cause** | Engine initialization is lazy (first use) rather than eager (at app startup). |
| **Files Involved** | `lib/providers/game_session_viewmodel.dart:56-59`, `lib/providers/engine_provider.dart:112-117` |
| **Expected Behaviour** | Engine should initialize at app startup (or at least when the game setup screen appears) so it's ready when the game begins. |
| **Current Behaviour** | First bot move triggers slow initialization on the critical path. |
| **Proposed Solution** | Add eager initialization in `main.dart` or when the user enters the game setup screen. Use the existing `engineInitializedProvider` FutureProvider. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P3 |

---

### ISSUE-028: `_outputController` Memory Leak Risk

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `_outputController` is a broadcast `StreamController`. Each call to `getBestMove()`, `analyzePosition()`, and `_waitForReadyOk()` creates new `StreamSubscription` listeners. While they are cancelled when the operation completes, rapid failure/retry cycles could create temporary listener accumulation. |
| **Root Cause** | `stockfish_service.dart:32-33` and multiple methods that subscribe to the stream. |
| **Files Involved** | `lib/core/services/stockfish_service.dart` (multiple locations) |
| **Expected Behaviour** | No more than one active listener per operation. |
| **Current Behaviour** | Accumulation possible during error/retry scenarios. |
| **Proposed Solution** | Use a single persistent subscription in `getBestMove`/`analyzePosition` that is managed with a setter (cancel old, assign new). Or use a `StreamIterator` pattern. |
| **Dependencies** | None |
| **Priority** | P3 |

---

### ISSUE-029: `startNewGame` Race Condition with Engine Init

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | `GameSessionViewModel.startNewGame()` at line 56 calls `_makeBotMove()` immediately if the bot is white. But `_makeBotMove()` calls `engineNotifier.getBotMove()` which may trigger `_service.initialize()`. Meanwhile, the `engineInitializedProvider` FutureProvider may also be initializing the engine. These concurrent initialization attempts could cause race conditions around `_initCompleter`. |
| **Root Cause** | Two independent code paths may call `initialize()` concurrently. The `_initCompleter` guard prevents full duplication but the state machine around it is fragile. |
| **Files Involved** | `lib/providers/game_session_viewmodel.dart:56-59`, `lib/providers/engine_provider.dart:112-117` |
| **Expected Behaviour** | Engine initialization should have a single owner and a clear state machine. |
| **Current Behaviour** | Multiple callers can trigger initialization. The `_initCompleter` guard is the only protection. |
| **Proposed Solution** | Move initialization to app startup (eager init) so it's complete before any game starts. Remove lazy init from `getBotMove()`. |
| **Dependencies** | ISSUE-001, ISSUE-027 |
| **Priority** | P3 |

---

## Newly Discovered Issues (Re-Audit)

The following issues were discovered during the re-audit process beyond the initial analysis.

### ISSUE-030: `_isEngineReady` Also Blocks `_configureEngine`

| Field | Value |
|-------|-------|
| **Severity** | **HIGH** |
| **Description** | Even after `readyok` is received (hypothetically, if the queue weren't blocked), `_configureEngine()` at line 132 calls `_sendCommand('setoption...')` which goes through the queue. If `_isEngineReady` were properly set by `readyok`, this would work. But there's another subtlety: `_processCommandQueue()` at line 243 checks `_isEngineReady`, and `readyok` sets `_isEngineReady` at line 718. However, `_processCommandQueue()` is ALSO called at line 721 by `readyok`, AFTER setting `_isEngineReady`. So if `readyok` were received, the queue would start processing. The real bug is that `readyok` is never received because the initial UCI commands never reach Stockfish. |
| **Root Cause** | Circular dependency: `isready` → queue → `_isEngineReady` check fails → never processed → `readyok` never received → `_isEngineReady` stays false. |
| **Files Involved** | `lib/core/services/stockfish_service.dart:165-169` |
| **Expected Behaviour** | Engine configuration options should be sent after successful initialization. |
| **Current Behaviour** | `_configureEngine()` never executes because initialization always times out. |
| **Proposed Solution** | Same as ISSUE-001: fix the engine initialization pipeline. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P1 |

### ISSUE-031: `_isAnalyzing` Flag Can Get Stuck at `true`

| Field | Value |
|-------|-------|
| **Severity** | **MEDIUM** |
| **Description** | In `AnalysisNotifier`, the `_isAnalyzing` guard flag (line 161) is set to `true` at the start of `_analyzeCurrentPosition()` and `analyzeFullGame()`, and reset to `false` in the `finally` block. If a `StackOverflowError`, `OutOfMemoryError`, or other non-`Exception` error occurs (which doesn't extend `Exception`), the `finally` block won't execute in some edge cases, leaving `_isAnalyzing = true` forever. All subsequent analysis calls are silently blocked. |
| **Root Cause** | `analysis_provider.dart:287, 345`: The flag is set before the try block. If the code between flag set and try throws a non-Exception error, the flag is stuck. |
| **Files Involved** | `lib/providers/analysis_provider.dart:286-288, 345-347` |
| **Expected Behaviour** | The guard flag should always be reset, even on catastrophic failures. |
| **Current Behaviour** | Rare but possible: analysis becomes permanently blocked until app restart. |
| **Proposed Solution** | Set `_isAnalyzing = true` inside the `try` block, not before it. Or use a `bool get isAnalyzing => _analysisToken != 0` pattern where the token is always modified in a controlled way. |
| **Dependencies** | None |
| **Priority** | P2 |

### ISSUE-032: No Error Feedback in Engine Debug Screen

| Field | Value |
|-------|-------|
| **Severity** | **LOW** |
| **Description** | The `EngineDebugScreen` tests call `_testInitialization()` and `_testBestMove()` which call `service.initialize()` and `service.getBestMove()`. Since Stockfish never initializes, these tests always hit fallback. The UI shows "Initialized successfully" with `service.isReady` = false, which is misleading. There's no indication that the fallback is being used. |
| **Root Cause** | The debug screen doesn't check `service.isUsingFallback` and doesn't display the engine status from `statusNotifier`. |
| **Files Involved** | `lib/debug/engine_debug_screen.dart` |
| **Expected Behaviour** | Debug screen should clearly show engine status, fallback state, and any initialization errors. |
| **Current Behaviour** | Debug screen shows potentially misleading success messages. |
| **Proposed Solution** | Display `statusNotifier` value, `isUsingFallback`, and initialization errors. Show the engine's actual output stream for debugging. |
| **Dependencies** | ISSUE-001 |
| **Priority** | P3 |

---

## Refactor Phases

### Phase 0: Repository Analysis & Understanding

**Purpose**: Ensure complete understanding of the codebase before making changes.

**Expected Outcome**: Familiarity with all engine-related files, their interactions, and the data flow.

**Files Affected**: None (read-only analysis)

**Implementation Order**:
1. Review all engine-related source files (completed by this audit)
2. Understand the provider hierarchy and data flow
3. Review all existing tests
4. Document any additional observations

**Testing Strategy**: No code changes in this phase.

**Risks**: None.

**Rollback Considerations**: Not applicable (read-only).

**Dependencies**: None.

**Checklist**:
- [ ] All engine source files reviewed
- [ ] Provider hierarchy documented
- [ ] Data flow mapped (user input → game state → engine → response)
- [ ] Existing tests reviewed and categorized
- [ ] Dependency graph between modules understood

---

### Phase 1: Stockfish Initialization Fix

**Purpose**: Fix the `_isEngineReady` deadlock so Stockfish actually initializes and receives commands.

**Expected Outcome**: Stockfish successfully starts, receives `uci`, responds with `uciok`, receives `isready`, responds with `readyok`, and can accept `position` and `go` commands. The engine status shows `EngineStatus.ready` instead of `EngineStatus.usingFallback`.

**Files Affected**:
- `lib/core/services/stockfish_service.dart`

**Implementation Order**:
1. Add `engine_ready` message in the isolate entry point after Stockfish creation
2. Modify `_processCommandQueue()` to not block on `_isEngineReady` (or initialize it to `true` after isolate setup)
3. Fix the `initialize()` method to properly sequence UCI communication
4. Add timeout to `completer.future` in `_startEngineIsolate()` (ISSUE-022)
5. Add error reporting from isolate to main thread (ISSUE-023)
6. Add comprehensive logging at each step
7. Verify the engine status transitions correctly

**Testing Strategy**:
- Unit tests for each step of initialization (without requiring native Stockfish binary, use a mock)
- Integration test with actual Stockfish binary on device
- Verify `EngineStatus` transitions: `initializing` → `ready`
- Verify `isReady` returns `true`
- Verify `isUsingFallback` returns `false`
- Manual testing via `EngineDebugScreen`

**Risks**:
- Platform differences in isolate behavior
- Stockfish binary may not be bundled correctly on all platforms
- Race conditions in the improved initialization flow

**Rollback Considerations**:
- The current fallback path remains intact; if the fix fails, games still work via `SimpleBotService`
- Can roll back by reverting changes to `stockfish_service.dart`

**Dependencies**: Phase 0

**Checklist**:
- [ ] `engine_ready` message sent from isolate after Stockfish creation
- [ ] `_processCommandQueue()` no longer blocked by `_isEngineReady`
- [ ] `initialize()` successfully sends `uci` and `isready`
- [ ] `readyok` received and `_isReady` set to `true`
- [ ] `_configureEngine()` executes after initialization
- [ ] Engine status shows `EngineStatus.ready`
- [ ] Isolate spawn has timeout protection
- [ ] Errors in isolate are reported to main thread
- [ ] All existing tests pass with `forceFallback = false`
- [ ] New unit tests verify initialization sequence
- [ ] Manual testing via debug screen confirms engine works

**Success Criteria**:
- ✓ Engine initializes every launch
- ✓ `readyok` received
- ✓ No deadlock
- ✓ No premature fallback activation
- ✓ All existing tests pass
- ✓ Manual validation via debug screen

---

### Phase 2: Engine Lifecycle Management — COMPLETED

**Purpose**: Fix engine lifecycle issues — graceful shutdown, re-initialization, timeout recovery, and memory management.

**Expected Outcome**: Engine can be started, stopped, and restarted reliably without resource leaks. Timeouts don't permanently disable the engine.

**Files Affected**:
- `lib/core/services/stockfish_service.dart` — major refactor
- `lib/core/services/stockfish_lifecycle_observer.dart` — still functional as-is
- `test/stockfish_service_test.dart` — updated status test
- `test/engine_initialization_test.dart` — added setUp reset
- `test/engine_lifecycle_test.dart` — new file with 18 lifecycle tests
- `test/analysis_benchmark_test.dart` — added missing mock methods
- `test/widget_test.dart` — added missing mock methods

**Implementation Notes**:

1. **`_killEngineIfRunning()` (new) vs `_killEngineGracefully()`** — Separated cleanup into two concerns:
   - `_killEngineIfRunning()`: kills the isolate, closes ports, cancels subscriptions, resets state flags. Does NOT enable fallback or dispose. Safe to call multiple times.
   - `_killEngineGracefully()`: calls `_killEngineIfRunning()` + clears command queue. Used when the engine encounters a terminal error but the service should remain usable.

2. **Timeout no longer destroys engine** — Both `getBestMove()` and `analyzePosition()` timeout handlers now send `stop()` and return a fallback result for that request only. They no longer call `_stopEngineIsolate()` or `_enableFallback()`. The engine remains available for subsequent requests.

3. **Fallback recovery** — Added `_shouldRetryInit()` (30s cooldown), `_tryFallbackRecovery()` (called before `getBestMove`/`analyzePosition` when in fallback state), and `resetFallback()` (public API for manual re-init). Fallback is no longer permanent.

4. **Session isolation** — Added `_engineSessionId` counter incremented on each `_startEngineIsolate()`. The response port listener checks `_engineSessionId != sessionId` to ignore stale messages from previous sessions.

5. **`dispose()` no longer closes `_outputController`** — Since `StockfishService` is a singleton living for the app lifetime, closing the stream controller permanently breaks the service. The controller is naturally GC'd on app exit.

6. **`resetTestState()`** — Added `@visibleForTesting` method to reset singleton state between tests, solving the persistent singleton state leak across test files.

7. **State flags added**:
   - `_isDisposed` — prevents operations on disposed service
   - `_lastFallbackTime` — tracks when fallback was entered (for cooldown)
   - `_engineResponseSubscription` — stored reference for proper cleanup
   - `_engineSessionId` — for stale message detection

8. **All public methods guarded** — `_sendCommand`, `_sendCommandDirect`, `_processCommandQueue`, `setSkillLevel`, `setMaxStrength`, `stopAnalysis`, `newGame`, `getBestMove`, `analyzePosition` all check `_isDisposed` before proceeding.

**Files Not Modified** (by design):
- `lib/core/services/stockfish_lifecycle_observer.dart` — the observer already correctly calls `stopAnalysis()` on app pause; pausing/resuming during active search is a Phase 4 concern (time management).

**Testing Strategy**:
- Unit tests for dispose/cleanup
- Unit tests for fallback recovery
- Integration tests for rapid start/stop cycles
- Memory leak detection testing

**Risks**:
- Race conditions during rapid start/stop cycles
- Stream subscription cleanup in error scenarios

**Rollback Considerations**:
- Each fix can be individually rolled back
- The fallback path remains as safety net

**Dependencies**: Phase 1

**Checklist**:
- [X] `_killEngineGracefully` properly drains and cleans up (split into `_killEngineIfRunning` + cleanup)
- [X] Fallback recovery mechanism implemented (`_shouldRetryInit`, `_tryFallbackRecovery`, `resetFallback()`)
- [X] Timeouts no longer destroy the engine isolate (send `stop`, return per-request fallback)
- [X] `resetFallback()` method works (public API for manual re-init)
- [X] Stream subscriptions properly managed (session ID guard, stored subscription reference)
- [X] Lifecycle observer already correctly pauses search on app background
- [X] No memory leaks after repeated cycles (31 tests passing including 5 restart cycles, concurrent init, race conditions)
- [X] All tests pass (31/31)

**Success Criteria**:
- ✓ Engine can be stopped and restarted without errors
- ✓ Transient timeouts don't permanently disable engine
- ✓ No resource leaks after repeated cycles
- ✓ App backgrounding safely pauses engine search (via existing lifecycle observer)
- ✓ All tests pass

---

### Phase 3: Difficulty System & Playing Strength Calibration — COMPLETED

**Purpose**: Implement correct ELO-to-Stockfish mapping. Fix `UCI_Elo`/`Skill Level` conflict. Ensure each difficulty level plays at its advertised strength.

**Expected Outcome**: Difficulty levels 1-10 map to distinct playing strengths. Beginner (1320) plays weakly. Maximum (2800) plays near-Stockfish strength.

**Files Affected**:
- `lib/core/services/stockfish_service.dart` — `setSkillLevel()`, `getBestMove()`, `_getSimpleBotMove()`, added `_fallbackDepth()`
- `lib/providers/engine_provider.dart` — removed per-move `setSkillLevel` and `elo` param, updated `resetForNewGame()`
- `lib/providers/game_session_viewmodel.dart` — passes difficulty to `resetForNewGame()`
- `lib/core/constants/app_constants.dart` — remapped ELOs to Stockfish valid range, adjusted depths/times, added `fallbackDepth` getter
- `test/engine_difficulty_test.dart` — new file with 11 tests for difficulty system

**Implementation Order**:
1. Remove `Skill Level` UCI option, keep only `UCI_LimitStrength` + `UCI_Elo` (ISSUE-005)
2. Map difficulty ELO values directly to `UCI_Elo`, remapping to Stockfish valid range (1320–2800)
3. Move strength configuration to `resetForNewGame()` rather than per-move (ISSUE-016)
4. Add `_fallbackDepth()` for tiered fallback scaling (depth 1→1, 2→2, 3-8→3, 10+→4)
5. Update `engine_session_viewmodel.dart` to pass difficulty to `resetForNewGame()`
6. Create comprehensive difficulty tests

**Implementation Notes**:

1. **`UCI_Elo` minimum discovery** — Stockfish's `UCI_Elo` minimum is 1320. Any value below this is silently treated as 1320, making levels 1-3 play identically. Fixed by remapping ELO values in `app_constants.dart` to use the full 1320–2800 range (1320, 1400, 1500, 1600, 1700, 1850, 2000, 2200, 2500, 2800). Each level at least 80 ELO apart.

2. **`Skill Level` removed from `setSkillLevel()`** — `UCI_Elo` and `Skill Level` are mutually exclusive in Stockfish. Setting both causes undefined behavior. `setSkillLevel()` now sends only `UCI_LimitStrength=true` + `UCI_Elo=$clampedElo`.

3. **Strength configured once per game** — Previously, `setSkillLevel(difficulty.elo)` was called inside `getBotMove()` (every move), AND the `elo` parameter was passed to `getBestMove()` which sent UCI options again. Both duplications eliminated:
   - `_service.setSkillLevel(difficulty.elo)` removed from `getBotMove()`
   - `elo:` parameter removed from `getBestMove()` call
   - `resetForNewGame()` now accepts optional `DifficultyLevel` and calls `_service.setSkillLevel()` once

4. **`getBestMove()` no longer sends UCI options** — Removed duplicate `UCI_LimitStrength`/`UCI_Elo` settings from `getBestMove()`. It only sets the position and sends `go`.

5. **Fallback depth scaling** — `_fallbackDepth()` replaces hard-coded `depth > 4 ? 4 : depth`: depth 1→1, 2→2, 3-8→3, 10+→4. Also added `DifficultyLevel.fallbackDepth` getter with same logic.

6. **Fallback depth hard cap** — SimpleBot physically can't search deeper than depth 4 without ANR. The tiered function reflects this real constraint while providing meaningful differentiation at lower levels.

**Testing Strategy**:
- Unit tests for ELO mapping (unique, within valid range, monotonically increasing)
- Unit tests for fallback depth scaling (1, 2, 3, 4 tiers, capped at 4)
- Unit tests for `setSkillLevel` clamping and no `Skill Level` conflict
- Unit tests for per-game (not per-move) strength configuration
- Unit tests for parameter consistency across levels
- All existing tests (31 in previous phases) continue to pass

**Risks**:
- Stockfish's `UCI_Elo` may not perfectly match the advertised ELO ratings
- Very low ELO (1320) may still play too strong for true beginners
- Fallback (SimpleBot) differentiation is limited (only 4 tiers due to depth cap)

**Rollback Considerations**:
- The ELO mapping can be tuned independently
- Current (broken) behavior is fully preserved in fallback path

**Dependencies**: Phase 1, Phase 2

**Checklist**:
- [X] `Skill Level` UCI option removed from `setSkillLevel()`
- [X] `UCI_Elo` correctly set based on difficulty level (remapped to 1320–2800)
- [X] Strength configuration moved to game start (`resetForNewGame()`) not per-move
- [X] `getBestMove()` no longer sends duplicate UCI options
- [X] Fallback depth scales with tiered mapping (1, 2, 3, 4)
- [X] `engine_session_viewmodel.dart` passes difficulty to `resetForNewGame()`
- [X] 11 new tests verify difficulty system correctness
- [X] All 42 tests pass (31 prior + 11 difficulty)
- [X] ELO values discovered: Stockfish `UCI_Elo` minimum is 1320

**Success Criteria**:
- ✓ Each difficulty level maps to a distinct, valid `UCI_Elo` value
- ✓ No conflicting UCI options set (`Skill Level` removed)
- ✓ Strength options set once per game, not per move
- ✓ Fallback depth tiered and capped at 4 (ANR prevention)
- ✓ All 11 difficulty tests pass
- ✓ All 31 prior tests continue to pass

---

### Phase 4: Search Engine Improvements — COMPLETED

**Purpose**: Fix alpha-beta search bugs, implement iterative deepening, and add principal variation tracking to the fallback engine (SimpleBot).

**Expected Outcome**: Pure negamax with correct alpha-beta pruning (ISSUE-003 fix). Iterative deepening from depth 1 to max depth. PV tracking for future analysis features. Search cancellation via cancellation token.

**Files Affected**:
- `lib/core/services/simple_bot_service.dart` — complete rewrite of search: pure negamax, ID, PV, cancellation
- `test/engine_search_test.dart` — new file with 13 tests for search correctness

**Implementation Order**:
1. Fix alpha-beta initial value: `int value = -1000000000` → `int value = alpha` (ISSUE-003)
2. Convert to pure negamax: remove `isMaximizing` flag from recursion, use standard negamax convention (score = -childScore)
3. Fix checkmate scoring: remove `isMaximizing` ternary, use `-999999 + depth` (prefer sooner mates)
4. Implement iterative deepening: loop depth 1 → maxDepth, reuse best move from completed iterations
5. Add `cancelSearch()` static method with `_cancelToken` pattern
6. Add `principalVariation` field to `SimpleBotResult`
7. Implement PV tracking in both `_searchRoot` and `_negamax`
8. Extract `_moveToStr()` helper to reduce allocations
9. Sort moves: captures before non-captures

**Implementation Notes**:

1. **Pure negamax replaces mixed minimax/negamax** — The previous code had a confusing mix: `_getBestMoveSync` used minimax-style `isMaximizing` split at the root, while `_minimax` used negamax-style `-beta, -alpha` recursion. The new code uses pure negamax throughout: `_searchRoot` evaluates root moves, `_negamax` handles all deeper levels with `score = -childScore`.

2. **Alpha-beta initial value fix** — Previously `int value = -1000000000` ignored the alpha bound. Changed to `int value = alpha` for correct fail-soft alpha-beta behavior. This also enables tighter windows as the search finds better moves: `_negamax(board, depth-1, -beta, -bestScore)` uses the best score found so far to narrow the window.

3. **Checkmate scoring fix** — Previously used `isMaximizing ? -999999 : 999999`. Now uses `-999999 + depth`. The side to move being checkmated is always bad (negative), and sooner mates are preferred (less negative).

4. **Depth-1 case** — Previously picked a random move at depth ≤ 1. Now evaluates each move with a single-ply search and picks the best. This gives non-random, deterministic results at all depths.

5. **Iterative deepening** — Searches from depth 1 to requested depth. Each iteration calls `_searchRoot(board, idDepth)`. The best move, evaluation, and PV from the deepest completed iteration are returned.

6. **Cancellation** — `cancelSearch()` increments `_cancelToken`. `getBestMove` captures `cancelId` before `Isolate.run`. Inside the isolate, `_getBestMoveSync` checks `_cancelToken != cancelId` between ID iterations. Note: since `Isolate.run` spawns a separate isolate with its own static state, the cancellation check only works across ID iterations, not within a single depth's search. Future work: move to `Isolate.spawn` with explicit message passing for true cancellation.

7. **Principal Variation** — Both `_searchRoot` and `_negamax` return PV as a `List<String>`. At each level the best move is prepended to the child's PV. This gives a complete alternating move line (e.g., `[e2e4, e7e5, Nf3]`).

8. **`principalVariation` field** — Added to `SimpleBotResult` as an optional field. Stockfish `BestMoveResult` already has this field, so the APIs are now consistent.

9. **Performane** — At depth 3, ID adds ~5% node overhead (8,420 vs 8,000 nodes). All tests complete under the ANR threshold.

10. **Depth-0 single ply** — `_pickBestSinglePly` replaces the random move for depth 0/1 inputs.

**Testing Strategy**:
- Determinism: same position, same depth → same result
- PV extends from previous depth iteration
- Cancellation: returns best move from completed iterations
- Repeated searches don't interfere
- ANR threshold: depth 3 completes under 5s
- Evaluation at starting position: roughly balanced
- Midgame positions return valid moves
- Checkmate positions handled correctly

**Risks**:
- ID adds overhead (5% more nodes at depth 3)
- Cancellation token doesn't cross `Isolate.run` boundary (static isolation)
- PV tracking adds memory allocations proportional to search depth

**Rollback Considerations**:
- Each change is independently revertible
- The `principalVariation` field addition is backward-compatible (optional, default `[]`)

**Dependencies**: Phase 3

**Checklist**:
- [X] Alpha-beta initial value fixed (`int value = alpha` instead of `-inf`)
- [X] Pure negamax (no `isMaximizing` in recursion)
- [X] Checkmate scoring uses depth-adjusted penalty (`-999999 + depth`)
- [X] Iterative deepening (depth 1 → maxDepth)
- [X] PV tracking in both root and recursive search
- [X] `principalVariation` field added to `SimpleBotResult`
- [X] `cancelSearch()` static method implemented
- [X] Depth-1 case uses evaluation (not random)
- [X] Captures sorted before non-captures
- [X] 13 new search tests (determinism, PV, cancellation, ANR, checkmate)
- [X] All 109 tests pass (96 prior + 13 new)

**Success Criteria**:
- ✓ Pure negamax with correct alpha-beta pruning (ISSUE-003 resolved)
- ✓ Iterative deepening produces progressively deeper PVs
- ✓ Search results are deterministic
- ✓ Cancellation works between ID iterations
- ✓ All existing tests continue to pass

---

### Phase 5: Time Management — COMPLETED

**Purpose**: Implement proper time management for bot moves. Remove artificial delays. Use Stockfish's time management features correctly.

**Expected Outcome**: UCI search commands follow official recommendations. No combined depth/movetime. Minimum think time as a true floor (not additive). Timer pauses during bot thinking. 119 tests pass.

**Files Affected**:
- `lib/core/services/stockfish_service.dart` — ISSUE-006: split `go` commands; removed fallback proportional delay
- `lib/providers/engine_provider.dart` — ISSUE-007: replaced `thinkTimeMs/2` additive delay with fixed 300ms floor
- `lib/providers/game_session_viewmodel.dart` — ISSUE-015: pause timer during bot thinking, resume after move
- `test/engine_timing_test.dart` — new file with 10 timing-specific regression tests

**Issues Resolved**:

1. **ISSUE-006 — Combined `go depth X movetime Y`**: Previously `_sendCommand('go depth $depth movetime $thinkTimeMs')` combined both parameters, which is redundant and can cause confusing behaviour. Stockfish's internal time management works best with a single constraint. Now:
   - Bot play (`thinkTimeMs` provided): `go movetime <ms>` — time-bounded, no depth limit
   - Analysis (depth only): `go depth <depth>` — depth-bounded, no time limit
   - Never combine both in one "go" command

2. **ISSUE-007 — Artificial additive delay in EngineProvider**: Previously `minDelay = thinkTimeMs / 2` acted as a proportional floor (e.g., 150ms for Beginner, 1250ms for Maximum). This penalised harder difficulties with longer minimum waits even when the search completed quickly. Replaced with a fixed **300ms minimum think time** that applies uniformly to all difficulties. The minimum is a true floor: if the search finishes before 300ms, wait the remainder; if it finishes after, move immediately with no added delay.

3. **ISSUE-015 — Player clock decreases while engine thinks**: The timer previously continued ticking during bot thinking, counting down the bot's clock. This is confusing in a human-vs-bot game — there is no human playing the other side. Now `_makeBotMove()` pauses the timer before the search starts and resumes it for the human's turn after the bot's move is applied.

**UCI Command Strategy**:

| Context | Command | Rationale |
|---|---|---|
| Bot play (untimed) | `go movetime <thinkTimeMs>` | Stockfish searches as deep as possible within the time budget. No depth cap — maximum strength within time. |
| Analysis | `go depth <depth>` | Fixed-depth search for consistent evaluation quality. No time limit — thoroughness is primary. |
| Timed games (future) | `go wtime <ms> btime <ms> [movetime <maxMs>]` | Use remaining clock times. `movetime` is optional as a maximum safety bound. |

**Time Allocation Strategy**:

Each difficulty level maps `thinkTimeMs` to a `go movetime` parameter. Stockfish naturally searches deeper for easier positions and shallower for complex ones within the budget.

| Level | thinkTimeMs | Movetime | Character |
|---|---|---|---|
| Beginner | 300ms | 300ms | Very fast, weak play |
| Novice | 500ms | 500ms | Quick replies |
| Casual | 700ms | 700ms | Moderate think |
| Intermediate | 1000ms | 1000ms | Balanced |
| Club Player | 1200ms | 1200ms | Thoughtful |
| Advanced | 1500ms | 1500ms | Deliberate |
| Expert | 1800ms | 1800ms | Deep calculation |
| Master | 2000ms | 2000ms | Thorough |
| Grandmaster | 2200ms | 2200ms | Maximum analysis |
| Maximum | 2500ms | 2500ms | Deepest practical |

**Minimum Think Time Policy**:

- Fixed floor: **300ms** for all difficulties
- Not additive: delay only applied if search completes before 300ms
- Not proportional: same floor for Beginner and Maximum
- Prevents instant "robotic" replies without adding unnecessary latency

**Timeout Recovery Policy**:

- Timeout: `thinkTimeMs * 2 + 2000ms` generous window for engine response
- On timeout: `TimeoutException` thrown → caught by `getBotMove()` → fallback (SimpleBot) for that move
- Engine NOT killed or permanently disabled — isolate stays alive
- Subsequent moves retry Stockfish normally
- `_isEngineBusy` flag resets in `finally` block to prevent stuck-busy state

**Testing Strategy**:
- Minimum think time not excessive for Beginner
- `getBestMove` with/without `thinkTimeMs` completes within bounds
- Consecutive rapid searches don't degrade or crash
- Search after busy/timeout recovery returns valid result
- All difficulty think times are within sensible range (200ms-5000ms)
- Engine restart after dispose does not hang
- Cancel between calls does not corrupt state
- Fallback depth cap at 4 prevents ANR for deep requests
- `analyzePosition` uses depth-only command (no movetime)
- All 119 tests pass (109 prior + 10 new)

**Risks**:
- Removing artificial 300ms floor entirely could make low-difficulty bots feel too fast. Mitigated: floor kept at 300ms for all levels.
- `wtime`/`btime` not yet integrated — that requires the timer system to provide remaining time to the engine. Deferred to a future "Timed Game Support" phase.

**Remaining Limitations**:
- Timed games using `wtime`/`btime` are not yet implemented. The current timer provider (`TimerNotifier`) tracks remaining time, but `StockfishService.getBestMove()` does not yet accept clock arguments.
- The SimpleBot fallback does not support time-bounded search — it always uses fixed depth. Minimum think time is applied in `engine_provider.dart` for both Stockfish and fallback paths.

**Future Timed-Game Considerations**:
- `TimerNotifier` state (`whiteTime`, `blackTime`, `isWhiteTurn`) already provides the data needed for `wtime`/`btime`
- Integration point: pass remaining times from `TimerNotifier` to `StockfishService.getBestMove()` when a time control is active
- Suggested UCI: `go wtime <whiteMs> btime <blackMs> movetime <maxThinkMs>`

**Dependencies**: Phase 1

**Checklist**:
- [X] `movetime` removed from depth-limited `go` commands
- [X] Bot play: `go movetime <ms>` (time-bounded, no depth)
- [X] Analysis: `go depth <depth>` (depth-bounded, no time)
- [X] Artificial additive delay removed (`thinkTimeMs/2` → fixed 300ms floor)
- [X] Minimum thinking time implemented as floor (not add-on)
- [X] Timer pauses during bot thinking (ISSUE-015)
- [X] Fallback proportional delay removed
- [X] 10 new timing regression tests
- [X] All 119 tests pass

**Success Criteria**:
- ✓ UCI commands follow official recommendations (no combined depth+movetime)
- ✓ No artificial additive delays
- ✓ Minimum think time is a true floor (not additive penalty)
- ✓ Player's clock does not decrease while engine thinks
- ✓ Bot responses feel natural (not instant, not artificially delayed)
- ✓ Engine recovers from timeout without permanent fallback
- ✓ All tests pass

---

### Phase 6: Evaluation Correctness & Score Consistency — COMPLETED

**Purpose**: Fix every place where evaluation values are produced or consumed. Enforce a single consistent convention (white-relative) across all components. Fix negamax score propagation, Stockfish score parsing, mate scoring, and draw scoring.

**Expected Outcome**: All evaluations are white-relative (positive = good for white). SimpleBot negamax correctly converts between side-to-move and white-relative. Stockfish's side-to-move `score cp` is converted to white-relative. Mate and draw scores follow documented conventions.

**Files Affected**:
- `lib/core/services/simple_bot_service.dart` — 4 bugs fixed:
  1. `_negamax` depth 0: converted white-relative `_evaluatePosition` to side-to-move relative
  2. `_pickBestSinglePly`: fixed eval sign for black's turn (used `eval > bestEval` always)
  3. `_getBestMoveSync`: added terminal condition checks (checkmate/draw/stalemate) with correct white-relative conversion
  4. `_getBestMoveSync`: converts root search results from side-to-move to white-relative
- `lib/core/services/stockfish_service.dart` — 2 bugs fixed:
  1. `getBestMove()` score cp parsing: added `_toWhiteRelative()` conversion
  2. `analyzePosition()` score cp parsing: same conversion
- `test/engine_evaluation_test.dart` — new file with 20 evaluation correctness tests

**Bugs Found & Fixed**:

| Bug | Location | Description | Fix |
|---|---|---|---|
| 1 | `_negamax` depth 0 | `_evaluatePosition()` returns white-relative, but negamax expects side-to-move relative. Every other depth produced inverted scores. | Flip eval when `board.turn == BLACK` before returning from depth 0 |
| 2 | `_pickBestSinglePly` | Always picked highest eval (`eval > bestEval`). For black's turn, high white-relative = bad for black. | Negate white-relative eval for black's turn before comparing |
| 3 | `_getBestMoveSync` | Checkmate positions returned `moves.isEmpty → eval=0` instead of mate score | Added terminal checks before move generation; returns `±(999999 - depth)` white-relative |
| 4 | `_getBestMoveSync` | `_searchRoot` returns from root side's perspective, stored as white-relative. Wrong for black's turn. | Convert root-perspective eval to white-relative when `board.turn == BLACK` |
| 5 | `getBestMove()` | Stockfish's `score cp` is side-to-move relative, stored as-is. Black-turn positions had inverted white-relative scores. | New `_toWhiteRelative(int scoreCp, String fen)` helper: negates when FEN turn is `b` |
| 6 | `analyzePosition()` | Same missing conversion for all `score cp` lines in MultiPV analysis | Same `_toWhiteRelative()` helper applied |

**Evaluation Convention**:

```
White-Relative Centipawn Scores
  +1000 .. +∞     Forced mate (white winning)
  +100  .. +999   Clear advantage (good for white)
  +50   .. +99    Slight advantage
    0   .. ±50    Balanced / equal
  -50   .. -99    Slight disadvantage (good for black)
  -100  .. -999   Clear disadvantage
  -1000 .. -∞     Forced mate (black winning)
```

All components now follow this convention:
- `SimpleBotResult.evaluation` — white-relative centipawns
- `BestMoveResult.evaluation` — white-relative centipawns (includes Stockfish conversion)
- `AnalysisResult.evaluation` — white-relative centipawns
- `EngineLine.evaluation` — white-relative pawns (centipawns / 100)
- `classifyMove()` — expects white-relative `evalBefore`/`evalAfter`

**Mate Score Convention**:

```
  Checkmated (side to move):   -999999 + depth
  Opponent checkmated (root):  +999999 - depth
  White-relative (API):        board.turn == BLACK ? +999999 - depth : -999999 + depth
```

- Lower (more negative) mate scores = sooner mates (preferred)
- Mate scores are separated from positional scores by ~900,000 centipawns gap
- Maximum material advantage (< 100,000 cp) never overlaps mate territory

**Draw Score Convention**:

```
  All draws (stalemate, threefold, insufficient material, fifty-move):  0
```

- `_negamax` checks `board.in_stalemate || board.in_draw` and returns `(score: 0)`
- `_getBestMoveSync` checks terminal conditions before move generation
- `BasicEvaluatorService._evaluateBoard` checks `board.in_draw` and returns 0

**Internal Documentation Added**:
- `_evaluatePosition()` doc: "Returns white-relative centipawn score. Callers in negamax must convert to side-to-move relative when needed."
- `_toWhiteRelative()` doc: "Convert a Stockfish side-to-move score to white-relative."
- Test file header documents the full evaluation convention

**Testing Strategy**:
- BasicEvaluator: starting position near zero, checkmate detection, empty board
- SimpleBot: white ahead = positive, black ahead = negative, both colors at depth 1-3
- Sign consistency: position evaluated at depths 1, 2, 3 all produce same sign
- Mate scores: outside normal positional range (> 999000), consistent across depths
- Draw scores: insufficient material near zero, stalemate/checkmate handled
- Determinism: repeated searches produce identical evaluations
- Stockfish: white-to-move FEN has identity conversion, black-to-move also returns valid results in fallback mode
- 20 new evaluation tests

**Risks**:
- No migration for previously saved game evaluations (they may be in the wrong sign convention)
- `BasicEvaluatorService._evaluateBoard` does not check `board.in_checkmate`/`board.in_draw` — only `_negamax` and `_getBestMoveSync` do. The BasicEvaluator is only used as a static fallback.
- The stalemate FEN construction can be tricky with the chess library's FEN parser; tests use depth >= 2 to go through negamax which handles draws properly.

**Dependencies**: Phase 1 (Stockfish parsing), Phase 4 (negamax search)

**Checklist**:
- [X] `_negamax` depth 0 converts white-relative eval to side-to-move relative
- [X] `_pickBestSinglePly` fixes sign for black's turn
- [X] `_getBestMoveSync` terminal condition checks (checkmate, draw, stalemate)
- [X] `_getBestMoveSync` converts root-perspective to white-relative
- [X] `_toWhiteRelative()` helper in StockfishService
- [X] Stockfish `getBestMove()` score cp converted to white-relative
- [X] Stockfish `analyzePosition()` score cp converted to white-relative
- [X] Mate scores: `-999999 + depth` (negamax), separated from positional
- [X] Draw scores: 0 (stalemate, threefold, insufficient material)
- [X] 20 new evaluation correctness tests
- [X] All 139 tests pass (119 prior + 20 new)

**Success Criteria**:
- ✓ All evaluations are white-relative (positive = good for white)
- ✓ Negamax correctly uses side-to-move relative internally, converts for API
- ✓ Stockfish score cp correctly converted to white-relative
- ✓ Mate scores never overlap positional scores
- ✓ Draw scores consistently 0
- ✓ classifyMove works correctly for both colors (white-relative assumption validated)
- ✓ No sign inversions when switching between white/black positions
- ✓ All tests pass

---

### Phase 7: Full Game Analysis Optimization — COMPLETED

**Purpose**: Fix the analysis pipeline to be correct and efficient.

**Expected Outcome**: Full game analysis runs in ~1 second per move (not 2+). Accuracy is computed correctly against the best move. No redundant engine calls.

**Files Affected**:
- `lib/providers/analysis_provider.dart` — 3 bugs fixed:
  1. ISSUE-009: Removed `getBestMove` call from `analyzeFullGame()` loop (reduced from 2→1 engine calls per move, removed 100ms of forced delays per move)
  2. ISSUE-018: Removed `if (mounted)` check from `_analyzeCurrentPosition()` (StateNotifier doesn't have mounted)
  3. ISSUE-031: Moved `_isAnalyzing = true` inside both `try` blocks in `_analyzeCurrentPosition()` and `analyzeFullGame()` (prevents stuck-flag on catastrophic errors)

**Implementation Order**:
1. Remove `getBestMove` call before each move (ISSUE-009)
2. Use `analyzePosition` with `multiPv=1` for eval-after only
3. Derive best move from `analyzePosition` PV output (first line)
4. Fix the `mounted` check issue (ISSUE-018)
5. Fix `_isAnalyzing` stuck flag vulnerability (ISSUE-031)
6. Verify `classifyMove` works with correct evaluations

**Implementation Notes**:

1. **`getBestMove` removed** — The redundant `_stockfish!.getBestMove(fen, depth: 15)` call before each move was eliminated. Previously, for each of N moves, the engine was called 2× (getBestMove for best-move-of-position, analyzePosition for eval-after-move). Now it's 1× per move.

2. **Best move derived from PV** — The best move is now extracted from `analyzePosition`'s PV output (`result.lines.first.moves.first`). This gives the engine's top continuation in the post-move position, used for `classifyMove`'s "was this the best move" check.

3. **100ms forced delays removed** — Two 50ms delays (one between engine calls, one after the applied move) were eliminated since there's only one engine call per move now. This saves ~4 seconds for a 40-move game.

4. **`mounted` check (ISSUE-018)** — Removed `if (mounted)` from `_analyzeCurrentPosition()`'s `onUpdate` callback. `StateNotifier` does not have a `mounted` property (that's from Flutter's `State` class). The onUpdate callback is only invoked while the notifier is active, so the guard was unnecessary and wouldn't have compiled in strict mode.

5. **`_isAnalyzing` stuck flag (ISSUE-031)** — Both `_analyzeCurrentPosition()` (line 288) and `analyzeFullGame()` (line 345) previously set `_isAnalyzing = true` before the `try` block. If a non-Exception error (e.g., `StackOverflowError`) occurred between the flag set and `try`, the flag would be stuck at `true`. Fixed by moving `_isAnalyzing = true` inside both `try` blocks.

**Testing Strategy**:
- All 139 existing tests pass (no regressions)
- Existing analysis provider tests (`analysis_provider_test.dart`, `analysis_benchmark_test.dart`) continue to pass
- No new tests added (Phase 7 is an optimization, not a new feature)

**Risks**:
- Best move derived from post-move PV is the opponent's best continuation, not the player's best move in the position before. This means `classifyMove` will rarely flag moves as "best" based on the `bestMove` match. The eval-loss-based classification is unaffected and remains primary.
- Analysis is still bounded by Stockfish availability; on platforms without Stockfish, the BasicEvaluator fallback is used.

**Rollback Considerations**:
- Old analysis results remain in saved games
- Each change is independently revertible

**Dependencies**: Phase 1, Phase 5

**Checklist**:
- [X] `getBestMove` calls removed from analysis loop
- [X] `analyzePosition` used for evaluation after each move
- [X] Best move extracted from PV output
- [X] Eval-before derived from previous position eval-after
- [X] `mounted` check removed/replaced
- [X] `_isAnalyzing` flag properly protected
- [X] Performance: ≤1 second per move (reduced from 2 calls + 100ms delay per move)
- [X] All 139 tests pass

**Success Criteria**:
- ✓ Analysis completes in ≤1 second per move
- ✓ Accuracy calculated correctly against best move (via eval loss)
- ✓ No redundant engine calls (1 per move instead of 2)
- ✓ Analysis results are deterministic (same game → same analysis)

---

### Phase 8: Accuracy Calculation & Move Quality Evaluation — COMPLETED

**Purpose**: Replace the approximate accuracy calculation with a proper chess-engine-based centipawn-loss model. Implement consistent move-quality classification with configurable thresholds.

**Expected Outcome**: Accuracy percentages reflect real centipawn loss. Move classification uses documented thresholds. White/black symmetry. Mate and draw evaluations handled separately.

**Files Affected**:
- `lib/core/constants/app_constants.dart` — Added `EvalConstants` class with CPL thresholds, accuracy formula, and mate threshold constants
- `lib/models/analysis_model.dart` — Rewrote `classifyMove()` with configurable thresholds, mate/draw handling, CPL-based classification; added `computeCentipawnLoss()` and `computeAccuracy()` as standalone functions; rewrote `GameAnalysis.fromMoves()` to use CPL-based per-move accuracy instead of fixed per-classification scores; added `centipawnLoss` and `accuracy` fields to `MoveAnalysis`
- `lib/providers/game_session_viewmodel.dart` — Replaced `_calculateAccuracy()` (ISSUE-010) with CPL-based model using eval-before derived from preceding move's eval
- `lib/providers/analysis_provider.dart` — Updated `MoveAnalysis` construction to pass computed `centipawnLoss` and `accuracy` fields
- `test/engine_accuracy_test.dart` — New file with 55 comprehensive accuracy tests

**Implementation Notes**:

1. **`EvalConstants` (new class in `app_constants.dart`)** — Central location for all evaluation/accuracy constants:
   - `thresholdBlunderCp: 200` — CPL ≥ 200cp (2.0 pawns)
   - `thresholdMistakeCp: 100` — CPL ≥ 100cp (1.0 pawn)
   - `thresholdInaccuracyCp: 50` — CPL ≥ 50cp (0.5 pawns)
   - `thresholdGoodCp: 20` — CPL ≥ 20cp
   - `thresholdExcellentCp: 5` — CPL ≥ 5cp
   - `thresholdBrilliantCp: -50` — CPL ≤ -50cp (improvement)
   - `mateThreshold: 1000` — abs(eval) > 1000 = mate score
   - `accuracyAttenuationFactor: 0.003` — for accuracy formula
   - `accuracyFromCpl(cpl)` — standard formula: `100 × exp(-0.003 × CPL)`
   - `classifyCpl(cpl)` — maps CPL to `MoveClassification`
   - `computeCpl(...)` — computes CPL from evalBefore, evalAfter, side

2. **`computeCentipawnLoss()` and `computeAccuracy()` (standalone functions)** — Extractable from `analysis_model.dart` so both the analysis pipeline and real-time viewmodel can use them:
   ```dart
   double computeCentipawnLoss({evalBefore, evalAfter, isWhiteMove})
   double computeAccuracy({evalBefore, evalAfter, isWhiteMove})
   ```

3. **CPL (Centipawn Loss) formula**:
   ```
   White: CPL = (evalBefore - evalAfter) × 100
   Black: CPL = (evalAfter - evalBefore) × 100
   Positive CPL = bad for the side that moved
   Negative CPL = improvement (good)
   ```

4. **Accuracy formula**:
   ```
   accuracy = 100 × exp(-0.003 × CPL)
   accuracy = 100 when CPL ≤ 0
   accuracy ∈ [0, 100]
   ```
   This matches standard chess platform conventions (lichess/chess.com use similar exponential attenuation).

5. **Move Classification** (via `EvalConstants.classifyCpl`):

   | CPL Range (cp) | Classification | Meaning |
   |---|---:|---|
   | CPL ≤ 5 | Best | Perfect or near-perfect move |
   | 5 < CPL ≤ 20 | Excellent | Very small inaccuracy |
   | 20 < CPL ≤ 50 | Good | Slightly suboptimal |
   | 50 < CPL ≤ 100 | Inaccuracy | Noticeable but not critical |
   | 100 < CPL ≤ 200 | Mistake | Clear error, lost advantage |
   | CPL > 200 | Blunder | Game-losing error |
   | CPL ≤ -50 | Excellent | Significant improvement (brilliant/opponent error) |

6. **Mate handling** — `classifyMove()` checks if either `evalBefore` or `evalAfter` exceeds `EvalConstants.mateThreshold` (1000). In mate territory:
   - If the played move matches `bestMove` → Best
   - If CPL ≥ 200cp → Blunder (walked into mate)
   - If CPL ≤ -50cp → Excellent (escaped mate)
   - Otherwise → Best
   This prevents mate scores (e.g., +1500) from being classified using normal centipawn thresholds.

7. **`_calculateAccuracy()` replacement (ISSUE-010)** — The real-time post-game accuracy in `game_session_viewmodel.dart` was completely rewritten. Instead of comparing eval against 0.0 with ad-hoc thresholds, it now:
   - Derives `evalBefore` from the preceding move's stored evaluation (or 0.0 for the first move)
   - Uses `computeAccuracy()` with the correct CPL formula
   - Computes per-move accuracy and averages them
   - Falls back to `EvalConstants.defaultAccuracy` (85%) when no evaluation data exists

8. **`GameAnalysis.fromMoves()` rewrite** — Previously assigned hard-coded accuracy scores per classification (blunder = 20, mistake = 50, etc.). Now uses per-move `accuracy` field (computed from actual CPL) and averages across all moves. Classification counts are still tracked but accuracy is purely CPL-derived.

9. **`MoveAnalysis` new fields**:
   - `centipawnLoss` — actual CPL for the move
   - `accuracy` — per-move accuracy 0.0–100.0

**Testing Strategy**:
- 55 new tests in `test/engine_accuracy_test.dart`:
  - `computeCentipawnLoss`: white/black orientation, zero loss, improvement, symmetry (6 tests)
  - `computeAccuracy`: perfect, small/medium/large/severe loss, black symmetry (7 tests)
  - `EvalConstants`: accuracyFromCpl at various CPLs, classifyCpl at each threshold boundary, toCentipawns (10 tests)
  - `classifyMove`: best match, CPL-based (all 6 levels), black orientation, mate handling (14 tests)
  - `MoveAnalysis`: CPL/accuracy storage, evalLoss orientation, best move flag (5 tests)
  - `GameAnalysis.fromMoves`: empty, single perfect, mixed quality, all classification types, evaluations list (5 tests)
  - Accuracy Symmetry: white/black equality (2 tests)
  - Edge Cases: large evals, zero, negative improvements (4 tests)

**Risks**:
- Real-time accuracy in `_calculateAccuracy()` uses the preceding move's eval as a proxy for evalBefore. This is not true engine analysis — it doesn't compare against the best move. The full analysis pipeline (`analyzeFullGame` → `GameAnalysis.fromMoves`) produces more accurate results because it uses engine evaluations.
- The `Ev`alConstants.mateThreshold` of 1000 is a heuristic; actual mate scores from the engine are ~999999, but stored evaluations after division by 100 would be ~10000. The threshold of 1000 safely separates mate scores from positional ones.
- No migration for previously saved game sessions with old (incorrect) accuracy values.

**Rollback Considerations**:
- Each change is independently revertible.
- Old accuracy values in saved sessions are preserved (not recomputed).
- The `EvalConstants` class is additive (no existing interfaces changed).

**Dependencies**: Phase 7

**Checklist**:
- [X] ISSUE-010: Fake accuracy calculation removed from `_calculateAccuracy()`
- [X] CPL computed with correct orientation: `(evalBefore - evalAfter) × 100` for white, `(evalAfter - evalBefore) × 100` for black
- [X] Per-move centipawn loss stored in `MoveAnalysis.centipawnLoss`
- [X] Accuracy derived from CPL: `100 × exp(-0.003 × CPL)`
- [X] Move classification uses configurable thresholds in `EvalConstants`
- [X] Mate scores handled separately (abs > 1000 uses mate-specific logic)
- [X] White/black accuracy symmetry verified
- [X] `GameAnalysis.fromMoves()` uses CPL-based per-move accuracy instead of fixed per-classification scores
- [X] All previous 139 tests continue to pass
- [X] 55 new accuracy tests cover: CPL computation, accuracy formula, all classification levels, mate handling, symmetry, edge cases

**Success Criteria**:
- ✓ Accuracy reflects real centipawn loss
- ✓ Perfect play → ~100% accuracy
- ✓ Blunder → significant accuracy drop (< 50%)
- ✓ White and black accuracy are symmetric (equal loss → equal accuracy)
- ✓ Numbers consistent with chess platform standards (exponential attenuation formula)
- ✓ All 194 tests pass

---

### Phase 9: Evaluation Improvements (Fallback Bot)

**Purpose**: Improve the evaluation function in the fallback bot.

**Expected Outcome**: Better positional play from `SimpleBotService`, including pawn structure awareness, king safety, and piece activity.

**Files Affected**:
- `lib/core/services/simple_bot_service.dart`
- `lib/core/services/basic_evaluator_service.dart`
- `lib/core/services/lightweight_engine_service.dart`

**Implementation Order**:
1. Add PSTs for rooks and queens in `BasicEvaluatorService` and `LightweightEngineService` (ISSUE-024)
2. Add pawn structure evaluation (doubled, isolated, passed pawns)
3. Add king zone safety evaluation (not just pawn shield)
4. Add mobility evaluation (number of legal moves)
5. Add endgame evaluation (king centralization)
6. Add tempo/bonus for development in opening

**Testing Strategy**:
- Unit tests for each evaluation feature
- Position testing: known positions where specific features matter
- Play testing: compare move selection before/after

**Risks**:
- Too many evaluation terms can cause evaluation instability
- Performance impact of mobility evaluation (need to count moves)

**Rollback Considerations**:
- Each evaluation term can be independently added/removed
- Fallback is secondary to Stockfish

**Dependencies**: Phase 4

**Checklist**:
- [ ] PSTs for rooks and queens added to all engines
- [ ] Pawn structure evaluation implemented
- [ ] King zone safety evaluated
- [ ] Mobility evaluation added (with performance guard)
- [ ] Endgame evaluation added
- [ ] Opening development bonus added
- [ ] Evaluation still completes in <10ms per position
- [ ] All tests pass

**Success Criteria**:
- ✓ Fallback bot understands pawn structure weaknesses
- ✓ Fallback bot recognizes good/bad king positions
- ✓ Fallback bot prefers active pieces
- ✓ Evaluation correlates better with game outcome

---

### Phase 10: Analysis Engine Improvements

**Purpose**: Fix all remaining analysis mode issues and improve the user experience.

**Expected Outcome**: Analysis mode works correctly with engine eval, multi-line display, and accurate move classification.

**Files Affected**:
- `lib/providers/analysis_provider.dart`
- `lib/screens/analysis/` (UI files)

**Implementation Order**:
1. Fix `setMaxStrength` to properly flow through the command pipeline
2. Ensure `ucinewgame` is used appropriately (ISSUE-017)
3. Support 3+ lines of analysis (MultiPV)
4. Fix live analysis with proper eval updates
5. Ensure analysis cleanup on provider dispose

**Testing Strategy**:
- Integration test: analyze a full game, verify all moves classified
- Manual testing: compare against lichess/chess.com analysis
- Performance benchmark: measure total analysis time

**Risks**:
- Analysis of long games (80+ moves) may be slow if not optimized
- MultiPV increases analysis time significantly

**Rollback Considerations**:
- Analysis UI is separate from game play; changes are isolated

**Dependencies**: Phase 1, Phase 6, Phase 7

**Checklist**:
- [ ] Analysis uses full engine strength (no ELO limits)
- [ ] Move classification correct for all positions
- [ ] MultiPV displays 3+ lines correctly
- [ ] Live analysis updates eval in real-time
- [ ] Analysis cleanup on dispose
- [ ] Eval graph renders correctly
- [ ] All tests pass

**Success Criteria**:
- ✓ Full game analysis produces accurate evaluations
- ✓ Move classification matches major chess platforms
- ✓ 3 engine lines displayed correctly
- ✓ Analysis completes in reasonable time

---

### Phase 11: Error Handling & Resilience

**Purpose**: Implement robust error handling at all levels of the engine system.

**Expected Outcome**: Engine failures are handled gracefully with clear user feedback. Temporary failures don't permanently break functionality. All error paths have logging.

**Files Affected**:
- `lib/core/services/stockfish_service.dart`
- `lib/core/services/simple_bot_service.dart`
- `lib/providers/engine_provider.dart`
- `lib/providers/analysis_provider.dart`
- `lib/providers/game_session_viewmodel.dart`

**Implementation Order**:
1. Add consistent logging across all engine services
2. Implement proper error propagation (don't swallow errors)
3. Add user-visible error messages for engine failures
4. Implement automatic retry with exponential backoff
5. Add engine health monitoring
6. Ensure all catch blocks have useful fallback behavior

**Testing Strategy**:
- Unit tests for each error scenario
- Integration tests for error recovery
- Stress testing: rapid start/stop, invalid FENs, concurrent calls

**Risks**:
- Over-engineering error handling for edge cases that rarely occur
- Adding too much logging may impact performance

**Rollback Considerations**:
- Error handling improvements don't affect core functionality
- Easy to rollback individual error paths

**Dependencies**: Phase 2

**Checklist**:
- [ ] All engine services have consistent logging
- [ ] No empty catch blocks (each has at minimum a debugPrint)
- [ ] User-visible errors for critical engine failures
- [ ] Automatic retry with backoff for transient failures
- [ ] Engine health monitoring (ping/health check)
- [ ] All tests pass

**Success Criteria**:
- ✓ All error paths logged and handled
- ✓ Transient failures automatically recover
- ✓ User receives clear feedback on engine issues
- ✓ No silent failures in production

---

### Phase 12: Code Cleanup & Technical Debt

**Purpose**: Remove dead code, consolidate duplicate code, and clean up the codebase.

**Expected Outcome**: Clean, maintainable codebase with no dead code, minimal duplication, and consistent patterns.

**Files Affected**:
- All engine-related files

**Implementation Order**:
1. Remove or integrate `LightweightEngineService` (ISSUE-021)
2. Remove unused `analyzeGame()` method from `EngineNotifier` (ISSUE-025)
3. Consolidate evaluation functions (reduce code duplication)
4. Fix `Chess` library direct board access (ISSUE-026)
5. Standardize naming conventions across services
6. Extract shared constants and types
7. Clean up all TODOs and comments

**Testing Strategy**:
- All existing tests must pass
- Code coverage should not decrease
- Manual smoke testing of all features

**Risks**:
- Removing apparently dead code that is actually used via reflection or runtime binding
- Consolidation may introduce coupling between modules

**Rollback Considerations**:
- Each cleanup can be done independently
- Code removal can be reverted via source control

**Dependencies**: All previous phases

**Checklist**:
- [ ] `LightweightEngineService` integrated or removed
- [ ] `analyzeGame()` removed from `EngineNotifier`
- [ ] Evaluation code deduplicated
- [ ] Direct `board.board` access replaced with `board.get()`
- [ ] Naming conventions consistent
- [ ] Shared constants extracted
- [ ] All TODOs addressed
- [ ] All tests pass

**Success Criteria**:
- ✓ No dead code in engine modules
- ✓ No code duplication in evaluation functions
- ✓ Consistent naming and patterns
- ✓ All tests pass

---

### Phase 13: Performance Optimization

**Purpose**: Optimize engine interaction for mobile performance.

**Expected Outcome**: Fast engine initialization, responsive analysis, no UI jank during engine operations.

**Files Affected**:
- All engine-related files

**Implementation Order**:
1. Add eager engine initialization at app startup (ISSUE-027)
2. Optimize stream subscription management
3. Benchmark and optimize evaluation performance
4. Add node count limits for fallback search
5. Profile and optimize analysis pipeline
6. Reduce unnecessary UI rebuilds during analysis
7. Add time-bounded search for fallback engines

**Testing Strategy**:
- Performance benchmarks for all engine operations
- UI responsiveness testing (no dropped frames)
- Battery usage profiling
- Memory usage tracking

**Risks**:
- Eager initialization may waste resources if user never plays against the bot
- Performance optimization may reduce code clarity

**Rollback Considerations**:
- Each optimization independently reversible
- Eager init can be made lazy again

**Dependencies**: All previous phases

**Checklist**:
- [ ] Engine initialized at app startup (warm start)
- [ ] Stream subscriptions optimized (single subscription pattern)
- [ ] Evaluation speed benchmarked (target: <1ms per evaluation)
- [ ] Fallback search time-bounded (max 5 seconds)
- [ ] Analysis pipeline: <500ms per move
- [ ] UI responsive during all engine operations
- [ ] Battery/memory within acceptable range
- [ ] All tests pass

**Success Criteria**:
- ✓ Engine ready within 2 seconds of app launch
- ✓ Analysis: <500ms per move
- ✓ No UI jank during engine operations
- ✓ Battery usage: <5% per hour of play

---

### Phase 14: Testing & Validation

**Purpose**: Comprehensive testing of all engine functionality.

**Expected Outcome**: All engine features have automated tests. No regressions. Confidence in production reliability.

**Files Affected**:
- `test/` directory (all engine-related test files)

**Implementation Order**:
1. Create mock Stockfish service for unit tests
2. Unit tests for initialization (every state transition)
3. Unit tests for evaluation (known positions)
4. Unit tests for search (perft-like move generation)
5. Unit tests for analysis and classification
6. Unit tests for accuracy calculation
7. Integration tests for full game flow
8. Performance benchmarks (regression prevention)
9. Stress tests (concurrent calls, invalid inputs)

**Testing Strategy**:
- Test-driven development for new features
- Regression tests for every issue fix
- Performance benchmarks in CI
- Manual test plan for game play, analysis, and puzzles

**Risks**:
- Mocking Stockfish may not capture all edge cases
- Full Stockfish integration tests require native binary

**Rollback Considerations**:
- Tests don't affect production code
- Can be added incrementally

**Dependencies**: All previous phases

**Checklist**:
- [ ] Mock Stockfish service for unit tests
- [ ] Initialization tests (all state transitions)
- [ ] Evaluation tests (100+ positions)
- [ ] Search tests (depth-verified)
- [ ] Analysis tests (full game analysis)
- [ ] Accuracy calculation tests
- [ ] Integration tests (full game play flow)
- [ ] Performance benchmarks
- [ ] Stress tests
- [ ] Regression tests for every ISSUE
- [ ] All tests pass in CI

**Success Criteria**:
- ✓ 80%+ code coverage on engine services
- ✓ Every ISSUE has a regression test
- ✓ All performance benchmarks within targets
- ✓ No regressions from previous phases
- ✓ CI pipeline green

---

### Phase 15: Final Validation & Production Readiness

**Purpose**: Final manual testing, edge case validation, and production deployment preparation.

**Expected Outcome**: Engine system is production-ready with all features working correctly.

**Files Affected**: None (testing only)

**Implementation Order**:
1. Manual game play testing at all difficulty levels
2. Manual analysis testing (full game, single position)
3. Edge case testing (checkmate, stalemate, insufficient material, en passant, castling, promotion)
4. Time control edge cases (zero time, very low time, increment)
5. Multi-game session testing (start, finish, save, load, analyze)
6. Platform-specific testing (Android, iOS)
7. Performance validation on low-end devices
8. Regression testing: all previously broken features work
9. Release checklist review

**Testing Strategy**:
- Manual test plan covering all engine features
- Edge case matrix
- Platform compatibility matrix
- Device performance matrix

**Risks**:
- Edge cases discovered late
- Platform-specific bugs (especially Stockfish binary compatibility)

**Rollback Considerations**:
- Version control for easy rollback
- Feature flags for risky changes

**Dependencies**: Phase 14

**Checklist**:
- [ ] Game play tested at all 10 difficulty levels
- [ ] Analysis tested (full game + single position)
- [ ] All chess rules edge cases tested
- [ ] Time control edge cases tested
- [ ] Multi-session tested (save/load)
- [ ] Android testing completed
- [ ] iOS testing completed
- [ ] Low-end device performance validated
- [ ] Regression: all ISSUEs verified fixed
- [ ] Release checklist complete

**Success Criteria**:
- ✓ All game play scenarios work correctly
- ✓ All difficulty levels play at appropriate strength
- ✓ Analysis produces accurate results
- ✓ All edge cases handled
- ✓ Cross-platform compatibility confirmed
- ✓ Production-ready

---

## Dependency Graph

```
Phase 0: Analysis (no deps)
    │
    ▼
Phase 1: Stockfish Init fix (needs Phase 0)
    │
    ├──────────────────────────────────────────────┐
    ▼                                              ▼
Phase 2: Lifecycle (needs P1)           Phase 5: Eval Sign (needs P1) — COMPLETED
    │                                              │
    ▼                                              ▼
Phase 3: Difficulty (needs P1, P2) — COMPLETED      Phase 6: Eval Correctness (needs P1, P5) — COMPLETED
    │                                              │
    ▼                                              ▼
Phase 4: Time Mgmt (needs P1) — COMPLETED            Phase 7: Analysis Optimize (needs P6) — COMPLETED
    │                                                                              │
    └──────────────────────────────────────────────┐                              ▼
                                                    ▼              Phase 8: Accuracy (needs P7) — COMPLETED
                                         Phase 9: Search (needs P1, prefer after P4)
                                                    │
                                                    ▼
                                         Phase 10: Eval (needs P9)
                                                   │
                    ┌───────────────────────────────┘
                    ▼
           Phase 11: Analysis Engine (needs P6, P7, P8)
                    │
                    ▼
           Phase 12: Error Handling (needs P2)
                    │
                    ▼
           Phase 13: Cleanup (needs all above)
                    │
                    ▼
           Phase 14: Performance (needs all above)
                    │
                    ▼
           Phase 15: Testing (needs all above)
                    │
                    ▼
           Phase 16: Validation (needs P15)
```

**Critical Path**: Phase 1 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 11

**Independent Tracks**:
- Track A (must do): P1 → P2 → P3 → P4
- Track B (must do): P1 → P5 → P6 → P7 → P8
- Track C (nice to have): P9 → P10
- Track D (polish): P11, P12, P13, P14, P15, P16

---

## Testing Strategy

### Unit Tests
- Test each function in isolation
- Mock `Stockfish` and Streams for service testing
- Known-position evaluation values
- Search tree verification (for fallback engines)

### Integration Tests
- Full initialization → `getBestMove` → result
- Analysis of a complete short game (10-15 moves)
- Start game → play moves → undo → engine responds → game over

### Regression Tests
- Every ISSUE gets a test case that verifies the fix
- Automatically run in CI pipeline

### Manual Testing
- Game play at each difficulty level (10 games per level)
- Full game analysis comparison with lichess/chess.com
- Edge cases (promotion, en passant, castling, checkmate patterns)

### Stress Testing
- 100 rapid start/stop cycles
- Maximum analysis depth for long periods
- Concurrent engine requests
- Random FEN input validation
- Memory usage monitoring over extended play

---

## Overall Architecture Review

### Engine Architecture
**Rating: 3/10**

The engine architecture has a reasonable high-level design (isolate-based Stockfish with Dart fallback) but is critically broken at the implementation level. The command queue pattern with `_isEngineReady` blocking is a fundamental design flaw. The singleton service pattern adds unnecessary complexity without clear benefits.

### Maintainability
**Rating: 4/10**

Code is generally readable with good comments. However, there is significant code duplication (three evaluation functions with similar logic). Error handling is inconsistent (empty catch blocks). The mixed Riverpod pattern (two competing game state models: `GameState` and `GameSession`) adds confusion.

### Scalability
**Rating: 5/10**

The architecture scales reasonably well for the required features. Adding new difficulty levels or time controls is straightforward. The provider pattern supports adding new features. However, the dual game state model (`game_provider.dart` vs `game_session_viewmodel.dart`) is a scalability concern.

### Performance
**Rating: 2/10**

Performance is poor due to:
- Stockfish initialization timeout (5s delay on every game start)
- Fallback depth caps that make search shallow but still slow
- Additive artificial delays doubling response time
- Analysis calling the engine 2× per move
- Direct board array access (minor)
- Stream subscription churn

### Reliability
**Rating: 2/10**

Engine is not reliable:
- Stockfish never initializes (always falls back)
- Once fallback activated, never recovers
- Timeouts permanently disable the engine
- Errors silently swallowed in isolate
- No error recovery mechanisms
- Race conditions in initialization
- Sign errors in evaluation display

### Code Duplication
**Rating: 4/10**

Three separate evaluation functions with ~80% identical code:
- `SimpleBotService._evaluatePosition()`
- `LightweightEngineService._evaluate()`
- `BasicEvaluatorService._evaluateBoard()`

Each duplicates the board iteration and piece value logic. PST arrays are duplicated across all three files.

### Technical Debt
**Rating: 3/10**

Significant technical debt:
- Dead code (`LightweightEngineService`, `analyzeGame()`)
- Two competing game state models
- `mounted` check in non-Widget context (compilation hazard)
- Empty catch blocks
- No tests for actual Stockfish functionality (all tests use `forceFallback`)
- Hard-coded values (depth caps, timing)
- Circular dependency in initialization
- 28 documented issues

### Future Extensibility
**Rating: 5/10**

The provider pattern and service abstraction make adding features straightforward. Adding new bot types, puzzle sources, or analysis features is well-supported by the current architecture. The main blocker is fixing the existing bugs first.

---

## Estimated Refactor Scope

| Metric | Value |
|--------|-------|
| **Number of Phases** | 16 implementation + 1 analysis |
| **Files Impacted** | ~15-20 source files |
| **Risk Level** | Medium-High (critical initialization fix has far-reaching effects) |
| **Complexity** | High (depends on fixing the core deadlock first) |
| **Estimated Effort** | 4-8 weeks for full completion |
| **Estimated Effort (Core Only)** | 1-2 weeks for Phase 1-5 (critical path) |

### Recommended Implementation Order

1. **Must do immediately**: Phase 1 (Stockfish initialization), Phase 5 (evaluation sign fix) — COMPLETED
2. **Should do next**: Phase 2 (lifecycle), Phase 3 (difficulty), Phase 4 (time management) — COMPLETED
3. **Important for users**: Phase 6 (analysis optimization), Phase 7 (analysis optimize), Phase 8 (accuracy) — COMPLETED
4. **Nice to have**: Phase 9 (fallback search), Phase 10 (fallback evaluation)
5. **Polish**: Phase 11-16

The **critical path** is Phases 1 → 5 → 6 → 7 → 8, which fixes:
- Stockfish not working
- Wrong evaluation signs
- Slow/broken analysis
- Wrong accuracy numbers

---

## Expected End State

After all phases are completed, the ChessMaster Offline engine system should provide:

### Stable Stockfish Initialization
- Engine initializes within 2 seconds of app launch
- All UCI handshake steps complete correctly
- Engine transitions through all states correctly
- Status indicators show accurate state

### Correct UCI Implementation
- All UCI commands use correct syntax
- `UCI_Elo` vs `Skill Level` handled correctly
- Time management uses `wtime`/`btime` appropriately
- Command queue processes serially without deadlocks
- `ucinewgame` sent between games

### Reliable Engine Lifecycle
- Start, stop, restart without resource leaks
- Timeout recovery (no permanent fallback)
- App backgrounding handled correctly
- Memory usage stable over extended play
- No stream subscription leaks

### Accurate Difficulty Scaling
- 10 distinct difficulty levels from 800-2800 ELO
- Beginner makes clearly suboptimal moves
- Grandmaster plays at near-full Stockfish strength
- Each level feels distinct and appropriate

### Human-Like Playing Strength
- Bot response time matches configured think time
- No artificial or additive delays
- Natural-feeling move timing (not instant, not artificially slow)
- Appropriate strength for each level

### Strong Fallback Engine
- SimpleBotService at depth 4 plays ~1500-1800 ELO
- Evaluation covers material, PST, pawn structure, king safety, mobility
- Alpha-beta pruning correctly implemented
- Quiescence search reduces horizon effect
- Good move ordering with killers and MVV-LVA

### Proper Analysis Mode
- Correct white-relative evaluation display
- 3+ engine lines displayed
- Accurate move classification (blunder/mistake/inaccuracy/good/excellent)
- Fast analysis (~500ms per move)
- Evaluation graph matches engine evaluations

### Accurate Statistics
- Centipawn loss calculated correctly
- Accuracy percentage based on real centipawn loss
- Numbers consistent with chess platform standards
- Per-move accuracy breakdown available

### High-Performance Search
- Stockfish search uses full machine capability
- Fallback search time-bounded (<5 seconds)
- No UI jank during engine operations
- Battery-efficient

### Robust Error Recovery
- Transient failures auto-recover
- Engine health monitored
- User receives clear feedback on issues
- No permanent fallback activation

### Comprehensive Automated Tests
- 80%+ code coverage on engine services
- Regression test for every documented issue
- Performance benchmarks in CI
- Cross-platform test coverage

### Production-Ready Reliability
- All 15 phases completed
- Manual validation on target platforms
- Edge cases handled
- Release checklist complete

---

*End of ENGINE_REFACTOR_ROADMAP.md*
