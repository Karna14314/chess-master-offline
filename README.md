# ChessMaster Offline ♞

A feature-rich offline chess application built with Flutter, powered by the Stockfish engine. Play against the computer, solve puzzles, analyze games, and track your statistics—all without an internet connection.

## ✨ Features

- **Play vs Bot**: Challenge the built-in Stockfish engine with adjustable difficulty levels (800-2800 ELO).
- **Play vs Friend**: Local multiplayer mode for two players on the same device.
- **Puzzles**: Improve your tactical skills with daily, adaptive, and themed puzzles.
- **Game Analysis**: Analyze your games with engine evaluation, mistake detection, and alternate lines.
- **Statistics**: Track your win/loss record, puzzle rating, and performance over time.
- **Customization**: Choose from multiple board themes and piece sets.
- **Save & Load**: Automatically saves your progress; load games from PGN or history.
- **Offline First**: All core features work completely offline.

## 🛠️ Technology Stack

- **Framework**: Flutter (Dart)
- **Engine**: Stockfish (via `stockfish_chess_engine`)
- **State Management**: Riverpod
- **Storage**: SQLite (`sqflite`), Shared Preferences
- **Game Logic**: `chess` package

## 🚀 Getting Started

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Karna14314/chess-master-offline.git
    cd chess-master-offline
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    flutter run
    ```

## 📱 Screenshots

*(Add screenshots here)*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
