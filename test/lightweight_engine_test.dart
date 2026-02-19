import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/lightweight_engine_service.dart';

void main() {
  group('LightweightEngineService', () {
    test('Initialization', () {
      final engine = LightweightEngineService.instance;
      expect(engine, isNotNull);
    });

    test('Opening Book - Starting Position', () async {
      final engine = LightweightEngineService.instance;
      const startFen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final result = await engine.getBestMove(startFen, 1);
      expect(result.bestMove, equals('e2e4'));
    });

    test('Mate in 1 (Scholar\'s Mate)', () async {
      final engine = LightweightEngineService.instance;
      // White to move and mate: Qh5xf7#
      // Position: r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4
      const fen =
          'r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4';

      final result = await engine.getBestMove(fen, 3);
      expect(result.bestMove, equals('h5f7'));
      // Evaluation should be very high (mate score)
      // Mate score is around -1000000 + depth logic.
      // Wait, in my code: return -1000000 + (100 - depth);
      // But getBestMove returns `bestValue` which is from root perspective?
      // Yes. White to move, finds mate. Score should be positive large.
      // Wait, my negamax returns score relative to side to move.
      // In getBestMove:
      // int value = -_negaMax(board, ...);
      // If white moves and mates, negaMax (black's turn) returns -MateScore.
      // So value = -(-MateScore) = MateScore.
      // MateScore is ~ -1000000. So value is ~1000000.
      expect(result.evaluation, greaterThan(900000));
    });

    test('Returns valid move for random position', () async {
      final engine = LightweightEngineService.instance;
      // Some midgame position
      const fen =
          'rnbqkb1r/ppp2ppp/5n2/3pp3/3P4/2N2N2/PPP1PPPP/R1BQKB1R w KQkq - 0 4';
      final result = await engine.getBestMove(fen, 2);
      expect(result.bestMove, isNotEmpty);
      expect(result.bestMove.length, greaterThanOrEqualTo(4));
    });

    test('Back Rank Mate', () async {
      // White Rooks on e1, d1. Black King on g8, pawns f7,g7,h7.
      // White Rook on d1 moves to d8 mate? No.
      // Simple back rank:
      // 6k1/5ppp/8/8/8/8/8/3R2K1 w - - 0 1
      // White moves Rd1 -> d8 #
      final engine = LightweightEngineService.instance;
      const fen = '6k1/5ppp/8/8/8/8/8/3R2K1 w - - 0 1';
      final result = await engine.getBestMove(fen, 3);
      expect(result.bestMove, equals('d1d8'));
    });
  });
}
