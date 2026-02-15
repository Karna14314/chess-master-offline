import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

void main() {
  group('StockfishService Parsing', () {
    test('parseInfoLine correctly parses standard info line', () {
      final line =
          'info depth 10 seldepth 15 multipv 1 score cp 45 nodes 1234 nps 5678 tbhits 0 time 12 pv e2e4 e7e5 g1f3 b8c6';
      final result = StockfishService.instance.parseInfoLine(line);

      expect(result.depth, 10);
      expect(result.multipv, 1);
      expect(result.cp, 45);
      expect(result.mate, null);
      expect(result.moves, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
    });

    test('parseInfoLine correctly parses mate score', () {
      final line =
          'info depth 20 multipv 1 score mate 3 nodes 999 pv f1c4 g8f6 f3g5 d7d5';
      final result = StockfishService.instance.parseInfoLine(line);

      expect(result.depth, 20);
      expect(
        result.cp,
        null,
      ); // score mate implies cp is usually not present or we prioritize mate parsing
      // Actually _parseValue looks for ' score cp '. If ' score mate ' is present, it parses mate.
      // In Stockfish output, usually it's either cp or mate.
      expect(result.mate, 3);
      expect(result.moves, ['f1c4', 'g8f6', 'f3g5', 'd7d5']);
    });

    test('parseInfoLine handles negative scores', () {
      final line = 'info depth 12 multipv 1 score cp -150 pv d2d4 d7d5 c2c4';
      final result = StockfishService.instance.parseInfoLine(line);

      expect(result.cp, -150);
    });

    test('parseInfoLine handles truncated output gracefully', () {
      final line = 'info depth 5';
      final result = StockfishService.instance.parseInfoLine(line);

      expect(result.depth, 5);
      expect(result.cp, null);
      expect(result.moves, null);
    });

    test('parseInfoLine correctly parses multipv > 1', () {
      final line = 'info depth 10 multipv 2 score cp 30 pv d2d4 d7d5';
      final result = StockfishService.instance.parseInfoLine(line);

      expect(result.multipv, 2);
      expect(result.cp, 30);
      expect(result.moves, ['d2d4', 'd7d5']);
    });
  });
}
