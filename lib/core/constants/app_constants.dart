// App-wide constants for ChessMaster Offline

import 'dart:math';

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'ChessMaster Offline';
  static const String appVersion = '1.0.0';

  // Difficulty Levels
  //
  // UCI_Elo values map to Stockfish's UCI_LimitStrength range (1320–3190).
  // Each level is at least 80 ELO apart so Stockfish plays distinctly differently.
  //
  // Stockfish UCI_Elo key facts:
  //   - Minimum: 1320 (plays weakly, blunders frequently)
  //   - Maximum: 3190 (full strength within limits)
  //   - Values below 1320 are treated as 1320 (no differentiation at very low end)
  //
  // Depth controls "go depth N". Think time controls minimum search time.
  static const List<DifficultyLevel> difficultyLevels = [
    DifficultyLevel(
      level: 1,
      elo: 1320,
      depth: 1,
      thinkTimeMs: 300,
      name: 'Beginner',
    ),
    DifficultyLevel(
      level: 2,
      elo: 1400,
      depth: 3,
      thinkTimeMs: 500,
      name: 'Novice',
    ),
    DifficultyLevel(
      level: 3,
      elo: 1500,
      depth: 5,
      thinkTimeMs: 700,
      name: 'Casual',
    ),
    DifficultyLevel(
      level: 4,
      elo: 1600,
      depth: 8,
      thinkTimeMs: 1000,
      name: 'Intermediate',
    ),
    DifficultyLevel(
      level: 5,
      elo: 1700,
      depth: 10,
      thinkTimeMs: 1200,
      name: 'Club Player',
    ),
    DifficultyLevel(
      level: 6,
      elo: 1850,
      depth: 12,
      thinkTimeMs: 1500,
      name: 'Advanced',
    ),
    DifficultyLevel(
      level: 7,
      elo: 2000,
      depth: 14,
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
      elo: 2500,
      depth: 20,
      thinkTimeMs: 2200,
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

  /// Safe search depth for the fallback (SimpleBot) engine.
  /// The fallback uses pure-Dart minimax and cannot search deep without ANR.
  /// Scales with difficulty while staying within performance limits.
  int get fallbackDepth {
    if (depth <= 1) return 1;
    if (depth <= 2) return 2;
    if (depth <= 8) return 3;
    return 4;
  }

  /// Number of top candidate moves to consider (MultiPV) for variety.
  int get multiPv {
    if (level <= 2) return 4; // Beginner/Novice
    if (level <= 5) return 3; // Casual to Club Player
    if (level <= 8) return 2; // Advanced to Master
    return 1; // Grandmaster/Maximum (Deterministic out of book)
  }

  /// Evaluation threshold in centipawns (100 = 1 pawn).
  /// The bot can pick any candidate move whose evaluation is within this threshold of the absolute best move.
  int get evalThresholdCp {
    if (level == 1) return 250; // 2.5 pawns
    if (level == 2) return 150; // 1.5 pawns
    if (level == 3) return 100; // 1.0 pawn
    if (level == 4) return 80;
    if (level == 5) return 50; // 0.5 pawns
    if (level == 6) return 40;
    if (level == 7) return 30;
    if (level == 8) return 20; // 0.2 pawns
    if (level == 9) return 10;
    return 0; // Level 10
  }
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
  Duration get totalTime => initialDuration;
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
  puzzle, // Puzzle solving mode
}

/// Bot type for AI opponents
enum BotType {
  simple, // Lightweight bot using minimax
  stockfish; // Full Stockfish engine

  String get displayName {
    switch (this) {
      case BotType.simple:
        return 'Simple Bot';
      case BotType.stockfish:
        return 'Stockfish Engine';
    }
  }

  String get description {
    switch (this) {
      case BotType.simple:
        return 'Fast, lightweight AI';
      case BotType.stockfish:
        return 'Maximum strength';
    }
  }
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

// ──────────────────────────────────────────────
// Evaluation & Accuracy Constants (Phase 8)
// ──────────────────────────────────────────────

/// Centipawn loss thresholds for move classification.
/// All values are in centipawns (100 cp = 1 pawn).
/// These follow standard chess platform conventions.
class EvalConstants {
  EvalConstants._();

  /// Blunder threshold: ≥200cp (2.0 pawns) — losing a full piece or more.
  static const double thresholdBlunderCp = 200;

  /// Mistake threshold: ≥100cp (1.0 pawn) — losing a pawn or clear positional advantage.
  static const double thresholdMistakeCp = 100;

  /// Inaccuracy threshold: ≥50cp (0.5 pawns) — suboptimal but not critical.
  static const double thresholdInaccuracyCp = 50;

  /// Good threshold: ≥20cp — slightly suboptimal.
  static const double thresholdGoodCp = 20;

  /// Excellent threshold: ≥5cp — very small loss, nearly best.
  static const double thresholdExcellentCp = 5;

  /// Positive improvement threshold: ≤ -50cp means the move improved the position
  /// significantly (opponent blundered or brilliant find).
  static const double thresholdBrilliantCp = -50;

  /// Mate score absolute minimum: scores above this are forced mate values.
  static const double mateThreshold = 1000;

  /// Accuracy formula: 100 × exp(-0.003 × CPL).
  /// Attenuation factor controls how quickly accuracy drops with CPL.
  static const double accuracyAttenuationFactor = 0.003;

  /// Maximum possible accuracy.
  static const double maxAccuracy = 100.0;

  /// Minimum possible accuracy.
  static const double minAccuracy = 0.0;

  /// Default accuracy when no evaluation data is available.
  static const double defaultAccuracy = 85.0;

  /// Convert pawns to centipawns.
  static double toCentipawns(double evalPawns) => evalPawns * 100;

  /// Compute accuracy from centipawn loss.
  /// CPL ≥ 0: 100 × exp(-0.003 × CPL)
  /// CPL < 0 (improvement): 100
  static double accuracyFromCpl(double cpl) {
    if (cpl <= 0) return maxAccuracy;
    return (maxAccuracy * exp(-accuracyAttenuationFactor * cpl)).clamp(
      minAccuracy,
      maxAccuracy,
    );
  }

  /// Compute centipawn loss from evalBefore and evalAfter for a given side.
  /// Returns positive value = bad for the side.
  static double computeCpl({
    required double evalBefore,
    required double evalAfter,
    required bool isWhiteMove,
  }) {
    final lossPawns = isWhiteMove
        ? evalBefore - evalAfter
        : evalAfter - evalBefore;
    return toCentipawns(lossPawns);
  }

  /// Classify a centipawn loss value into a MoveClassification.
  static MoveClassification classifyCpl(double cpl) {
    if (cpl <= thresholdExcellentCp) return MoveClassification.best;
    if (cpl <= thresholdGoodCp) return MoveClassification.excellent;
    if (cpl <= thresholdInaccuracyCp) return MoveClassification.good;
    if (cpl <= thresholdMistakeCp) return MoveClassification.inaccuracy;
    if (cpl <= thresholdBlunderCp) return MoveClassification.mistake;
    return MoveClassification.blunder;
  }
}

/// Move classification for analysis
enum MoveClassification {
  blunder(color: 0xFFFF0000, symbol: '??', name: 'Blunder'),
  miss(color: 0xFFFF0000, symbol: '?', name: 'Miss'),
  mistake(color: 0xFFFF8C00, symbol: '?', name: 'Mistake'),
  inaccuracy(color: 0xFFFFD700, symbol: '?!', name: 'Inaccuracy'),
  book(color: 0xFFA855F7, symbol: '', name: 'Book'),
  good(color: 0xFF90EE90, symbol: '', name: 'Good'),
  great(color: 0xFF5CACEE, symbol: '!', name: 'Great'),
  excellent(color: 0xFF00FF00, symbol: '!', name: 'Excellent'),
  brilliant(color: 0xFF00BFFF, symbol: '!!', name: 'Brilliant'),
  best(color: 0xFF00FF7F, symbol: '', name: 'Best Move'),
  forced(color: 0xFF808080, symbol: '', name: 'Forced'),
  onlyMove(color: 0xFF00FF7F, symbol: '', name: 'Only Move');

  final int color;
  final String symbol;
  final String name;

  const MoveClassification({
    required this.color,
    required this.symbol,
    required this.name,
  });
}
