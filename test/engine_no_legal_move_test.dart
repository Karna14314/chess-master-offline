import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/core/services/database_service.dart';
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

/// Engine stub that reports no legal move for every position.
class _NoMoveStockfishService extends MockStockfishService {
  @override
  Future<BestMoveResult> getBestMove({
    required String fen,
    required int depth,
    int? thinkTimeMs,
    String? startingFen,
    List<String>? moves,
  }) async {
    return BestMoveResult(bestMove: '(none)');
  }
}

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

  group('BestMoveResult no-legal-move parsing', () {
    test('bestmove (none) is rejected and flagged as no move', () {
      final result = BestMoveResult(bestMove: '(none)');
      expect(result.isValid, isFalse);
      expect(result.isNoMove, isTrue);
      expect(result.parsedMove, ('', '', null));
    });

    test('bestmove 0000 is rejected and flagged as no move', () {
      final result = BestMoveResult(bestMove: '0000');
      expect(result.isValid, isFalse);
      expect(result.isNoMove, isTrue);
      expect(result.parsedMove, ('', '', null));
    });

    test('valid moves remain valid and parseable', () {
      final plain = BestMoveResult(bestMove: 'e2e4');
      expect(plain.isValid, isTrue);
      expect(plain.isNoMove, isFalse);
      expect(plain.parsedMove, ('e2', 'e4', null));

      final promo = BestMoveResult(bestMove: 'e7e8q');
      expect(promo.isValid, isTrue);
      expect(promo.isNoMove, isFalse);
      expect(promo.parsedMove, ('e7', 'e8', 'q'));
    });

    test('empty bestmove is invalid', () {
      final result = BestMoveResult(bestMove: '');
      expect(result.isValid, isFalse);
      expect(result.isNoMove, isFalse);
      expect(result.parsedMove, ('', '', null));
    });
  });

  group('No-legal-move integration (forced-mate must not hang)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(MockDatabaseService()),
          stockfishServiceProvider.overrideWithValue(_NoMoveStockfishService()),
          gameSessionRepositoryProvider.overrideWithValue(
            _MockGameSessionRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    GameSessionViewModel viewModel() =>
        container.read(gameSessionProvider.notifier);

    test(
      'bot in a checkmated position records the result instead of hanging',
      () async {
        final vm = viewModel();
        final session = GameSession.create(
          gameMode: GameMode.bot,
          botType: BotType.stockfish,
          playerColor: PlayerColor.white,
          difficulty: AppConstants.difficultyLevels[4],
          timeControl: AppConstants.timeControls[0],
        );
        // Scholar's mate — black (bot) to move is checkmated.
        vm.setSession(
          session.copyWith(
            fen:
                'r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 1',
          ),
        );

        await vm.triggerBotMoveForTesting().timeout(const Duration(seconds: 5));

        final state = vm.state!;
        expect(state.isCompleted, isTrue);
        expect(state.result, GameResult.whiteWins);
        expect(state.resultReason, 'Checkmate');
        // No garbage move was appended to history.
        expect(state.moveHistory, isEmpty);
      },
    );

    test('bot with no legal move in a non-terminal position does not hang or '
        'play an invalid move', () async {
      final vm = viewModel();
      final session = GameSession.create(
        gameMode: GameMode.bot,
        botType: BotType.stockfish,
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[4],
        timeControl: AppConstants.timeControls[0],
      );
      // It is black (bot) to move from the starting position — non-terminal.
      vm.setSession(
        session.copyWith(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1',
        ),
      );

      await vm.triggerBotMoveForTesting().timeout(const Duration(seconds: 5));

      final state = vm.state!;
      expect(state.isCompleted, isFalse);
      expect(state.moveHistory, isEmpty);
    });

    test(
      'player move into bot turn does not hang when engine reports (none)',
      () async {
        final vm = viewModel();
        final session = GameSession.create(
          gameMode: GameMode.bot,
          botType: BotType.stockfish,
          playerColor: PlayerColor.white,
          difficulty: AppConstants.difficultyLevels[4],
          timeControl: AppConstants.timeControls[0],
        );
        vm.setSession(session);

        final moved = await vm
            .makeMove('e2', 'e4')
            .timeout(const Duration(seconds: 5));
        expect(moved, isTrue);

        // Let the (fire-and-forget) bot move pipeline complete.
        await Future<void>.delayed(const Duration(milliseconds: 600));

        final state = vm.state!;
        expect(state.isCompleted, isFalse);
        // Only the player's move is in history — no garbage bot move.
        expect(state.moveHistory.length, 1);
        expect(state.moveHistory.single.from, 'e2');
        expect(state.moveHistory.single.to, 'e4');
      },
    );
  });
}
