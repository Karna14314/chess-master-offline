import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';

class _MockRepo extends Fake implements GameSessionRepository {
  @override
  Future<void> saveSession(GameSession session) async {}

  @override
  Future<GameSession?> getSession(String id) async => null;

  @override
  Future<List<GameSession>> getAllSessions({
    int? limit,
    int? offset,
  }) async => [];

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<void> clearAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // No vibration plugin in tests — sink all calls.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), (
          call,
        ) async {
          switch (call.method) {
            case 'hasVibrator':
            case 'hasAmplitudeControl':
            case 'hasCustomVibrationsSupport':
              return false;
            default:
              return null;
          }
        });
  });

  test(
    'REPRO: simple bot answers the player move',
    () async {
      final container = ProviderContainer(
        overrides: [
          gameSessionRepositoryProvider.overrideWithValue(_MockRepo()),
        ],
      );
      addTearDown(container.dispose);

      final bot = BotProfile.getById('bot_rusty');
      final vm = container.read(gameSessionProvider.notifier);
      vm.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: bot.difficultyLevel,
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
        botType: BotType.simple,
      );

      GameSession? session;
      for (var i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        session = container.read(gameSessionProvider);
        if (session != null) break;
      }
      expect(session, isNotNull, reason: 'session never created');

      final moved = await vm.makeMove('e2', 'e4');
      expect(moved, isTrue, reason: 'player move rejected');

      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        session = container.read(gameSessionProvider);
        if (session != null && session.moveHistory.length >= 2) break;
      }
      expect(
        session?.moveHistory.length,
        greaterThanOrEqualTo(2),
        reason: 'BOT NEVER REPLIED',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
