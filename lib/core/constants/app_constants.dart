// App-wide constants for ChessMaster Offline

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'ChessMaster Offline';
  static const String appVersion = '1.0.0';

  // Difficulty Levels (ELO and Engine Depth)
  static const List<DifficultyLevel> difficultyLevels = [
    DifficultyLevel(
      level: 1,
      elo: 800,
      depth: 1,
      thinkTimeMs: 500,
      name: 'Beginner',
    ),
    DifficultyLevel(
      level: 2,
      elo: 1000,
      depth: 3,
      thinkTimeMs: 800,
      name: 'Novice',
    ),
    DifficultyLevel(
      level: 3,
      elo: 1200,
      depth: 5,
      thinkTimeMs: 1000,
      name: 'Casual',
    ),
    DifficultyLevel(
      level: 4,
      elo: 1400,
      depth: 8,
      thinkTimeMs: 1200,
      name: 'Intermediate',
    ),
    DifficultyLevel(
      level: 5,
      elo: 1600,
      depth: 10,
      thinkTimeMs: 1500,
      name: 'Club Player',
    ),
    DifficultyLevel(
      level: 6,
      elo: 1800,
      depth: 12,
      thinkTimeMs: 1500,
      name: 'Advanced',
    ),
    DifficultyLevel(
      level: 7,
      elo: 2000,
      depth: 15,
      thinkTimeMs: 1800,
      name: 'Expert',
    ),
    DifficultyLevel(
      level: 8,
      elo: 2200,
      depth: 18,
      thinkTimeMs: 2000,
      name: 'Master',
    ),
    DifficultyLevel(
      level: 9,
      elo: 2400,
      depth: 20,
      thinkTimeMs: 2000,
      name: 'Grandmaster',
    ),
    DifficultyLevel(
      level: 10,
      elo: 2800,
      depth: 22,
      thinkTimeMs: 2500,
      name: 'Maximum',
    ),
  ];

  // Timer Presets
  static const List<TimeControl> timeControls = [
    TimeControl(name: 'No Timer', minutes: 0, increment: 0),
    TimeControl(name: '1+0 Bullet', minutes: 1, increment: 0),
    TimeControl(name: '2+1 Bullet', minutes: 2, increment: 1),
    TimeControl(name: '3+0 Blitz', minutes: 3, increment: 0),
    TimeControl(name: '3+2 Blitz', minutes: 3, increment: 2),
    TimeControl(name: '5+0 Blitz', minutes: 5, increment: 0),
    TimeControl(name: '5+3 Blitz', minutes: 5, increment: 3),
    TimeControl(name: '10+0 Rapid', minutes: 10, increment: 0),
    TimeControl(name: '15+10 Rapid', minutes: 15, increment: 10),
    TimeControl(name: '30+0 Classical', minutes: 30, increment: 0),
    TimeControl(name: '30+20 Classical', minutes: 30, increment: 20),
  ];

  // Game Constants
  static const int maxHintsPerGame = 3;
  static const int maxUndosPerGame = -1; // -1 = unlimited

  // Animation Durations
  static const Duration moveAnimationFast = Duration(milliseconds: 100);
  static const Duration moveAnimationMedium = Duration(milliseconds: 200);
  static const Duration moveAnimationSlow = Duration(milliseconds: 400);

  // Board
  static const double boardPadding = 8.0;
  static const double pieceScale = 0.85;

  // Analysis
  static const int analysisDepth = 18;
  static const int topEngineLinesCount = 3;
}

/// Represents a difficulty level configuration
class DifficultyLevel {
  final int level;
  final int elo;
  final int depth;
  final int thinkTimeMs;
  final String name;

  const DifficultyLevel({
    required this.level,
    required this.elo,
    required this.depth,
    required this.thinkTimeMs,
    required this.name,
  });
}

/// Represents a time control setting
class TimeControl {
  final String name;
  final int minutes;
  final int increment;

  const TimeControl({
    required this.name,
    required this.minutes,
    required this.increment,
  });

  bool get hasTimer => minutes > 0;

  String get displayString {
    if (!hasTimer) return 'No Timer';
    if (increment == 0) return '${minutes}min';
    return '$minutes+$increment';
  }

  Duration get initialDuration => Duration(minutes: minutes);
  Duration get incrementDuration => Duration(seconds: increment);
}

/// Player color options
enum PlayerColor {
  white,
  black,
  random;

  String get displayName {
    switch (this) {
      case PlayerColor.white:
        return 'White';
      case PlayerColor.black:
        return 'Black';
      case PlayerColor.random:
        return 'Random';
    }
  }
}

/// Game mode type
enum GameMode {
  bot, // Play against AI
  localMultiplayer, // 2 players on same device
  analysis, // Analysis mode
}

/// Game result types
enum GameResult {
  whiteWins('1-0', 'White wins'),
  blackWins('0-1', 'Black wins'),
  draw('1/2-1/2', 'Draw'),
  ongoing('*', 'Ongoing');

  final String pgn;
  final String displayName;

  const GameResult(this.pgn, this.displayName);
}

/// Move classification for analysis
enum MoveClassification {
  blunder(color: 0xFFFF0000, symbol: '??', name: 'Blunder'),
  mistake(color: 0xFFFF8C00, symbol: '?', name: 'Mistake'),
  inaccuracy(color: 0xFFFFD700, symbol: '?!', name: 'Inaccuracy'),
  book(color: 0xFFA855F7, symbol: '', name: 'Book'),
  good(color: 0xFF90EE90, symbol: '', name: 'Good'),
  excellent(color: 0xFF00FF00, symbol: '!', name: 'Excellent'),
  brilliant(color: 0xFF00BFFF, symbol: '!!', name: 'Brilliant'),
  best(color: 0xFF00FF7F, symbol: '', name: 'Best');

  final int color;
  final String symbol;
  final String name;

  const MoveClassification({
    required this.color,
    required this.symbol,
    required this.name,
  });
}
