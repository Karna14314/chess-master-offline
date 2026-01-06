# ChessMaster Offline - AI-Assisted Development Plan

> **Goal**: Build a feature-complete offline chess app in **5-7 days** using AI pair programming.
> **Strategy**: Batch related features, use AI for boilerplate, focus on logic.

---

## 🚀 Quick Start Checklist

- [ ] Flutter SDK installed (3.x)
- [ ] Android Studio + Emulator ready
- [ ] VS Code with Flutter extension
- [ ] AI assistant ready (Claude/Cursor)

---

## 📅 5-Day Sprint Plan

### **Day 1: Project Setup + Core Board** ⏱️ 4-6 hours

#### Step 1.1 - Initialize Project
```
Create a new Flutter project called "chess_master" with:
- Riverpod for state management
- SQLite (sqflite) for database
- Material 3 theming with dark mode
- Proper folder structure as defined in chess.md
```

#### Step 1.2 - Chess Board Widget
```
Create a chess board widget using CustomPainter that:
- Renders an 8x8 board with configurable colors
- Supports 3 themes: Classic Wood, Modern Blue, Green
- Shows coordinates (a-h, 1-8) with toggle option
- Uses flutter_chess package for game state
- Renders pieces from SVG assets
- Highlights last move and legal moves
- Supports drag-and-drop piece movement
```

#### Step 1.3 - Basic Game Logic
```
Create a game provider using Riverpod that:
- Manages chess game state using chess package
- Validates and executes moves
- Detects check, checkmate, stalemate
- Maintains move history in algebraic notation
- Supports undo functionality
```

**Day 1 Deliverable**: Playable 2-player board on single device

---

### **Day 2: Stockfish + Bot Play** ⏱️ 5-7 hours

#### Step 2.1 - Stockfish Integration
```
Integrate Stockfish chess engine:
- Use stockfish_chess_engine package (pre-built binaries)
- Create StockfishService class with UCI protocol
- Implement getBestMove(fen, depth) method
- Implement analyzePosition(fen) returning eval + lines
- Add engine initialization on app start
```

#### Step 2.2 - Difficulty System
```
Create difficulty configuration:
- 10 levels mapping to Stockfish depth (1-22)
- Add human-like think delays (500ms-2500ms)
- Create difficulty selector widget with ELO display
- Store selected difficulty in preferences
```

#### Step 2.3 - Game Setup Screen
```
Create game setup screen with:
- Difficulty selector (10 levels + custom ELO slider)
- Color selection (White/Black/Random)
- Timer selection (presets + custom)
- "Start Game" button
- Store settings in provider
```

#### Step 2.4 - Bot Move Execution
```
Extend game provider to:
- Detect when it's bot's turn
- Request move from Stockfish with appropriate depth
- Apply artificial delay for realism
- Execute bot move with animation
- Play move sounds
```

**Day 2 Deliverable**: Play vs Bot at any difficulty

---

### **Day 3: Timer + Game Management** ⏱️ 4-5 hours

#### Step 3.1 - Timer System
```
Create chess timer provider and widget:
- Countdown timer for both players
- Support increments (Fischer)
- Preset time controls: 1+0, 3+2, 5+0, 10+0, 15+10
- Custom time control dialog
- Low time warning sound at 10 seconds
- Timer pause for bot games
- Flag (time out) detection
```

#### Step 3.2 - Game Over Handling
```
Create game over dialog showing:
- Result (Win/Loss/Draw) with reason
- Game stats (moves, time, accuracy)
- Options: "Analyze", "Rematch", "New Game", "Home"
- Auto-save game to database
```

#### Step 3.3 - Save/Load System
```
Implement game persistence:
- Auto-save current game on pause/exit
- Manual save with custom name
- Game history screen with list view
- Load and continue saved games
- Delete saved games
- Search/filter by date or result
```

**Day 3 Deliverable**: Complete game flow with timer and saves

---

### **Day 4: Analysis + Puzzles** ⏱️ 5-6 hours

#### Step 4.1 - Analysis Screen
```
Create post-game analysis screen:
- Navigate through game moves (arrows/swipe)
- Show position evaluation bar (-10 to +10)
- Display best move for current position
- Show top 3 engine lines
- Classify moves: blunder/mistake/inaccuracy/good/excellent
- Build evaluation graph using fl_chart
```

#### Step 4.2 - Move Hints
```
Add hint system during gameplay:
- "Hint" button (max 3 per game)
- Query Stockfish for best move
- Highlight best move square with arrow
- Track hints used in game stats
```

#### Step 4.3 - Puzzle System
```
Create puzzle trainer:
- Pre-populate 2000 puzzles from Lichess CSV
- Puzzle screen with board and info
- User must find correct move sequence
- Puzzle rating system (starts at 1200)
- Categories: tactics, checkmate, endgame
- Hint: show first move
- Skip puzzle option
- Track solve rate and rating
```

**Day 4 Deliverable**: Full analysis and puzzle system

---

### **Day 5: Polish + Extras** ⏱️ 4-5 hours ✅ COMPLETE

#### Step 5.1 - Statistics Dashboard ✅
```
Create statistics screen showing:
- Total games played
- Win/Loss/Draw record
- Performance vs each difficulty level
- Puzzles solved/attempted
- Current puzzle rating
- Average game length
- Accuracy trends
```

#### Step 5.2 - Settings & Customization ✅
```
Create settings screen:
- Board theme selector (3 themes with preview)
- Piece set selector (2 sets)
- Sound effects toggle
- Vibration toggle
- Move animation speed
- Show coordinates toggle
- Show legal moves toggle
```

#### Step 5.3 - PGN Import/Export ✅
```
Add PGN functionality:
- Export game to PGN format
- Copy PGN to clipboard
- Share PGN via Android share sheet
- Import PGN from text input
- Validate PGN and show errors
```

#### Step 5.4 - Position Setup (Optional) ✅
```
Create FEN editor screen:
- Clear/reset board buttons
- Tap to place pieces
- Set turn (white/black)
- Set castling rights
- Generate FEN string
- Play or analyze from position
```

**Day 5 Deliverable**: Polished, feature-complete app ✅

---

## 🎯 AI Prompting Strategy

### Effective Prompt Templates

#### For New Features:
```
Create [FEATURE NAME] with the following requirements:
1. [Requirement 1]
2. [Requirement 2]
3. [Requirement 3]

Use Riverpod for state management.
Follow the project structure in chess.md.
Include error handling and loading states.
```

#### For Bug Fixes:
```
The [FEATURE] has this issue: [DESCRIPTION]
Error message: [ERROR]
Expected behavior: [WHAT SHOULD HAPPEN]
Fix this while maintaining existing functionality.
```

#### For Refactoring:
```
Refactor [FILE/COMPONENT] to:
- [Improvement 1]
- [Improvement 2]
Keep the same public API.
Add comments for complex logic.
```

### Batch Prompting Tips

1. **Group related files** - Create models, providers, and screens for a feature together
2. **Provide context** - Reference chess.md for structure
3. **Be specific** - Include exact method signatures when needed
4. **Iterate fast** - Test after each feature, not at the end

---

## 📁 File Creation Order

```
Phase 1: Core Setup
├── pubspec.yaml (dependencies)
├── lib/main.dart
├── lib/core/constants/app_constants.dart
├── lib/core/theme/app_theme.dart
├── lib/core/theme/board_themes.dart
└── lib/core/services/database_service.dart

Phase 2: Chess Board
├── lib/models/game_model.dart
├── lib/providers/game_provider.dart
├── lib/screens/game/widgets/chess_board.dart
├── lib/screens/game/widgets/chess_piece.dart
└── lib/screens/game/game_screen.dart

Phase 3: Engine
├── lib/core/services/stockfish_service.dart
├── lib/providers/engine_provider.dart
├── lib/models/analysis_model.dart
└── lib/screens/game_setup/game_setup_screen.dart

Phase 4: Timer
├── lib/providers/timer_provider.dart
├── lib/screens/game/widgets/timer_widget.dart
└── lib/screens/game/widgets/game_controls.dart

Phase 5: Persistence
├── lib/core/services/storage_service.dart
├── lib/core/utils/pgn_parser.dart
└── lib/screens/history/game_history_screen.dart

Phase 6: Analysis
├── lib/screens/analysis/analysis_screen.dart
├── lib/screens/analysis/widgets/eval_bar.dart
├── lib/screens/analysis/widgets/eval_graph.dart
└── lib/screens/analysis/widgets/engine_lines.dart

Phase 7: Puzzles
├── lib/models/puzzle_model.dart
├── lib/providers/puzzle_provider.dart
└── lib/screens/puzzles/puzzle_screen.dart

Phase 8: Polish
├── lib/models/statistics_model.dart
├── lib/providers/statistics_provider.dart
├── lib/screens/stats/statistics_screen.dart
├── lib/screens/settings/settings_screen.dart
└── lib/screens/home/home_screen.dart
```

---

## ⚡ Speed Optimization Tips

| Tip | Time Saved |
|-----|------------|
| Use `stockfish_chess_engine` package instead of manual FFI | 4+ hours |
| Use `chess` package for rules/validation | 6+ hours |
| Copy Lichess puzzles CSV instead of building DB | 2+ hours |
| Use `fl_chart` for eval graphs | 2+ hours |
| Skip Google Drive backup for MVP | 3+ hours |
| Use pre-made SVG piece sets from lichess | 1+ hour |

---

## 🔄 Testing Checkpoint Commands

```bash
# After each phase, test with:
flutter run -d emulator

# Check for issues:
flutter analyze

# Build release APK:
flutter build apk --release

# Check APK size:
dir build\app\outputs\flutter-apk\app-release.apk
```

---

## ✅ MVP Definition (Ship This First)

### Must Have (Day 1-3):
- [x] Play vs Bot (5 difficulty levels minimum)
- [x] Timer (3 presets minimum)
- [x] Basic save/load
- [x] Move hints
- [x] Undo moves
- [x] Sound effects

### Nice to Have (Day 4-5):
- [x] Full 10 difficulty levels
- [x] Game analysis
- [x] Puzzles
- [x] Statistics
- [x] Custom themes
- [x] PGN export

### Post-MVP (Week 2+):
- [ ] Google Drive backup
- [ ] Opening book
- [x] Position editor
- [ ] Custom ELO

---

## 🚨 Common Pitfalls to Avoid

| Pitfall | Solution |
|---------|----------|
| Stockfish crashes on init | Use package, not manual FFI |
| Board not responsive | Use LayoutBuilder + AspectRatio |
| Timer drift | Use Stopwatch, not Timer |
| Slow analysis | Cache common positions |
| Large APK size | Use --split-per-abi flag |
| Puzzle DB too big | Limit to 2000, use SQLite not JSON |

---

## 📝 Daily AI Session Template

```
Start each session with:
"I'm building ChessMaster Offline chess app. Today's focus: [PHASE].
Reference chess.md for full specs. Let's build [SPECIFIC FEATURE]."

End each session with:
"Summarize what we built today.
List any known issues.
What should we tackle next?"
```

---

*Total estimated time: 25-35 hours over 5-7 days*
*With focused AI assistance: Achievable in one week*
