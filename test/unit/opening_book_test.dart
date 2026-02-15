import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/opening_book_service.dart';

void main() {
  group('OpeningBookService', () {
    test('getMove returns move for starting position', () {
      final fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final move = OpeningBookService.instance.getMove(fen);

      expect(move, isNotNull);
      expect(['e2e4', 'd2d4', 'g1f3', 'c2c4'], contains(move));
    });

    test('getMove handles transpositions (different move counts)', () {
      // Starting position but with weird move counts
      final fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 10 15';
      final move = OpeningBookService.instance.getMove(fen);

      expect(move, isNotNull);
    });

    test('getMove handles position after 1. e4', () {
      final fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
      final move = OpeningBookService.instance.getMove(fen);

      expect(move, isNotNull);
      expect(['e7e5', 'c7c5', 'e7e6', 'c7c6', 'd7d6'], contains(move));
    });

    test('getMove handles position after 1. e4 e5', () {
      final fen =
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1';
      final move = OpeningBookService.instance.getMove(fen);

      expect(move, isNotNull);
    });

    test('getMove returns null for unknown position', () {
      // Empty board (impossible but good for test)
      final fen = '8/8/8/8/8/8/8/8 w - - 0 1';
      final move = OpeningBookService.instance.getMove(fen);

      expect(move, isNull);
    });
  });
}
