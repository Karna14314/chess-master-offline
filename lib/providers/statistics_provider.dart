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
    bool? isPlayerWhite,
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
      strongestBotEloBeaten:
          isWin && botElo > state.strongestBotEloBeaten
              ? botElo
              : state.strongestBotEloBeaten,
      winsAsWhite:
          isWin && (isPlayerWhite ?? true)
              ? state.winsAsWhite + 1
              : state.winsAsWhite,
      winsAsBlack:
          isWin && !(isPlayerWhite ?? true)
              ? state.winsAsBlack + 1
              : state.winsAsBlack,
    );

    await _saveStatistics();
  }

  /// Record a completed full-game analysis.
  Future<void> recordGameAnalysed() async {
    state = state.copyWith(gamesAnalysed: state.gamesAnalysed + 1);
    await _saveStatistics();
  }

  /// Record game result with calibrated, sequential ELO calculation.
  ///
  /// Shape of the curve:
  /// - Standard FIDE expected score with a 400-point difference clamp.
  /// - K-factor from games played (40 provisional / 28 developing / 16
  ///   established), so new players place quickly instead of grinding.
  /// - Underdog bonus: beating stronger opposition accelerates the climb
  ///   toward their level, still bounded (no teleport leaps).
  /// - Anti-farming: beating far weaker bots yields nothing, so the only
  ///   way up is beating peers or stronger opponents.
  /// - Losses always dip but a single game can never plummet (bounded by K).
  Future<void> recordGameElo({
    required int botElo,
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
  }) async {
    // 1. Standard FIDE 400-point difference clamp prevents explosive rating jumps or deflation
    final rawDiff = (botElo - state.currentGameElo).clamp(-400, 400);
    final expectedScore = 1.0 / (1.0 + math.pow(10, rawDiff / 400));
    final actualScore =
        isWin
            ? 1.0
            : isDraw
            ? 0.5
            : 0.0;

    // 2. Calibrated K-factor (provisional: 40, developing: 28, established: 16)
    final k = state.kFactor;
    final provisional = state.isProvisional;
    int eloChange = (k * (actualScore - expectedScore)).round();

    // 3. Grounded sequential progression:
    if (isWin) {
      eloChange = eloChange.clamp(1, k);
      final gap = botElo - state.currentGameElo;
      if (gap > 0) {
        // Underdog bonus: +3 per 100 ELO of gap while provisional,
        // +2 once established — capped so progress stays sequential.
        final bonus = ((gap ~/ 100) * (provisional ? 3 : 2)).clamp(
          0,
          provisional ? 12 : 6,
        );
        eloChange = (eloChange + bonus).clamp(1, k + (provisional ? 12 : 6));
      } else {
        // Anti-farming: grinding far weaker bots yields no progress.
        final overmatch = -gap;
        if (overmatch >= 300) {
          eloChange = 0;
        } else if (overmatch >= 200) {
          eloChange = eloChange.clamp(0, 1);
        }
      }
    } else if (isLoss) {
      // Losses ALWAYS dip (at least -1, bounded by -K), ensuring rating is
      // never "always up" — but one game can never cause a plummet.
      eloChange = eloChange.clamp(-k, -1);
    } else if (isDraw) {
      eloChange = eloChange.clamp(-k ~/ 2, k ~/ 2);
    }

    final newElo = (state.currentGameElo + eloChange).clamp(100, 3200);

    final newConsecutiveWins = isWin ? state.consecutiveWins + 1 : 0;
    final newConsecutiveLosses = isLoss ? state.consecutiveLosses + 1 : 0;

    final newHistory = List<EloSnapshot>.from(state.eloHistory)..add(
      EloSnapshot(
        elo: newElo,
        gameNumber: state.totalGames > 0 ? state.totalGames : 1,
        timestamp: DateTime.now(),
      ),
    );

    // initialGameElo is seeded once (fresh default or onboarding skill
    // pick) and never rewritten by results — it anchors trend/progress UI.
    state = state.copyWith(
      currentGameElo: newElo,
      consecutiveWins: newConsecutiveWins,
      consecutiveLosses: newConsecutiveLosses,
      eloHistory: newHistory,
      maxWinStreak:
          newConsecutiveWins > state.maxWinStreak
              ? newConsecutiveWins
              : state.maxWinStreak,
      bestEloDate:
          newElo > state.bestElo
              ? DateTime.now().millisecondsSinceEpoch
              : state.bestEloDate,
    );

    await _saveStatistics();
  }

  /// Set the starting rating for fresh players (e.g. from onboarding skill
  /// selection). Only applies when no games have been recorded yet.
  Future<void> setStartingElo(int elo) async {
    if (state.totalGames > 0) return;
    final clamped = elo.clamp(100, 3200);
    state = state.copyWith(
      currentGameElo: clamped,
      initialGameElo: clamped,
    );
    await _saveStatistics();
  }

  /// Record hint usage
  Future<void> recordHintUsed() async {
    state = state.copyWith(hintsUsed: state.hintsUsed + 1);
    await _saveStatistics();
  }

  /// Record puzzle attempt with dynamic move-scaled rating adjustments
  Future<void> recordPuzzleAttempt({
    required bool solved,
    required int puzzleRating,
    int hintsUsed = 0,
    int currentStreak = 0,
    int totalPlayerMoves = 1,
    int correctPlayerMoves = 0,
  }) async {
    // Calculate new puzzle rating using dynamic move-scaled system
    int newRating = state.currentPuzzleRating;
    final ratingDiff = puzzleRating - state.currentPuzzleRating;
    final expectedScore = 1 / (1 + math.pow(10, -ratingDiff / 400));

    if (solved) {
      const baseK = 28;

      // Move-depth scaling: multi-move combinations require finding multiple correct tactics
      // 1 move: 1.0x, 2 moves: 1.15x, 3 moves: 1.30x, 4+ moves: up to 1.5x
      final moves = totalPlayerMoves.clamp(1, 5);
      final moveMultiplier = 1.0 + (moves - 1) * 0.15;

      // Streak bonus: consecutive solves give incremental boost
      final streakBonus =
          currentStreak >= 5 ? 4 : (currentStreak >= 3 ? 2 : 0);

      // Hints penalty: each hint reduces gain by 30%
      final hintFactor = math.max(0.25, 1.0 - (hintsUsed * 0.3));

      // Calculate rating gain with depth and streak bonuses
      int gain =
          (baseK * (1 - expectedScore) * moveMultiplier * hintFactor +
                  streakBonus)
              .round();

      // Ensure a rewarding minimum gain (+5 if no hints, +2 with hints)
      final minGain = hintsUsed > 0 ? 2 : 5;
      gain = math.max(minGain, gain);

      newRating += gain;
    } else {
      // When failed, consider partial credit if player found multiple correct moves in a multi-move puzzle
      const baseK = 24;
      double mitigation = 0.0;
      if (totalPlayerMoves > 1 && correctPlayerMoves > 0) {
        // Reduced loss if they found most of the tactical sequence (up to 45% mitigation)
        mitigation =
            (correctPlayerMoves / totalPlayerMoves).clamp(0.0, 0.9) * 0.45;
      }

      int penalty = (baseK * expectedScore * (1.0 - mitigation)).round();
      // Clamp loss so a single failed puzzle is never overly punishing
      penalty = penalty.clamp(4, 20);

      newRating -= penalty;
    }

    // Clamp rating between 400 and 3200
    newRating = newRating.clamp(400, 3200);

    state = state.copyWith(
      puzzlesAttempted: state.puzzlesAttempted + 1,
      puzzlesSolved: solved ? state.puzzlesSolved + 1 : state.puzzlesSolved,
      currentPuzzleRating: newRating,
      highestPuzzleRating:
          solved && newRating > state.highestPuzzleRating
              ? newRating
              : state.highestPuzzleRating,
      maxPuzzleStreak:
          currentStreak > state.maxPuzzleStreak
              ? currentStreak
              : state.maxPuzzleStreak,
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
