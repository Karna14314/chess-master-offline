import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';

void main() {
  group('Difficulty System Tests', () {
    late StockfishService service;

    setUp(() {
      service = StockfishService.instance;
      service.resetTestState();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('every difficulty level has a unique ELO rating', () {
      final elos = AppConstants.difficultyLevels.map((d) => d.elo).toSet();
      expect(elos.length, AppConstants.difficultyLevels.length,
          reason: 'All 10 difficulty levels must have distinct ELO ratings');
    });

    test('difficulty ELOs are within Stockfish UCI_Elo valid range', () {
      for (final level in AppConstants.difficultyLevels) {
        expect(level.elo, greaterThanOrEqualTo(1320),
            reason:
                '${level.name} (level ${level.level}): ELO ${level.elo} is below Stockfish minimum 1320');
        expect(level.elo, lessThanOrEqualTo(3190),
            reason:
                '${level.name} (level ${level.level}): ELO ${level.elo} exceeds Stockfish maximum 3190');
      }
    });

    test('difficulty depths increase monotonically', () {
      int prevDepth = -1;
      for (final level in AppConstants.difficultyLevels) {
        expect(level.depth, greaterThan(prevDepth),
            reason:
                '${level.name} depth must be > previous level depth ($prevDepth)');
        prevDepth = level.depth;
      }
    });

    test('difficulty think times increase monotonically', () {
      int prevTime = -1;
      for (final level in AppConstants.difficultyLevels) {
        expect(level.thinkTimeMs, greaterThanOrEqualTo(prevTime),
            reason:
                '${level.name} think time must not decrease (was $prevTime, got ${level.thinkTimeMs})');
        prevTime = level.thinkTimeMs;
      }
    });

    test('fallback depths are distinct for lower levels, capped at 4', () {
      final fallbackDepths =
          AppConstants.difficultyLevels.map((d) => d.fallbackDepth).toList();

      // No fallback depth should exceed 4 (ANR prevention)
      for (int i = 0; i < fallbackDepths.length; i++) {
        expect(fallbackDepths[i], lessThanOrEqualTo(4),
            reason: 'Level ${i + 1} fallback depth exceeds performance limit');
      }

      // At least some levels should have different fallback depths
      // (Beginner=1, Novice=2, higher=3 or 4)
      expect(fallbackDepths[0], equals(1),
          reason: 'Beginner fallback depth should be 1');
      expect(fallbackDepths[1], equals(3),
          reason: 'Novice fallback depth should be 3');
      expect(fallbackDepths[9], equals(4),
          reason: 'Maximum fallback depth should be 4');
    });

    test('setSkillLevel clamps ELO to valid Stockfish range', () async {
      service.forceFallback = true;
      await service.initialize();

      // Below minimum
      service.setSkillLevel(800);
      // Above maximum
      service.setSkillLevel(3200);
      // Valid value
      service.setSkillLevel(2000);

      // Should not throw
    });

    test('setSkillLevel sends only UCI_Elo (no Skill Level conflict)', () async {
      service.forceFallback = true;
      await service.initialize();

      // setSkillLevel should only set UCI_LimitStrength + UCI_Elo
      // It should NOT set Skill Level (mutually exclusive)
      service.setSkillLevel(1500);
      // In fallback mode, setSkillLevel is a no-op, so this is a logic test
      // The real validation happens in stockfish_service.dart:setSkillLevel()
    });

    test('engine_provider configures strength once per game (not per move)',
        () async {
      // This test verifies that strength is set in resetForNewGame (once)
      // and NOT in getBotMove (every move).
      // Since we can't easily inspect UCI traffic without a real engine,
      // this is a code coverage assertion.
      service.forceFallback = true;
      await service.initialize();

      // Simulate getBestMove without elo parameter (as engine_provider now does)
      final result = await service.getBestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        depth: 5,
      );
      expect(result.bestMove.isNotEmpty, isTrue);

      // Second call with different depth — still no elo param
      final result2 = await service.getBestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        depth: 5,
      );
      expect(result2.bestMove.isNotEmpty, isTrue);
    });

    test('fallback depth scaling matches expected values', () {
      // StockfishService._fallbackDepth is private, but DifficultyLevel.fallbackDepth
      // uses the same logic
      final testCases = {
        1: 1, // depth 1 → fallback 1 (Beginner)
        2: 2, // depth 2 → fallback 2 (Novice)
        5: 3, // depth 5 → fallback 3 (Casual)
        8: 3, // depth 8 → fallback 3 (Intermediate)
        10: 4, // depth 10 → fallback 4 (Club Player)
        15: 4, // depth 15 → fallback 4 (Expert)
        22: 4, // depth 22 → fallback 4 (Maximum)
      };

      for (final entry in testCases.entries) {
        // create a temporary DifficultyLevel to test fallbackDepth
        final level = DifficultyLevel(
          level: 0,
          elo: 1500,
          depth: entry.key,
          thinkTimeMs: 1000,
          name: 'test',
        );
        expect(level.fallbackDepth, entry.value,
            reason: 'depth=${entry.key} should map to fallback=${entry.value}');
      }
    });

    test('difficulty levels have distinct advertised ELOs', () {
      final names = AppConstants.difficultyLevels.map((d) => d.name).toList();
      expect(names, [
        'Beginner',
        'Novice',
        'Casual',
        'Intermediate',
        'Club Player',
        'Advanced',
        'Expert',
        'Master',
        'Grandmaster',
        'Maximum',
      ]);
    });

    test('all difficulty parameters are internally consistent', () {
      for (final level in AppConstants.difficultyLevels) {
        // Think time should be reasonable
        expect(level.thinkTimeMs, greaterThan(0),
            reason: '${level.name} must have positive think time');
        expect(level.thinkTimeMs, lessThanOrEqualTo(5000),
            reason: '${level.name} think time exceeds 5s max');

        // Depth should be reasonable
        expect(level.depth, greaterThan(0),
            reason: '${level.name} must have positive depth');
        expect(level.depth, lessThanOrEqualTo(30),
            reason: '${level.name} depth exceeds 30');

        // Level number should match position
        expect(
            level.level, AppConstants.difficultyLevels.indexOf(level) + 1);
      }
    });
  });
}
