import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/models/campaign_model.dart';

void main() {
  group('BotProfile Roster Tests', () {
    test('Should have at least 20 unique bot personalities', () {
      expect(BotProfile.allBots.length, greaterThanOrEqualTo(20));

      final uniqueIds = BotProfile.allBots.map((b) => b.id).toSet();
      expect(uniqueIds.length, equals(BotProfile.allBots.length));

      final uniqueNames = BotProfile.allBots.map((b) => b.name).toSet();
      expect(uniqueNames.length, equals(BotProfile.allBots.length));
    });

    test('All bots have valid ELOs spanning from 400 to 2800+', () {
      final minElo = BotProfile.allBots.map((b) => b.elo).reduce((a, b) => a < b ? a : b);
      final maxElo = BotProfile.allBots.map((b) => b.elo).reduce((a, b) => a > b ? a : b);

      expect(minElo, equals(400));
      expect(maxElo, greaterThanOrEqualTo(2800));
    });

    test('Engine routing: sub-1300 bots use SimpleBot, 1300+ use Stockfish', () {
      for (final bot in BotProfile.allBots) {
        if (bot.elo < 1300) {
          expect(
            bot.engineType,
            equals(BotType.simple),
            reason: '${bot.name} (${bot.elo} ELO) must use BotType.simple',
          );
          expect(bot.isHeuristicBot, isTrue);
          expect(bot.blunderRate, greaterThan(0.0));
        } else {
          expect(
            bot.engineType,
            equals(BotType.stockfish),
            reason: '${bot.name} (${bot.elo} ELO) must use BotType.stockfish',
          );
          expect(bot.isHeuristicBot, isFalse);
        }
      }
    });

    test('Each bot has dialogue and style tags', () {
      for (final bot in BotProfile.allBots) {
        expect(bot.bio, isNotEmpty);
        expect(bot.quote, isNotEmpty);
        expect(bot.styleTags, isNotEmpty);
        expect(bot.dialogue.greeting, isNotEmpty);
        expect(bot.avatarGradient.length, equals(2));
      }
    });

    test('getClosestToElo finds the closest matching bot', () {
      final bot450 = BotProfile.getClosestToElo(450);
      expect(bot450.elo, anyOf(equals(400), equals(500)));

      final bot1300 = BotProfile.getClosestToElo(1300);
      expect(bot1300.elo, anyOf(equals(1250), equals(1350)));

      final botMaster = BotProfile.getClosestToElo(2700);
      expect(botMaster.elo, anyOf(equals(2600), equals(2850)));
    });
  });

  group('12-Level Master Campaign Tests', () {
    test('Should have exactly 12 sequential levels', () {
      expect(CampaignLevel.allLevels.length, equals(12));

      for (int i = 0; i < 12; i++) {
        expect(CampaignLevel.allLevels[i].levelNumber, equals(i + 1));
      }
    });

    test('All campaign bots exist in BotProfile registry', () {
      for (final level in CampaignLevel.allLevels) {
        final bot = level.bot;
        expect(bot.id, equals(level.botId));
        expect(bot.name, isNotEmpty);
      }
    });

    test('Campaign difficulty is non-decreasing', () {
      for (int i = 1; i < CampaignLevel.allLevels.length; i++) {
        final prev = CampaignLevel.allLevels[i - 1];
        final curr = CampaignLevel.allLevels[i];
        expect(curr.targetElo, greaterThanOrEqualTo(prev.targetElo));
      }
    });
  });
}
