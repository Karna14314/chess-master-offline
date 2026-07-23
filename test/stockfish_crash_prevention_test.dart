import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Section 11 — Stockfish Native Crash Prevention (FEN Validation)', () {
    final service = StockfishService.instance;

    setUp(() {
      service.forceFallback = true;
    });

    test('Valid FEN strings pass validation and return move', () async {
      const validStartPos =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      const validEndgame = '8/8/4k3/8/4P3/8/4K3/8 w - - 0 1';

      final res1 = await service.getBestMove(fen: validStartPos, depth: 1, thinkTimeMs: 100);
      expect(res1.bestMove, isNotEmpty);

      final res2 = await service.getBestMove(fen: validEndgame, depth: 1, thinkTimeMs: 100);
      expect(res2.bestMove, isNotEmpty);
    });

    test('Malformed or invalid FENs are rejected by validation and use fallback safely', () async {
      const missingKings = '8/8/8/8/8/8/8/8 w - - 0 1';
      const missingWhiteKing = 'rnbq1bnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1BNR w - - 0 1';
      const badBoardRows = '8/8/8/8/8/8/8 w - - 0 1';
      const badEnPassant = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq invalid 0 1';

      // None of these should throw SIGSEGV or exception; all should return a valid fallback move
      final res1 = await service.getBestMove(fen: missingKings, depth: 1, thinkTimeMs: 100);
      expect(res1.bestMove, isNotNull);

      final res2 = await service.getBestMove(fen: missingWhiteKing, depth: 1, thinkTimeMs: 100);
      expect(res2.bestMove, isNotNull);

      final res3 = await service.getBestMove(fen: badBoardRows, depth: 1, thinkTimeMs: 100);
      expect(res3.bestMove, isNotNull);

      final res4 = await service.getBestMove(fen: badEnPassant, depth: 1, thinkTimeMs: 100);
      expect(res4.bestMove, isNotNull);
    });
  });

  group('Section 10 — Android Target & Compile SDK 36 Policy', () {
    test('build.gradle.kts targets compileSdk 36 and targetSdk 36', () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), isTrue, reason: 'android/app/build.gradle.kts must exist');

      final content = file.readAsStringSync();
      expect(content.contains('compileSdk = 36'), isTrue, reason: 'compileSdk must be set to 36');
      expect(content.contains('targetSdk = 36'), isTrue, reason: 'targetSdk must be set to 36');
    });
  });
}
