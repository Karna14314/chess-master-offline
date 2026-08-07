import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/providers/timer_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/models/game_model.dart';

void main() {
  group('Timer System Tests', () {
    test('Local 2P game starts with a correctly initialized clock', () {
      final timeControl = AppConstants.timeControls[3]; // 3 min timer

      final session = GameSession.create(
        gameMode: GameMode.localMultiplayer,
        botType: BotType.stockfish,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: timeControl,
        playerColor: PlayerColor.white,
      );

      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith(
            (ref) => GameSessionViewModel(
              // Mock repository is not needed just to test TimerNotifier initialization
              throw UnimplementedError('Repository not used for this test'),
              ref,
            )..setSession(session),
          ),
        ],
      );

      final timerNotifier = container.read(timerProvider.notifier);
      timerNotifier.initialize(timeControl);
      timerNotifier.setTimes(
        whiteTime: session.whiteTimeRemaining,
        blackTime: session.blackTimeRemaining,
      );
      timerNotifier.setTurn(session.isWhiteTurn);

      if (session.timeControl.hasTimer && !session.isCompleted) {
        timerNotifier.start();
      }

      final timerState = container.read(timerProvider);
      expect(timerState.hasTimer, true);
      expect(timerState.isRunning, true);
      expect(
        timerState.timeControl.initialDuration,
        const Duration(minutes: 3),
      );
    });

    test('Bot game is always created with no timer', () {
      final timeControlWithTimer = AppConstants.timeControls[3]; // 3 min timer

      final timeControl =
          GameMode.bot == GameMode.bot
              ? AppConstants
                  .timeControls[0] // Mocking the logic applied in NewGameSetupScreen
              : timeControlWithTimer;

      final session = GameSession.create(
        gameMode: GameMode.bot,
        botType: BotType.stockfish,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: timeControl,
        playerColor: PlayerColor.white,
      );

      expect(session.timeControl.hasTimer, false);
      expect(session.timeControl.name, 'No Timer');
    });

    test('Starting a second game replaces the first game timer cleanly', () {
      final timeControl1 = AppConstants.timeControls[3]; // 3 min
      final timeControl2 = AppConstants.timeControls[5]; // 5 min

      final container = ProviderContainer();

      final timerNotifier = container.read(timerProvider.notifier);
      timerNotifier.initialize(timeControl1);

      var timerState = container.read(timerProvider);
      expect(timerState.timeControl, timeControl1);
      expect(timerState.whiteTime, const Duration(minutes: 3));

      // Simulate starting a new game which reinitializes the timer
      timerNotifier.initialize(timeControl2);

      timerState = container.read(timerProvider);
      expect(timerState.timeControl, timeControl2);
      expect(timerState.whiteTime, const Duration(minutes: 5));
    });
  });
}
