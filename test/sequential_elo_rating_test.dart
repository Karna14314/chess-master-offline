import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'dart:math' as math;

void main() {
  group('Sequential Elo Rating System Tests', () {
    test('Provisional Novice (400) beating 1200 bot gains sequential bounded rating (+22 max, no 40+ leap)', () {
      const playerElo = 400;
      const botElo = 1200;
      const kFactor = 24; // Provisional K

      final rawDiff = (botElo - playerElo).clamp(-400, 400);
      expect(rawDiff, 400);

      final expectedScore = 1.0 / (1.0 + math.pow(10, rawDiff / 400));
      // expectedScore = 1 / (1 + 10) = 1/11 ≈ 0.0909
      final actualScore = 1.0;
      int eloChange = (kFactor * (actualScore - expectedScore)).round();
      eloChange = eloChange.clamp(1, kFactor);

      expect(eloChange, 22);
      expect(playerElo + eloChange, 422);
      // Ensure it is sequentially bounded and NOT a 40+ leap
      expect(eloChange, lessThanOrEqualTo(24));
    });

    test('Novice (400) losing to 1200 bot realistically dips rating by -2 (not always up)', () {
      const playerElo = 400;
      const botElo = 1200;
      const kFactor = 24;

      final rawDiff = (botElo - playerElo).clamp(-400, 400);
      final expectedScore = 1.0 / (1.0 + math.pow(10, rawDiff / 400));
      final actualScore = 0.0;
      int eloChange = (kFactor * (actualScore - expectedScore)).round();
      eloChange = eloChange.clamp(-kFactor, -1);

      expect(eloChange, -2);
      expect(playerElo + eloChange, 398);
      // Guarantees rating dips on every defeat
      expect(eloChange, lessThan(0));
    });

    test('Equal matchup (400 vs 400): win awards +12, loss dips -12', () {
      const playerElo = 400;
      const botElo = 400;
      const kFactor = 24;

      final rawDiff = (botElo - playerElo).clamp(-400, 400);
      final expectedScore = 1.0 / (1.0 + math.pow(10, rawDiff / 400));
      expect(expectedScore, 0.5);

      // Win
      int winChange = (kFactor * (1.0 - expectedScore)).round().clamp(1, kFactor);
      expect(winChange, 12);

      // Loss
      int lossChange = (kFactor * (0.0 - expectedScore)).round().clamp(-kFactor, -1);
      expect(lossChange, -12);
    });

    test('Higher rated player (1200) beating 400 bot receives minimal gain (+1), preventing farming', () {
      const playerElo = 1200;
      const botElo = 400;
      const kFactor = 16; // Established K

      final rawDiff = (botElo - playerElo).clamp(-400, 400);
      final expectedScore = 1.0 / (1.0 + math.pow(10, rawDiff / 400));
      // rawDiff = -400, expectedScore = 1 / (1 + 0.1) = 1/1.1 ≈ 0.9091
      int winChange = (kFactor * (1.0 - expectedScore)).round().clamp(1, kFactor);

      expect(winChange, 1);
      expect(winChange, lessThan(5)); // No free +10 farming!
    });

    test('Higher rated player (1200) losing to 400 bot suffers significant dip (-15)', () {
      const playerElo = 1200;
      const botElo = 400;
      const kFactor = 16;

      final rawDiff = (botElo - playerElo).clamp(-400, 400);
      final expectedScore = 1.0 / (1.0 + math.pow(10, rawDiff / 400));
      int lossChange = (kFactor * (0.0 - expectedScore)).round().clamp(-kFactor, -1);

      expect(lossChange, -15);
      expect(playerElo + lossChange, 1185);
    });

    test('StatisticsModel persists and restores initialGameElo correctly', () {
      final stats = const StatisticsModel(
        currentGameElo: 850,
        initialGameElo: 800,
        totalGames: 5,
        wins: 4,
        losses: 1,
      );

      final map = stats.toMap();
      expect(map['initial_game_elo'], 800);
      expect(map['current_game_elo'], 850);

      final restored = StatisticsModel.fromMap(map);
      expect(restored.initialGameElo, 800);
      expect(restored.currentGameElo, 850);
    });

    test('nextTierProgress calculates milestones and progress fractions accurately', () {
      const stats450 = StatisticsModel(currentGameElo: 450);
      final progress450 = stats450.nextTierProgress;
      expect(progress450, isNotNull);
      expect(progress450!.$1, 'Apprentice'); // target tier
      expect(progress450.$2, 700); // target elo
      expect(progress450.$3, 250); // points needed: 700 - 450
      expect(progress450.$4, closeTo(50 / 300, 0.01)); // progress fraction

      const stats1050 = StatisticsModel(currentGameElo: 1050);
      final progress1050 = stats1050.nextTierProgress;
      expect(progress1050, isNotNull);
      expect(progress1050!.$1, 'Intermediate');
      expect(progress1050.$2, 1400);
      expect(progress1050.$3, 350);
    });

    test('eloTrend evaluates velocity from baseline when under 10 games', () {
      final history = [
        EloSnapshot(elo: 418, gameNumber: 1, timestamp: DateTime.now()),
      ];
      final stats = StatisticsModel(
        initialGameElo: 400,
        currentGameElo: 418,
        totalGames: 1,
        eloHistory: history,
      );

      expect(stats.eloTrend, 18);
    });
  });

  group('Bot Arena Preview Verification', () {
    test('Curated preview bots all exist, start from mid-800, and are in ascending rating order', () {
      final previewBotIds = [
        'bot_aaron',  // 850
        'bot_timmy',  // 950
        'bot_maya',   // 1050
        'bot_viktor', // 1150
        'bot_elena',  // 1250
        'bot_felix',  // 1350
        'bot_marcus', // 1550
        'bot_sophia', // 1700
      ];

      final bots = previewBotIds.map((id) => BotProfile.getById(id)).toList();

      // Ensure no fallbacks to Rusty (id: bot_rusty)
      for (final bot in bots) {
        expect(bot.id, isNot('bot_rusty'));
      }

      // First bot must be in mid-800
      expect(bots.first.elo, 850);
      expect(bots.first.name, contains('Aaron'));

      // Ensure ratings are strictly ascending
      for (int i = 0; i < bots.length - 1; i++) {
        expect(
          bots[i + 1].elo,
          greaterThan(bots[i].elo),
          reason: '${bots[i + 1].name} (${bots[i + 1].elo}) should be higher than ${bots[i].name} (${bots[i].elo})',
        );
      }
    });
  });
}
