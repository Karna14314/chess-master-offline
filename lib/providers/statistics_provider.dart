import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:chess_master/core/services/database_service.dart';

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

  /// Record hint usage
  Future<void> recordHintUsed() async {
    state = state.copyWith(hintsUsed: state.hintsUsed + 1);
    await _saveStatistics();
  }

  /// Record puzzle attempt
  Future<void> recordPuzzleAttempt({
    required bool solved,
    required int puzzleRating,
  }) async {
    // Calculate new puzzle rating using ELO-like system
    int newRating = state.currentPuzzleRating;
    const k = 32; // K-factor for rating changes

    if (solved) {
      // Increase rating more if solved harder puzzle
      final ratingDiff = puzzleRating - state.currentPuzzleRating;
      final expectedScore = 1 / (1 + pow(10, -ratingDiff / 400));
      newRating += (k * (1 - expectedScore)).round();
    } else {
      // Decrease rating less if failed harder puzzle
      final ratingDiff = puzzleRating - state.currentPuzzleRating;
      final expectedScore = 1 / (1 + pow(10, -ratingDiff / 400));
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
}

/// Power function for ELO calculations
double pow(double base, double exp) {
  double result = 1;
  int intExp = exp.abs().round();
  for (int i = 0; i < intExp; i++) {
    result *= base;
  }
  return exp < 0 ? 1 / result : result;
}
