import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class EloSnapshot {
  final int elo;
  final int gameNumber;
  final DateTime timestamp;

  const EloSnapshot({
    required this.elo,
    required this.gameNumber,
    required this.timestamp,
  });

  factory EloSnapshot.fromMap(Map<String, dynamic> map) {
    return EloSnapshot(
      elo: map['elo'] as int? ?? StatisticsModel.defaultGameElo,
      gameNumber: map['gameNumber'] as int? ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'elo': elo,
      'gameNumber': gameNumber,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Statistics model for tracking user progress
class StatisticsModel {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final int puzzlesSolved;
  final int puzzlesAttempted;
  final int currentPuzzleRating;
  final Map<int, EloStats> gamesByElo;
  final Map<String, int> openingsPlayed;
  final int totalMoves;
  final int totalGameTimeSeconds;
  final int hintsUsed;
  final int lastUpdated;
  final int currentGameElo;
  final int initialGameElo;
  final int consecutiveWins;
  final int consecutiveLosses;
  final List<EloSnapshot> eloHistory;
  // Peak records (persisted so failed attempts never erase the best).
  final int highestPuzzleRating;
  final int strongestBotEloBeaten;
  final int gamesAnalysed;
  // Lichess-style personal records.
  final int maxWinStreak;
  final int bestEloDate;
  final int winsAsWhite;
  final int winsAsBlack;
  final int maxPuzzleStreak;
  static const int provisionalGames = 10;
  static const int defaultGameElo = 400;

  const StatisticsModel({
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.puzzlesSolved = 0,
    this.puzzlesAttempted = 0,
    this.currentPuzzleRating = 1200,
    this.gamesByElo = const {},
    this.openingsPlayed = const {},
    this.totalMoves = 0,
    this.totalGameTimeSeconds = 0,
    this.hintsUsed = 0,
    this.lastUpdated = 0,
    this.currentGameElo = defaultGameElo,
    this.initialGameElo = defaultGameElo,
    this.consecutiveWins = 0,
    this.consecutiveLosses = 0,
    this.eloHistory = const [],
    this.highestPuzzleRating = 1200,
    this.strongestBotEloBeaten = 0,
    this.gamesAnalysed = 0,
    this.maxWinStreak = 0,
    this.bestEloDate = 0,
    this.winsAsWhite = 0,
    this.winsAsBlack = 0,
    this.maxPuzzleStreak = 0,
  });

  /// Win rate as a percentage
  double get winRate => totalGames > 0 ? (wins / totalGames) * 100 : 0;

  /// Draw rate as a percentage
  double get drawRate => totalGames > 0 ? (draws / totalGames) * 100 : 0;

  /// Loss rate as a percentage
  double get lossRate => totalGames > 0 ? (losses / totalGames) * 100 : 0;

  /// Puzzle solve rate as a percentage
  double get puzzleSolveRate =>
      puzzlesAttempted > 0 ? (puzzlesSolved / puzzlesAttempted) * 100 : 0;

  /// Average game length in moves
  double get averageGameLength => totalGames > 0 ? totalMoves / totalGames : 0;

  /// Average game time in minutes
  double get averageGameTimeMinutes =>
      totalGames > 0 ? (totalGameTimeSeconds / totalGames) / 60 : 0;

  /// Whether the player is still in provisional period.
  bool get isProvisional => totalGames < provisionalGames;

  /// Calibrated K-factor for sequential, grounded rating adjustments:
  /// - Provisional (<10 games): 24 (steady sequential placement, max swing ~22)
  /// - Developing (<30 games): 20 (max swing ~18)
  /// - Established (30+ games): 16 (max swing ~15)
  int get kFactor {
    if (totalGames < provisionalGames) return 24;
    if (totalGames < 30) return 20;
    return 16;
  }

  /// ELO trend over recent games (positive = improving, negative = dipping)
  int get eloTrend {
    if (eloHistory.isEmpty) return 0;
    if (eloHistory.length == 1) {
      return eloHistory.first.elo - initialGameElo;
    }
    final recent =
        eloHistory.length > 10
            ? eloHistory.sublist(eloHistory.length - 10)
            : eloHistory;
    final startElo =
        eloHistory.length <= 10 ? initialGameElo : recent.first.elo;
    return recent.last.elo - startElo;
  }

  /// Strongest bot ELO ever beaten (0 = none yet).
  int get strongestBotBeaten => strongestBotEloBeaten;

  /// Best ELO achieved
  int get bestElo {
    if (eloHistory.isEmpty) return currentGameElo;
    return math.max(
      currentGameElo,
      eloHistory.map((e) => e.elo).reduce(math.max),
    );
  }

  /// Standard rating tier title
  static String getRatingTier(int elo) {
    if (elo >= 2200) return 'Grandmaster';
    if (elo >= 1800) return 'Master';
    if (elo >= 1400) return 'Intermediate';
    if (elo >= 1000) return 'Club Player';
    if (elo >= 700) return 'Apprentice';
    return 'Novice';
  }

  /// Standard rating tier accent color
  static Color getRatingColor(int elo) {
    if (elo >= 2200) return const Color(0xFF00E5FF); // Diamond Cyan
    if (elo >= 1800) return const Color(0xFF7B1FA2); // Master Purple
    if (elo >= 1400) return const Color(0xFFFFB300); // Amber Gold
    if (elo >= 1000) return const Color(0xFF1E88E5); // Royal Blue
    if (elo >= 700) return const Color(0xFF00BFA5);  // Teal Apprentice
    return const Color(0xFF8D6E63);                  // Warm Bronze Novice
  }

  /// Get details about the next rating tier milestone:
  /// returns (nextTierName, nextTierElo, pointsNeeded, progressFraction 0.0..1.0)
  (String, int, int, double)? get nextTierProgress {
    if (currentGameElo >= 2200) return null; // Reached peak tier
    int targetElo;
    int floorElo;
    String targetTier;

    if (currentGameElo < 700) {
      targetTier = 'Apprentice';
      floorElo = 400;
      targetElo = 700;
    } else if (currentGameElo < 1000) {
      targetTier = 'Club Player';
      floorElo = 700;
      targetElo = 1000;
    } else if (currentGameElo < 1400) {
      targetTier = 'Intermediate';
      floorElo = 1000;
      targetElo = 1400;
    } else if (currentGameElo < 1800) {
      targetTier = 'Master';
      floorElo = 1400;
      targetElo = 1800;
    } else {
      targetTier = 'Grandmaster';
      floorElo = 1800;
      targetElo = 2200;
    }

    final pointsNeeded = math.max(0, targetElo - currentGameElo);
    final progress = ((currentGameElo - floorElo) / (targetElo - floorElo)).clamp(0.0, 1.0);
    return (targetTier, targetElo, pointsNeeded, progress);
  }

  /// Create from database map
  factory StatisticsModel.fromMap(Map<String, dynamic> map) {
    Map<int, EloStats> gamesByElo = {};
    if (map['games_by_elo'] != null) {
      try {
        final decoded =
            jsonDecode(map['games_by_elo'] as String) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          gamesByElo[int.parse(key)] = EloStats.fromMap(
            value as Map<String, dynamic>,
          );
        });
      } catch (_) {}
    }

    Map<String, int> openingsPlayed = {};
    if (map['openings_played'] != null) {
      try {
        final decoded =
            jsonDecode(map['openings_played'] as String)
                as Map<String, dynamic>;
        decoded.forEach((key, value) {
          openingsPlayed[key] = value as int;
        });
      } catch (_) {}
    }

    List<EloSnapshot> eloHistory = [];
    if (map['elo_history'] != null) {
      try {
        final decoded = jsonDecode(map['elo_history'] as String) as List;
        eloHistory =
            decoded
                .map((e) => EloSnapshot.fromMap(e as Map<String, dynamic>))
                .toList();
      } catch (_) {}
    }

    return StatisticsModel(
      totalGames: map['total_games'] as int? ?? 0,
      wins: map['wins'] as int? ?? 0,
      losses: map['losses'] as int? ?? 0,
      draws: map['draws'] as int? ?? 0,
      puzzlesSolved: map['puzzles_solved'] as int? ?? 0,
      puzzlesAttempted: map['puzzles_attempted'] as int? ?? 0,
      currentPuzzleRating: map['current_puzzle_rating'] as int? ?? 1200,
      gamesByElo: gamesByElo,
      openingsPlayed: openingsPlayed,
      totalMoves: map['total_moves'] as int? ?? 0,
      totalGameTimeSeconds: map['total_game_time_seconds'] as int? ?? 0,
      hintsUsed: map['hints_used'] as int? ?? 0,
      lastUpdated: map['last_updated'] as int? ?? 0,
      currentGameElo: () {
        final raw = map['current_game_elo'] as int?;
        final games = map['total_games'] as int? ?? 0;
        if (games == 0 &&
            (raw == null ||
                raw == 1500 ||
                raw == 1000 ||
                raw == 400 ||
                raw == 0)) {
          return defaultGameElo;
        }
        return raw ?? defaultGameElo;
      }(),
      initialGameElo: map['initial_game_elo'] as int? ?? () {
        if (eloHistory.isNotEmpty) {
          final firstElo = eloHistory.first.elo;
          if (firstElo >= 1150 && firstElo <= 1250) return 1200;
          if (firstElo >= 750 && firstElo <= 850) return 800;
          return defaultGameElo;
        }
        return map['current_game_elo'] as int? ?? defaultGameElo;
      }(),
      consecutiveWins: map['consecutive_wins'] as int? ?? 0,
      consecutiveLosses: map['consecutive_losses'] as int? ?? 0,
      eloHistory: eloHistory,
      // Backfill peaks from existing data so long-time users keep records.
      highestPuzzleRating:
          map['highest_puzzle_rating'] as int? ??
          (map['current_puzzle_rating'] as int? ?? 1200),
      strongestBotEloBeaten: map['strongest_bot_elo_beaten'] as int? ?? 0,
      gamesAnalysed: map['games_analysed'] as int? ?? 0,
      maxWinStreak: map['max_win_streak'] as int? ?? 0,
      bestEloDate: map['best_elo_date'] as int? ?? 0,
      winsAsWhite: map['wins_as_white'] as int? ?? 0,
      winsAsBlack: map['wins_as_black'] as int? ?? 0,
      maxPuzzleStreak: map['max_puzzle_streak'] as int? ?? 0,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    final eloMap = <String, dynamic>{};
    gamesByElo.forEach((key, value) {
      eloMap[key.toString()] = value.toMap();
    });

    return {
      'total_games': totalGames,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'puzzles_solved': puzzlesSolved,
      'puzzles_attempted': puzzlesAttempted,
      'current_puzzle_rating': currentPuzzleRating,
      'games_by_elo': jsonEncode(eloMap),
      'openings_played': jsonEncode(openingsPlayed),
      'total_moves': totalMoves,
      'total_game_time_seconds': totalGameTimeSeconds,
      'hints_used': hintsUsed,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
      'current_game_elo': currentGameElo,
      'initial_game_elo': initialGameElo,
      'consecutive_wins': consecutiveWins,
      'consecutive_losses': consecutiveLosses,
      'elo_history': jsonEncode(eloHistory.map((e) => e.toMap()).toList()),
      'highest_puzzle_rating': highestPuzzleRating,
      'strongest_bot_elo_beaten': strongestBotEloBeaten,
      'games_analysed': gamesAnalysed,
      'max_win_streak': maxWinStreak,
      'best_elo_date': bestEloDate,
      'wins_as_white': winsAsWhite,
      'wins_as_black': winsAsBlack,
      'max_puzzle_streak': maxPuzzleStreak,
    };
  }

  StatisticsModel copyWith({
    int? totalGames,
    int? wins,
    int? losses,
    int? draws,
    int? puzzlesSolved,
    int? puzzlesAttempted,
    int? currentPuzzleRating,
    Map<int, EloStats>? gamesByElo,
    Map<String, int>? openingsPlayed,
    int? totalMoves,
    int? totalGameTimeSeconds,
    int? hintsUsed,
    int? lastUpdated,
    int? currentGameElo,
    int? initialGameElo,
    int? consecutiveWins,
    int? consecutiveLosses,
    List<EloSnapshot>? eloHistory,
    int? highestPuzzleRating,
    int? strongestBotEloBeaten,
    int? gamesAnalysed,
    int? maxWinStreak,
    int? bestEloDate,
    int? winsAsWhite,
    int? winsAsBlack,
    int? maxPuzzleStreak,
  }) {
    return StatisticsModel(
      totalGames: totalGames ?? this.totalGames,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      puzzlesSolved: puzzlesSolved ?? this.puzzlesSolved,
      puzzlesAttempted: puzzlesAttempted ?? this.puzzlesAttempted,
      currentPuzzleRating: currentPuzzleRating ?? this.currentPuzzleRating,
      gamesByElo: gamesByElo ?? this.gamesByElo,
      openingsPlayed: openingsPlayed ?? this.openingsPlayed,
      totalMoves: totalMoves ?? this.totalMoves,
      totalGameTimeSeconds: totalGameTimeSeconds ?? this.totalGameTimeSeconds,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentGameElo: currentGameElo ?? this.currentGameElo,
      initialGameElo: initialGameElo ?? this.initialGameElo,
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
      consecutiveLosses: consecutiveLosses ?? this.consecutiveLosses,
      eloHistory: eloHistory ?? this.eloHistory,
      highestPuzzleRating: highestPuzzleRating ?? this.highestPuzzleRating,
      strongestBotEloBeaten:
          strongestBotEloBeaten ?? this.strongestBotEloBeaten,
      gamesAnalysed: gamesAnalysed ?? this.gamesAnalysed,
      maxWinStreak: maxWinStreak ?? this.maxWinStreak,
      bestEloDate: bestEloDate ?? this.bestEloDate,
      winsAsWhite: winsAsWhite ?? this.winsAsWhite,
      winsAsBlack: winsAsBlack ?? this.winsAsBlack,
      maxPuzzleStreak: maxPuzzleStreak ?? this.maxPuzzleStreak,
    );
  }
}

/// Statistics for a specific ELO level
class EloStats {
  final int wins;
  final int losses;
  final int draws;

  const EloStats({this.wins = 0, this.losses = 0, this.draws = 0});

  int get total => wins + losses + draws;

  double get winRate => total > 0 ? (wins / total) * 100 : 0;

  factory EloStats.fromMap(Map<String, dynamic> map) {
    return EloStats(
      wins: map['w'] as int? ?? 0,
      losses: map['l'] as int? ?? 0,
      draws: map['d'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'w': wins, 'l': losses, 'd': draws};
  }

  EloStats copyWith({int? wins, int? losses, int? draws}) {
    return EloStats(
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
    );
  }
}
