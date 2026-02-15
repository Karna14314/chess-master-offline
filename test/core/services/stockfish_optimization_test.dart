import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

void main() {
  test('StockfishParser.parse correctly parses standard Stockfish output', () {
    final line =
        'info depth 20 seldepth 30 multipv 1 score cp 55 nodes 1000 nps 500000 pv e2e4 e7e5 g1f3 b8c6';

    final result = StockfishParser.parse(line);

    expect(result.depth, 20);
    expect(result.cp, 55);
    expect(result.mate, null);
    expect(result.moves, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
  });

  test('StockfishParser.parse handles mate score', () {
    final line = 'info depth 22 score mate 5 pv f3e5 d8h4 g2g3';
    final result = StockfishParser.parse(line);

    expect(result.depth, 22);
    expect(result.cp, null);
    expect(result.mate, 5);
    expect(result.moves, ['f3e5', 'd8h4', 'g2g3']);
  });

  test('StockfishParser.parse handles maxMoves optimization', () {
    final line = 'info depth 20 score cp 10 pv e2e4 e7e5 g1f3 b8c6';

    // We want to test that we can limit parsed moves
    // Note: StockfishParser.parse signature might need to be verified if I exposed maxMoves
    // In my previous step I did: static AnalysisInfo parse(String line, {int? maxMoves})

    final result = StockfishParser.parse(line, maxMoves: 1);

    expect(result.moves.length, 1);
    expect(result.moves.first, 'e2e4');
  });

  test('StockfishParser.parse handles empty or malformed input gracefully', () {
    expect(StockfishParser.parse('random string').depth, null);
    expect(StockfishParser.parse('').depth, null);
  });
}
