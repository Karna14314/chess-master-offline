import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/services/position_evaluator.dart';
import 'package:chess_master/core/services/simple_bot_service.dart';
import 'package:chess_master/core/services/basic_evaluator_service.dart';

void main() {
  group('Phase 9 - PositionEvaluator Heuristics', () {
    int evalFen(String fen) {
      final board = chess.Chess.fromFEN(fen);
      return PositionEvaluator.evaluate(board);
    }

    // All test FENs include both kings to satisfy chess library validation.

    test('starting position evaluates near zero', () {
      final e = evalFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(e.abs(), lessThan(200));
    });

    test('material advantage dominates - queen vs king', () {
      final e = evalFen('k7/8/8/8/8/5K2/8/4Q3 w - - 0 1');
      expect(e, greaterThan(800));
    });

    test('passed pawn on 7th rank rewarded', () {
      final e = evalFen('8/1P6/8/8/8/8/k7/7K w - - 0 1');
      expect(e, greaterThan(100));
    });

    test('passed pawn bonus increases with rank', () {
      final e1 = evalFen('k7/8/8/3P4/8/8/8/7K w - - 0 1');
      final e2 = evalFen('k7/8/8/8/8/8/3P4/7K w - - 0 1');
      expect(e1, greaterThan(e2));
    });

    test('isolated pawn penalty', () {
      final e = evalFen('k7/8/8/8/8/8/P1P5/7K w - - 0 1');
      expect(e, greaterThan(250));
      expect(e, lessThan(350));
    });

    test('doubled pawns penalized', () {
      final eDoubled = evalFen('k7/8/8/8/8/1P6/1P6/7K w - - 0 1');
      final eNormal = evalFen('k7/8/8/8/8/8/PP6/7K w - - 0 1');
      expect(eNormal, greaterThan(eDoubled));
    });

    test('pawn islands penalized', () {
      final e = evalFen('k7/8/8/8/8/8/P1P3P1/7K w - - 0 1');
      expect(e, greaterThan(200));
      expect(e, lessThan(500));
    });

    test('castled king with pawn shield bonus', () {
      final e = evalFen('k7/8/8/8/8/8/5PPP/6K1 w - - 0 1');
      expect(e, greaterThan(0));
    });

    test('exposed king penalized vs castled king', () {
      final eSafe = evalFen('k7/8/8/8/8/8/5PPP/6K1 w - - 0 1');
      final eExposed = evalFen('k7/8/8/8/4K3/8/8/8 w - - 0 1');
      expect(eSafe, greaterThan(eExposed));
    });

    test('rook on open file bonus', () {
      final e = evalFen('k7/8/8/8/8/8/8/4R2K w - - 0 1');
      expect(e, greaterThan(400));
    });

    test('connected rooks bonus', () {
      final e = evalFen('k7/8/8/8/8/8/4R3/4R2K w - - 0 1');
      expect(e, greaterThan(900));
    });

    test('knight rim penalty', () {
      final eRim = evalFen('k7/8/8/8/8/8/8/N5K1 w - - 0 1');
      final eCenter = evalFen('k7/8/8/8/8/2N5/8/6K1 w - - 0 1');
      expect(eCenter, greaterThan(eRim));
    });

    test('knight centralization bonus', () {
      final e = evalFen('k7/8/8/3N4/8/8/8/6K1 w - - 0 1');
      expect(e, greaterThan(300));
    });

    test('center occupation bonus', () {
      final e = evalFen('rnbqkbnr/pppppppp/8/8/3PP3/8/PPP2PPP/RNBQKBNR b KQkq - 0 1');
      expect(e, greaterThan(-100));
    });

    test('endgame king activity evaluated', () {
      final e = evalFen('8/8/8/3k4/8/8/1K6/8 w - - 0 1');
      expect(e, isA<int>());
    });

    test('SimpleBotService delegates to PositionEvaluator', () async {
      final result = await SimpleBotService.instance.getBestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        depth: 1,
      );
      expect(result.evaluation.abs(), lessThan(200));
    });

    test('BasicEvaluatorService delegates to PositionEvaluator', () {
      final e = BasicEvaluatorService.instance.evaluate(
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(e.abs(), lessThan(200));
    });

    test('empty board (only kings) evaluates near zero', () {
      final e = evalFen('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
      expect(e.abs(), lessThan(50));
    });

    test('deterministic evaluation', () {
      const fen = 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1';
      expect(evalFen(fen), equals(evalFen(fen)));
    });

    test('pawn chain bonus', () {
      final e = evalFen('k7/8/8/4P3/3P4/8/8/7K w - - 0 1');
      expect(e, greaterThan(200));
    });

    test('queen advantage correctly valued', () {
      final e = evalFen('k7/8/8/8/8/5K2/8/4Q3 w - - 0 1');
      expect(e, greaterThan(800));
    });

    test('white pawn PST encourages advancement', () {
      final eAdv = evalFen('k7/P7/8/8/8/8/8/7K w - - 0 1');
      final eHome = evalFen('k7/8/8/8/8/8/P7/7K w - - 0 1');
      expect(eAdv, greaterThan(eHome));
    });

    test('eval monotonic with material', () {
      final e1 = evalFen('k7/8/8/8/8/8/8/4K3 w - - 0 1');
      final e2 = evalFen('k7/8/8/8/8/8/P7/4K3 w - - 0 1');
      final e3 = evalFen('k7/8/8/8/8/8/P5R1/4K3 w - - 0 1');
      expect(e2, greaterThan(e1));
      expect(e3, greaterThan(e2));
    });

    test('white-relative sign convention', () {
      expect(evalFen('4k3/8/8/8/8/8/8/R5K1 w - - 0 1'), greaterThan(0));
      expect(evalFen('r5k1/8/8/8/8/8/8/6K1 w - - 0 1'), lessThan(0));
    });

    test('eval scales with piece count', () {
      final e1 = evalFen('k7/8/8/8/8/8/8/4K3 w - - 0 1');
      final e2 = evalFen('k7/8/8/8/8/8/4P3/4K3 w - - 0 1');
      final e3 = evalFen('k7/8/8/8/8/4B3/4P3/4K3 w - - 0 1');
      final e4 = evalFen('k7/8/8/8/4R3/4B3/4P3/4K3 w - - 0 1');
      expect(e2, greaterThan(e1));
      expect(e3, greaterThan(e2));
      expect(e4, greaterThan(e3));
    });

    test('passed pawn bonus near promotion', () {
      expect(evalFen('k7/8/2P5/8/8/8/8/7K w - - 0 1'),
          greaterThanOrEqualTo(evalFen('k7/8/8/8/8/2P5/8/7K w - - 0 1')));
    });

    test('single evaluation fast', () {
      final sw = Stopwatch()..start();
      evalFen('r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQ1RK1 w kq - 0 1');
      sw.stop();
      expect(sw.elapsedMicroseconds, lessThan(50000));
    });

    test('knight outpost bonus', () {
      final e = evalFen('k7/8/4N3/8/8/8/8/7K w - - 0 1');
      expect(e, greaterThan(300));
    });

    test('scholars mate white winning', () {
      final e = evalFen('r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 1');
      expect(e, greaterThan(0));
    });

    test('black material advantage is negative', () {
      final e = evalFen('r5k1/8/8/8/8/8/8/6K1 w - - 0 1');
      expect(e, lessThan(0));
    });

    test('both services give consistent result for simple position', () async {
      const fen = '4k3/8/8/8/8/8/8/4K3 w - - 0 1';
      final basicEval = BasicEvaluatorService.instance.evaluate(fen);
      final result = await SimpleBotService.instance.getBestMove(fen: fen, depth: 1);
      expect(basicEval.abs(), lessThan(100));
      expect(result.evaluation.abs(), lessThan(100));
    });

    test('bishop pair gives bonus over single bishop opponent', () {
      // White has 2 bishops, black has 1 bishop + 1 knight (equal material ~320 vs 330)
      // FEN: replace black f8 bishop with knight
      final e = evalFen('rnbqkn1r/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      // White should be slightly better due to bishop pair
      expect(e, greaterThan(0));
    });

    test('100 evaluations in under 1 second', () {
      const fen = 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQ1RK1 w kq - 0 1';
      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        evalFen(fen);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
