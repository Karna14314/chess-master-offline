import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Provider for user statistics
final statisticsProvider =
    StateNotifierProvider<StatisticsNotifier, StatisticsModel>((ref) {
      return StatisticsNotifier();
    });

/// Statistics state notifier
class StatisticsNotifier extends StateNotifier<StatisticsModel> {
  final DatabaseService _db = DatabaseService.instance;

  StatisticsNotifier() : super(const StatisticsModel()) {
    loadStatistics();
  }

  /// Load statistics from database
  Future<void> loadStatistics() async {
    try {
      final statsMap = await _db.getStatistics();
      if (statsMap != null) {
        state = StatisticsModel.fromMap(statsMap);
      }
    } catch (e) {
      // Keep default state on error
    }
  }

  /// Save statistics to database
  Future<void> _saveStatistics() async {
    try {
      await _db.updateStatistics(state.toMap());
    } catch (e) {
      // Handle error silently
    }
  }

  /// Record a game result
  Future<void> recordGameResult({
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
    required int botElo,
    required int moveCount,
    required int gameTimeSeconds,
    String? openingName,
  }) async {
    // Update ELO-specific stats
    final newGamesByElo = Map<int, EloStats>.from(state.gamesByElo);
    final existingStats = newGamesByElo[botElo] ?? const EloStats();
    newGamesByElo[botElo] = existingStats.copyWith(
      wins: isWin ? existingStats.wins + 1 : existingStats.wins,
      losses: isLoss ? existingStats.losses + 1 : existingStats.losses,
      draws: isDraw ? existingStats.draws + 1 : existingStats.draws,
    );

    // Update openings played
    final newOpeningsPlayed = Map<String, int>.from(state.openingsPlayed);
    if (openingName != null && openingName.isNotEmpty) {
      newOpeningsPlayed[openingName] =
          (newOpeningsPlayed[openingName] ?? 0) + 1;
    }

    state = state.copyWith(
      totalGames: state.totalGames + 1,
      wins: isWin ? state.wins + 1 : state.wins,
      losses: isLoss ? state.losses + 1 : state.losses,
      draws: isDraw ? state.draws + 1 : state.draws,
      gamesByElo: newGamesByElo,
      openingsPlayed: newOpeningsPlayed,
      totalMoves: state.totalMoves + moveCount,
      totalGameTimeSeconds: state.totalGameTimeSeconds + gameTimeSeconds,
    );

    await _saveStatistics();
  }

  /// Record game result with ELO calculation
  Future<void> recordGameElo({
    required int botElo,
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
  }) async {
    final expectedScore =
        1.0 / (1.0 + math.pow(10, (botElo - state.currentGameElo) / 400));
    final actualScore =
        isWin
            ? 1.0
            : isDraw
            ? 0.5
            : 0.0;

    final eloChange = (state.kFactor * (actualScore - expectedScore)).round();
    final newElo = (state.currentGameElo + eloChange).clamp(100, 3200);

    final newConsecutiveWins = isWin ? state.consecutiveWins + 1 : 0;
    final newConsecutiveLosses = isLoss ? state.consecutiveLosses + 1 : 0;

    final newHistory = List<EloSnapshot>.from(state.eloHistory)..add(
      EloSnapshot(
        elo: newElo,
        gameNumber: state.totalGames + 1,
        timestamp: DateTime.now(),
      ),
    );

    state = state.copyWith(
      currentGameElo: newElo,
      consecutiveWins: newConsecutiveWins,
      consecutiveLosses: newConsecutiveLosses,
      eloHistory: newHistory,
    );

    await _saveStatistics();
  }

  /// Record hint usage
  Future<void> recordHintUsed() async {
    state = state.copyWith(hintsUsed: state.hintsUsed + 1);
    await _saveStatistics();
  }

  /// Record puzzle attempt
  Future<void> recordPuzzleAttempt({
    required bool solved,
    required int puzzleRating,
    int hintsUsed = 0,
  }) async {
    // Calculate new puzzle rating using ELO-like system
    int newRating = state.currentPuzzleRating;
    const k = 32; // K-factor for rating changes

    if (solved) {
      final ratingDiff = puzzleRating - state.currentPuzzleRating;
      final expectedScore = 1 / (1 + math.pow(10, -ratingDiff / 400));
      int change = (k * (1 - expectedScore)).round();
      if (hintsUsed > 0) {
        change = (change * 0.5).round();
      }
      newRating += change;
    } else {
      final ratingDiff = puzzleRating - state.currentPuzzleRating;
      final expectedScore = 1 / (1 + math.pow(10, -ratingDiff / 400));
      newRating += (k * (0 - expectedScore)).round();
    }

    // Clamp rating between 400 and 3200
    newRating = newRating.clamp(400, 3200);

    state = state.copyWith(
      puzzlesAttempted: state.puzzlesAttempted + 1,
      puzzlesSolved: solved ? state.puzzlesSolved + 1 : state.puzzlesSolved,
      currentPuzzleRating: newRating,
    );

    await _saveStatistics();
  }

  /// Reset all statistics
  Future<void> resetStatistics() async {
    state = const StatisticsModel();
    await _saveStatistics();
  }

  /// Get the recommended difficulty level based on player ELO.
  /// Returns the closest difficulty level to the player's current ELO.
  DifficultyLevel getRecommendedDifficulty() {
    return AppConstants.difficultyLevels.reduce(
      (a, b) =>
          (a.elo - state.currentGameElo).abs() <
                  (b.elo - state.currentGameElo).abs()
              ? a
              : b,
    );
  }

  /// Get a suggestion message based on recent performance.
  String? getDifficultySuggestion() {
    if (state.consecutiveWins >= 3) {
      final nextLevel = AppConstants.difficultyLevels.firstWhere(
        (d) => d.elo > state.currentGameElo,
        orElse: () => AppConstants.difficultyLevels.last,
      );
      return "You're on a ${state.consecutiveWins}-game win streak! Try ${nextLevel.name} (${nextLevel.elo} ELO)?";
    }
    if (state.consecutiveLosses >= 3) {
      final prevLevel = AppConstants.difficultyLevels.lastWhere(
        (d) => d.elo < state.currentGameElo,
        orElse: () => AppConstants.difficultyLevels.first,
      );
      return "Tough losses. Try ${prevLevel.name} (${prevLevel.elo} ELO) to build confidence?";
    }
    return null;
  }
}
