import 'dart:convert';
import 'dart:math' as math;

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
      elo: map['elo'] as int? ?? 1500,
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
  final int consecutiveWins;
  final int consecutiveLosses;
  final List<EloSnapshot> eloHistory;
  static const int provisionalGames = 10;
  static const int defaultGameElo = 1500;

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
    this.consecutiveWins = 0,
    this.consecutiveLosses = 0,
    this.eloHistory = const [],
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

  /// Whether the player is still in provisional period
  bool get isProvisional => totalGames < provisionalGames;

  /// Current K-factor based on provisional status
  int get kFactor => isProvisional ? 40 : 32;

  /// ELO trend over last N games (positive = improving)
  int get eloTrend {
    if (eloHistory.length < 2) return 0;
    final recent = eloHistory.length > 10 ? eloHistory.sublist(eloHistory.length - 10) : eloHistory;
    return recent.last.elo - recent.first.elo;
  }

  /// Best ELO achieved
  int get bestElo {
    if (eloHistory.isEmpty) return currentGameElo;
    return math.max(currentGameElo, eloHistory.map((e) => e.elo).reduce(math.max));
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
        eloHistory = decoded
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
      currentGameElo: map['current_game_elo'] as int? ?? defaultGameElo,
      consecutiveWins: map['consecutive_wins'] as int? ?? 0,
      consecutiveLosses: map['consecutive_losses'] as int? ?? 0,
      eloHistory: eloHistory,
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
      'consecutive_wins': consecutiveWins,
      'consecutive_losses': consecutiveLosses,
      'elo_history': jsonEncode(eloHistory.map((e) => e.toMap()).toList()),
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
    int? consecutiveWins,
    int? consecutiveLosses,
    List<EloSnapshot>? eloHistory,
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
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
      consecutiveLosses: consecutiveLosses ?? this.consecutiveLosses,
      eloHistory: eloHistory ?? this.eloHistory,
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
