import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/models/statistics_model.dart';

void main() {
  group('Puzzle Continuation Logic Tests', () {
    test('Multi-move continuation replays moves up to the mistake index', () {
      // Puzzle moves:
      // 0: e2e4 (opponent setup move)
      // 1: e7e5 (player move 1 - correct)
      // 2: g1f3 (opponent response)
      // 3: b8c6 (player move 2 - expected)
      final puzzle = Puzzle(
        id: 1001,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
        rating: 1200,
        themes: ['opening'],
        searchableThemes: ['opening'],
        popularity: 90,
      );

      // Suppose user made a mistake on move 2 (targetIndex = 3)
      const targetIndex = 3;
      final board = chess.Chess.fromFEN(puzzle.fen);
      String? lastFrom;
      String? lastTo;

      for (int i = 0; i < targetIndex && i < puzzle.moves.length; i++) {
        final uci = puzzle.moves[i];
        final from = uci.substring(0, 2);
        final to = uci.substring(2, 4);
        final promotion = uci.length > 4 ? uci.substring(4, 5) : null;
        final ok = board.move({
          'from': from,
          'to': to,
          if (promotion != null) 'promotion': promotion,
        });
        expect(ok, isTrue);
        lastFrom = from;
        lastTo = to;
      }

      // Board is now in the state AFTER opponent's response (g1f3, move index 2)
      // It is Black's turn to play move index 3 (b8c6)
      expect(board.turn, equals(chess.Color.BLACK));
      expect(lastFrom, equals('g1'));
      expect(lastTo, equals('f3'));

      // Player move b8c6 is legal from this continuation position
      final legalMoves = board.moves({'verbose': true});
      final hasExpected = legalMoves.any((m) => m['to'] == 'c6');
      expect(hasExpected, isTrue);
    });
  });

  group('Statistics 400 Elo Baseline Tests', () {
    test('Default StatisticsModel starts at 400 Elo', () {
      const stats = StatisticsModel();
      expect(stats.currentGameElo, equals(400));
      expect(StatisticsModel.defaultGameElo, equals(400));
    });

    test('K-factor decays with games played (24 / 20 / 16)', () {
      expect(const StatisticsModel(totalGames: 0).kFactor, equals(24));
      expect(const StatisticsModel(totalGames: 9).kFactor, equals(24));
      expect(const StatisticsModel(totalGames: 10).kFactor, equals(20));
      expect(const StatisticsModel(totalGames: 29).kFactor, equals(20));
      expect(const StatisticsModel(totalGames: 30).kFactor, equals(16));
      expect(const StatisticsModel(totalGames: 200).kFactor, equals(16));
    });

    test('StatisticsModel.fromMap normalizes 0-game rows to 400', () {
      final map = {
        'total_games': 0,
        'current_game_elo': 1500, // Legacy row
      };
      final stats = StatisticsModel.fromMap(map);
      expect(stats.currentGameElo, equals(400));

      final map1000 = {
        'total_games': 0,
        'current_game_elo': 1000, // Legacy row
      };
      expect(
        StatisticsModel.fromMap(map1000).currentGameElo,
        equals(400),
      );

      // Played rows keep their real rating.
      final played = {'total_games': 5, 'current_game_elo': 520};
      expect(
        StatisticsModel.fromMap(played).currentGameElo,
        equals(520),
      );
    });

    test('EloSnapshot defaults to 400 Elo', () {
      final snapshot = EloSnapshot.fromMap({});
      expect(snapshot.elo, equals(400));
    });
  });
}
