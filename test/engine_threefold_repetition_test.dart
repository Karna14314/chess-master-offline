import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_test.dart';

/// Repository stub that persists nothing.
class _MockGameSessionRepository implements GameSessionRepository {
  @override
  Future<void> saveSession(GameSession session) async {}

  @override
  Future<GameSession?> getSession(String id) async => null;

  @override
  Future<List<GameSession>> getAllSessions({int? limit, int? offset}) async =>
      [];

  @override
  Future<List<GameSession>> getUnfinishedGames({int? limit}) async => [];

  @override
  Future<List<GameSession>> getRealGamesHistory({int? limit}) async => [];

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<void> clearAll() async {}
}

/// Perpetual knight shuffle. After the 8th ply (4.Ng8) the initial position
/// has occurred three times and the game is a draw by threefold repetition.
const _perpetualMoves = [
  ('g1', 'f3'),
  ('g8', 'f6'),
  ('f3', 'g1'),
  ('f6', 'g8'),
  ('g1', 'f3'),
  ('g8', 'f6'),
  ('f3', 'g1'),
  ('f6', 'g8'),
];

ProviderContainer _makeContainer() => ProviderContainer(
  overrides: [
    databaseServiceProvider.overrideWithValue(MockDatabaseService()),
    stockfishServiceProvider.overrideWithValue(MockStockfishService()),
    gameSessionRepositoryProvider.overrideWithValue(
      _MockGameSessionRepository(),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('vibration'),
          (call) async => null,
        );
  });

  group('Position command builder', () {
    final service = StockfishService.instance;

    setUp(service.resetTestState);

    test('emits the full move list when startingFen and moves are provided', () {
      expect(
        service.buildPositionCommand(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 1 1',
          startingFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: const ['e2e4', 'e7e5'],
        ),
        'position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
        ' moves e2e4 e7e5',
      );
    });

    test('falls back to the current FEN when no startingFen is provided', () {
      expect(
        service.buildPositionCommand(
          fen:
              'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
        ),
        'position fen r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
      );
    });

    test('omits the moves segment when startingFen has no moves', () {
      expect(
        service.buildPositionCommand(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 1 1',
          startingFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        ),
        'position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
    });
  });

  group('Service sends the full position + moves command', () {
    final service = StockfishService.instance;

    setUp(service.resetTestState);

    test('getBestMove sends position fen <start> moves <uci...>', () async {
      const startFen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

      final receivePort = ReceivePort();
      final sentCommands = <String>[];
      final sub = receivePort.listen((message) {
        if (message is Map && message['type'] == 'stdin') {
          sentCommands.add((message['command'] as String).trim());
        }
      });

      service.setReadyForTesting(
        immediateReadyOk: true,
        commandPort: receivePort.sendPort,
      );

      final resultFuture = service.getBestMove(
        fen: startFen,
        depth: 5,
        thinkTimeMs: 100,
        startingFen: startFen,
        moves: const ['e2e4', 'e7e5'],
      );

      // Let the command queue flush the position command.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      service.emitEngineLineForTesting('bestmove e2e4');

      final result = await resultFuture.timeout(const Duration(seconds: 5));
      expect(result.bestMove, 'e2e4');

      expect(sentCommands, contains('position fen $startFen moves e2e4 e7e5'));
      expect(
        sentCommands.where((c) => c == 'position fen $startFen'),
        isEmpty,
        reason: 'a FEN-only position command must not be sent when moves exist',
      );

      await sub.cancel();
      receivePort.close();
    });
  });

  group('Threefold repetition is detected in the viewmodel', () {
    test('a fresh session completes as a threefold-repetition draw', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final vm = container.read(gameSessionProvider.notifier);

      final session = GameSession.create(
        gameMode: GameMode.localMultiplayer,
        difficulty: AppConstants.difficultyLevels[4],
        timeControl: AppConstants.timeControls[0],
      );
      vm.setSession(session);

      for (final (from, to) in _perpetualMoves) {
        final moved = await vm
            .makeMove(from, to)
            .timeout(const Duration(seconds: 5));
        expect(moved, isTrue, reason: '$from$to should be legal');
      }

      final state = vm.state!;
      expect(state.isCompleted, isTrue);
      expect(state.result, GameResult.draw);
      expect(state.resultReason, 'Threefold repetition');
      expect(state.moveHistory.length, _perpetualMoves.length);
    });

    test(
      'a reloaded session (fromMap round-trip) detects the repetition',
      () async {
        final container = _makeContainer();
        addTearDown(container.dispose);
        final vm = container.read(gameSessionProvider.notifier);

        final session = GameSession.create(
          gameMode: GameMode.localMultiplayer,
          difficulty: AppConstants.difficultyLevels[4],
          timeControl: AppConstants.timeControls[0],
        );
        vm.setSession(session);

        // Play all but the final ply, then persist & reload the session.
        for (final (from, to) in _perpetualMoves.take(7)) {
          final moved = await vm
              .makeMove(from, to)
              .timeout(const Duration(seconds: 5));
          expect(moved, isTrue);
        }
        expect(vm.state!.isCompleted, isFalse);

        final reloaded = GameSession.fromMap(vm.state!.toMap());
        expect(reloaded.moveHistory.length, 7);

        final reloadContainer = _makeContainer();
        addTearDown(reloadContainer.dispose);
        final reloadedVm = reloadContainer.read(gameSessionProvider.notifier);
        reloadedVm.setSession(reloaded);

        final (from, to) = _perpetualMoves[7];
        final moved = await reloadedVm
            .makeMove(from, to)
            .timeout(const Duration(seconds: 5));
        expect(moved, isTrue);

        final state = reloadedVm.state!;
        expect(state.isCompleted, isTrue);
        expect(state.result, GameResult.draw);
        expect(state.resultReason, 'Threefold repetition');
      },
    );
  });
}
