import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BotStats Model Tests', () {
    test('Default stats have zero games and zero stars', () {
      const stats = BotStats();
      expect(stats.wins, equals(0));
      expect(stats.draws, equals(0));
      expect(stats.losses, equals(0));
      expect(stats.totalGames, equals(0));
      expect(stats.hasBeaten, isFalse);
      expect(stats.bestStars, equals(0));
    });

    test('Json serialization round-trip preserves values', () {
      const stats = BotStats(wins: 5, draws: 2, losses: 1, bestStars: 3);
      final json = stats.toJson();
      final revived = BotStats.fromJson(json);

      expect(revived.wins, equals(5));
      expect(revived.draws, equals(2));
      expect(revived.losses, equals(1));
      expect(revived.totalGames, equals(8));
      expect(revived.hasBeaten, isTrue);
      expect(revived.bestStars, equals(3));
    });
  });

  group('BotProgressNotifier Tests', () {
    test('Winning as White without assists earns 2 stars', () async {
      final notifier = BotProgressNotifier();
      await notifier.loadProgress();

      await notifier.recordBotMatch(
        botId: 'bot_rusty',
        result: GameResult.whiteWins,
        isPlayerWhite: true,
        usedTakebacks: false,
        hintsUsed: 0,
      );

      final stats = notifier.state.getStatsFor('bot_rusty');
      expect(stats.wins, equals(1));
      expect(stats.losses, equals(0));
      expect(stats.bestStars, equals(2));
      expect(notifier.state.totalBotStars, equals(2));
    });

    test('Winning as Black with 0 assists earns 3 stars (Max Crown)', () async {
      final notifier = BotProgressNotifier();
      await notifier.loadProgress();

      await notifier.recordBotMatch(
        botId: 'bot_clara',
        result: GameResult.blackWins,
        isPlayerWhite: false,
        usedTakebacks: false,
        hintsUsed: 0,
      );

      final stats = notifier.state.getStatsFor('bot_clara');
      expect(stats.wins, equals(1));
      expect(stats.bestStars, equals(3));
    });

    test('Campaign progression unlocks next level upon winning', () async {
      final notifier = BotProgressNotifier();
      await notifier.loadProgress();

      expect(notifier.state.campaignUnlockedLevel, equals(1));
      expect(notifier.state.isCampaignLevelUnlocked(1), isTrue);
      expect(notifier.state.isCampaignLevelUnlocked(2), isFalse);

      // Win Level 1
      await notifier.recordCampaignMatch(
        levelNumber: 1,
        result: GameResult.whiteWins,
        isPlayerWhite: true,
        usedTakebacks: false,
        hintsUsed: 0,
      );

      expect(notifier.state.campaignUnlockedLevel, equals(2));
      expect(notifier.state.isCampaignLevelUnlocked(2), isTrue);
      expect(notifier.state.campaignStars[1], equals(2));
    });
  });
}
