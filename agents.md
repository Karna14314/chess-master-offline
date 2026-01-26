# Agent Guide: ChessMaster Offline

## 🤖 Welcome, Agent (Jules & Others)

This document serves as your primary orientation guide for the **ChessMaster Offline** project. It outlines the architecture, directory structure, and development conventions you must follow.

**Primary Context Source**: Refer to `.kiro/specs/chessmaster-offline-overhaul/design.md` for the most up-to-date architectural decisions and `chess.md` for the original project vision.

---

## 🏗️ Technical Architecture

This project is a **Flutter (3.x)** application designed for **Offline** use on Android.

### 1. Core Stack
*   **Language**: Dart (Flutter).
*   **State Management**: **Riverpod 2.x**. We do not use Provider or GetX.
*   **Database**: **SQLite** (`sqflite`) for storing games, puzzles, and history.
*   **Chess Engine**: **Stockfish 16 NNUE** (C++), integrated via `dart_ffi`.
    *   *Note*: The engine runs locally. Do not attempt to fetch moves from an HTTP API.
*   **Chess Logic**: `dart_chess` package (or similar local logic) for move validation and board state.

### 2. Architectural Pattern
We follow a pragmatic **Clean Architecture** approach:

1.  **UI Layer (`lib/screens`, `lib/widgets`)**: Pure Flutter widgets. They watch Providers.
2.  **State Layer (`lib/providers`)**: Riverpod Notifiers that manage state and interact with Services.
3.  **Domain/Service Layer (`lib/core/services`)**: Business logic, database access, and engine communication.
4.  **Model Layer (`lib/models`)**: Immutable data classes (freezed or standard Dart classes).

---

## 📂 Directory Structure Map

```text
lib/
├── main.dart                    # Application entry point
├── core/                        # Core utilities and shared logic
│   ├── constants/               # App-wide constants (colors, strings, enums)
│   ├── services/                # Business logic implementation
│   │   ├── stockfish_service.dart  # CRITICAL: Handles C++ engine interop
│   │   ├── database_service.dart   # SQLite management
│   │   └── audio_service.dart      # Sound effects
│   ├── theme/                   # Material 3 theme definitions
│   └── utils/                   # Helpers (PGN parser, formatting)
├── models/                      # Data classes (Game, Move, Puzzle)
├── providers/                   # Riverpod StateNotifiers
│   ├── game_provider.dart       # The heart of the gameplay loop
│   ├── engine_provider.dart     # Manages engine analysis state
│   └── ...
├── screens/                     # Feature-specific screens
│   ├── game/                    # The main Chess Board screen
│   ├── puzzles/                 # Puzzle solving interface
│   ├── analysis/                # Game analysis tools
│   ├── home/                    # Main menu / Dashboard
│   └── settings/                # App configuration
└── widgets/                     # Reusable UI components (Board, Pieces)
```

---

## 🔑 Key Concepts & Systems

### 1. The Game Loop
*   The `GameProvider` is the central source of truth for the board state.
*   Moves are validated using the `chess` library logic before being applied.
*   State updates flow: `User Input` -> `GameProvider` -> `BoardWidget` rebuild.

### 2. Stockfish Integration
*   We use **Dart FFI** to talk to the native Stockfish binary.
*   **UCI Protocol**: The app communicates with the engine using UCI commands (`position startpos...`, `go depth 20`).
*   *Constraint*: Native binaries are located in `android/app/src/main/jniLibs/`. Ensure you respect architecture constraints (arm64-v8a, armeabi-v7a).

### 3. Puzzles
*   Puzzles are stored locally in a SQLite database or JSON file.
*   Do not attempt to fetch puzzles from Lichess API during runtime; they are pre-packaged.

### 4. Navigation
*   The app uses a **Bottom Navigation** structure (Home, Puzzles, Analysis, Settings).
*   Navigation state is managed via Riverpod (see `.kiro/specs/.../design.md`).

---

## 🛡️ Development Rules

1.  **Strict Typing**: Always use strong types. Avoid `dynamic` unless absolutely necessary.
2.  **State Management**:
    *   Do NOT use `setState` for complex logic. Use Riverpod.
    *   Separate logic from UI. Widgets should be dumb.
3.  **Assets**:
    *   Chess pieces are **SVGs** (`assets/pieces/`).
    *   Load assets using the helper constants/classes, do not hardcode strings repeatedly.
4.  **Testing**:
    *   We use `flutter_test`.
    *   Unit tests for logic (providers, models).
    *   Widget tests for UI components.
    *   *Do not break existing tests.*

## 🚀 Tasks & Roadmap
The project is currently undergoing an overhaul. Always check **`.kiro/specs/chessmaster-offline-overhaul/tasks.md`** for the current active task list before starting new work.
