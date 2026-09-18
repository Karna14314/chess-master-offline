import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:chess_master/providers/statistics_provider.dart';

/// Regression tests for the rating progression overhaul:
/// - upset wins accelerate toward the beaten level (no hopeless grind),
/// - farming far weaker bots yields nothing,
/// - losses always dip but never plummet,
/// - stale legacy 1500/1000 defaults don't haunt barely-played profiles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rating progression (StatisticsNotifier)', () {
    test('Provisional upset win climbs meaningfully toward beaten level',
        () async {
      final notifier = StatisticsNotifier();
      // Allow async loadStatistics (DB unavailable in unit tests) to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.currentGameElo, equals(400));

      await notifier.recordGameElo(
        botElo: 1200,
        isWin: true,
        isLoss: false,
        isDraw: false,
      );

      final elo = notifier.state.currentGameElo;
      // Old behavior capped this at +22 (hopeless grind to 1200);
      // new behavior accelerates but stays bounded (K=40 + max bonus 12).
      expect(elo, greaterThan(422));
      expect(elo, lessThanOrEqualTo(452));
    });

    test('Farming far weaker bots yields no progress', () async {
      final notifier = StatisticsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Climb by beating slightly stronger opposition until established.
      for (int i = 0; i < 35; i++) {
        final current = notifier.state.currentGameElo;
        await notifier.recordGameResult(
          isWin: true,
          isLoss: false,
          isDraw: false,
          botElo: current + 100,
          moveCount: 40,
          gameTimeSeconds: 600,
        );
        await notifier.recordGameElo(
          botElo: current + 100,
          isWin: true,
          isLoss: false,
          isDraw: false,
        );
      }
      expect(notifier.state.totalGames, equals(35));
      final climbed = notifier.state.currentGameElo;
      expect(climbed - 400, greaterThanOrEqualTo(300));

      // Grinding 400-rated bots now yields nothing.
      await notifier.recordGameElo(
        botElo: 400,
        isWin: true,
        isLoss: false,
        isDraw: false,
      );
      expect(notifier.state.currentGameElo, equals(climbed));
    });

    test('Losses always dip but a single game never plummets', () async {
      final notifier = StatisticsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.recordGameElo(
        botElo: 1200,
        isWin: false,
        isLoss: true,
        isDraw: false,
      );
      final afterUpsetLoss = notifier.state.currentGameElo;
      expect(afterUpsetLoss, lessThan(400)); // always dips
      expect(afterUpsetLoss, greaterThanOrEqualTo(400 - 40)); // never plummets
    });

    test('Equal-strength win still grants healthy provisional gain', () async {
      final notifier = StatisticsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.recordGameElo(
        botElo: 400,
        isWin: true,
        isLoss: false,
        isDraw: false,
      );
      // K=40 provisional: 40 * (1 - 0.5) = +20, no bonus, no farm penalty.
      expect(notifier.state.currentGameElo, equals(420));
    });
  });

  group('Legacy rating defaults (StatisticsModel.fromMap)', () {
    test('Barely-played profile stuck at legacy 1500 resets to baseline',
        () {
      final stats = StatisticsModel.fromMap({
        'total_games': 3,
        'current_game_elo': 1500,
      });
      expect(stats.currentGameElo, equals(400));
    });

    test('Onboarding seed survives legacy-default normalization', () {
      final stats = StatisticsModel.fromMap({
        'total_games': 0,
        'current_game_elo': 1500,
        'initial_game_elo': 800,
      });
      expect(stats.currentGameElo, equals(800));
    });

    test('Real recorded history is never normalized away', () {
      final stats = StatisticsModel.fromMap({
        'total_games': 5,
        'current_game_elo': 1500,
        'elo_history':
            '[{"elo": 1480, "gameNumber": 4, "timestamp": 1700000000000},'
            '{"elo": 1500, "gameNumber": 5, "timestamp": 1700000100000}]',
      });
      expect(stats.currentGameElo, equals(1500));
    });
  });
}
