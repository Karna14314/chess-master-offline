import 'package:chess/chess.dart' as chess_lib;
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hardening tests for the production SIGSEGV/ANR reports:
///
///  * `Position::set()` castling scan and `Position::is_draw` crashes are fed
///    by malformed FENs / diverged move lists.
///  * `Search::Worker::search` crashes are fed by sending commands while a
///    previous search is still running.
///  * The flat 5 s analysis timeout caused repeated stop/fallback churn on
///    low-end devices (ANR pressure).
///
/// The native engine is unavailable in the test environment, so the protocol
/// tests drive the service through injected engine output.
void main() {
  const startPos = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  late StockfishService service;

  setUp(() {
    service = StockfishService.instance;
    service.resetTestState();
  });

  tearDown(() async {
    try {
      await service.dispose();
    } catch (_) {}
    service.resetTestState();
  });

  group('FEN hardening', () {
    test('legal promoted-piece positions pass validation', () {
      // 15 non-pawn men (14 queens + king) is the legal maximum for one side.
      // The previous cap of 8 rejected this and silently downgraded the
      // position to the fallback evaluator.
      expect(
        service.isValidFenForTesting(
          '4k3/8/8/8/8/8/QQQQQQQ1/QQQQKQQQ w - - 0 1',
        ),
        isTrue,
      );
      expect(
        service.isValidFenForTesting(
          'qqqqkqqq/qqqqqqq1/8/8/8/8/8/4K3 b - - 0 1',
        ),
        isTrue,
      );
    });

    test('castling rights without the corresponding rook are rejected', () {
      // Black h8 rook missing while the k right is still set: the native
      // castling scan walks below SQ_A1 looking for it and corrupts memory.
      expect(
        service.isValidFenForTesting(
          'rnbqkbn1/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        ),
        isFalse,
      );
      // White a1 rook missing while the Q right is still set.
      expect(
        service.isValidFenForTesting(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/1NBQKBNR w KQkq - 0 1',
        ),
        isFalse,
      );
    });

    test('valid en-passant squares pass validation', () {
      // Black just played e7-e5; white d5 pawn can capture on e6.
      expect(
        service.isValidFenForTesting('4k3/8/8/3Pp3/8/8/8/4K3 w - e6 0 2'),
        isTrue,
      );
      // White just played e2-e4; black d4 pawn can capture on e3.
      expect(
        service.isValidFenForTesting('4k3/8/8/8/3pP3/8/8/4K3 b - e3 0 2'),
        isTrue,
      );
      // Regression: FENs routinely record the skipped square even when no
      // enemy pawn can actually capture. These are legal and must not be
      // downgraded to the fallback evaluator.
      expect(
        service.isValidFenForTesting(
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        ),
        isTrue,
      );
      expect(
        service.isValidFenForTesting(
          'r1bqkb1r/ppp1pppp/2n2n2/3p4/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq d6 0 4',
        ),
        isTrue,
      );
      // No pawn can capture on e6 at all; still legal.
      expect(
        service.isValidFenForTesting('4k3/8/8/4p3/8/8/8/4K3 w - e6 0 2'),
        isTrue,
      );
      // No black pawn can capture on e3 at all; still legal.
      expect(
        service.isValidFenForTesting('4k3/8/8/8/4P3/8/8/4K3 b - e3 0 2'),
        isTrue,
      );
    });

    test('impossible en-passant squares are rejected', () {
      // En-passant target occupied by a knight.
      expect(
        service.isValidFenForTesting('4k3/8/4N3/3Pp3/8/8/8/4K3 w - e6 0 2'),
        isFalse,
      );
      // The double-pushed pawn's origin square is still occupied.
      expect(
        service.isValidFenForTesting('4k3/4P3/8/3Pp3/8/8/8/4K3 w - e6 0 2'),
        isFalse,
      );
    });
  });

  group('position command consistency', () {
    test('keeps the move list when it reproduces the current FEN', () {
      final chess = chess_lib.Chess.fromFEN(startPos);
      expect(chess.move({'from': 'e2', 'to': 'e4'}), isNot(false));

      final command = service.buildPositionCommand(
        fen: chess.fen,
        startingFen: startPos,
        moves: const ['e2e4'],
      );

      expect(command, startsWith('position fen $startPos'));
      expect(command, endsWith(' moves e2e4'));
    });

    test('falls back to a single FEN when the move list diverges', () {
      // The move list says e2e4, but the displayed position is still the
      // starting position. Sending the list would make Stockfish analyze a
      // different board than the UI.
      final command = service.buildPositionCommand(
        fen: startPos,
        startingFen: startPos,
        moves: const ['e2e4'],
      );

      expect(command, 'position fen $startPos');
    });

    test('falls back to a single FEN when the move list is illegal', () {
      final command = service.buildPositionCommand(
        fen: startPos,
        startingFen: startPos,
        moves: const ['e2e5'],
      );

      expect(command, 'position fen $startPos');
    });
  });

  group('readyok generations', () {
    setUp(() {
      service.setReadyForTesting(immediateReadyOk: false);
    });

    test(
      'a readyok received before the request cannot satisfy the wait',
      () async {
        // This is the exact stale-handshake failure: an old readyok was already
        // in flight when the new isready was issued.
        service.emitEngineLineForTesting('readyok');
        await Future<void>.delayed(Duration.zero);

        final result = await service.waitForReadyOkForTesting(
          timeout: const Duration(milliseconds: 100),
        );

        expect(result, isFalse);
      },
    );

    test('a readyok received after the request satisfies the wait', () async {
      final wait = service.waitForReadyOkForTesting(
        timeout: const Duration(milliseconds: 500),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.emitEngineLineForTesting('readyok');

      expect(await wait, isTrue);
    });
  });

  group('stop handshake', () {
    setUp(() {
      service.setReadyForTesting(immediateReadyOk: true);
      service.searchTimeoutForTesting = const Duration(seconds: 5);
    });

    test('requires bestmove plus a fresh readyok, in that order', () async {
      final search = service.getBestMove(fen: startPos, depth: 3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.isEngineBusyForTesting, isTrue);

      // The search is already running; now exercise the real stop handshake.
      service.disableImmediateReadyOkForTesting();

      // A readyok from the setup handshake must not release the stop wait.
      service.emitEngineLineForTesting('readyok');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      var stopCompleted = false;
      final stop = service.stopCurrentSearchAndWaitForTesting().then(
        (_) => stopCompleted = true,
      );

      // A readyok that arrives before bestmove is also not enough: the engine
      // has not confirmed the search stopped yet.
      service.emitEngineLineForTesting('readyok');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(stopCompleted, isFalse);

      // bestmove alone is not enough either; a fresh readyok must follow it.
      service.emitEngineLineForTesting('bestmove e2e4');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(stopCompleted, isFalse);

      service.emitEngineLineForTesting('readyok');
      await stop.timeout(const Duration(seconds: 2));
      expect(stopCompleted, isTrue);

      final result = await search.timeout(const Duration(seconds: 2));
      expect(result.bestMove, 'e2e4');
      expect(service.isEngineBusyForTesting, isFalse);
      expect(service.hasOutputListenersForTesting, isFalse);
    });
  });

  group('analysis timeout budget', () {
    test('deep analysis gets more than the old flat 5 seconds', () {
      final budget = service.effectiveAnalysisTimeoutForTesting(
        depth: 12,
        multiPv: 3,
      );

      expect(budget.inMilliseconds, greaterThan(5000));
      expect(budget.inMilliseconds, lessThanOrEqualTo(20000));
    });

    test('test timeout override still wins', () {
      service.analysisTimeoutForTesting = const Duration(milliseconds: 50);

      final budget = service.effectiveAnalysisTimeoutForTesting(
        depth: 12,
        multiPv: 3,
      );

      expect(budget, const Duration(milliseconds: 50));
    });

    test('node-bounded analysis has a fixed bounded budget', () {
      final budget = service.effectiveAnalysisTimeoutForTesting(
        depth: 12,
        multiPv: 3,
        nodes: 250000,
      );

      expect(budget, const Duration(seconds: 10));
    });
  });
}
