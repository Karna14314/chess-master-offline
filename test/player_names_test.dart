import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Player Names Tests', () {
    test('PvP Mode should set names to Player 1 and Player 2', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      gameNotifier.startNewGame(
        playerColor: PlayerColor.white, // Color doesn't matter for PvP names
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.localMultiplayer,
      );

      final gameState = container.read(gameProvider);

      expect(gameState.whitePlayerName, 'Player 1');
      expect(gameState.blackPlayerName, 'Player 2');

      container.dispose();
    });

    test('Bot Mode (Player White) should set names correctly', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      final difficulty = AppConstants.difficultyLevels[0]; // Beginner, Elo 800

      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: difficulty,
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );

      final gameState = container.read(gameProvider);

      expect(gameState.whitePlayerName, 'Player');
      expect(gameState.blackPlayerName, 'Bot (${difficulty.elo})');

      container.dispose();
    });

    test('Bot Mode (Player Black) should set names correctly', () {
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      final difficulty = AppConstants.difficultyLevels[0]; // Beginner, Elo 800

      gameNotifier.startNewGame(
        playerColor: PlayerColor.black,
        difficulty: difficulty,
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.bot,
      );

      final gameState = container.read(gameProvider);

      expect(gameState.whitePlayerName, 'Bot (${difficulty.elo})');
      expect(gameState.blackPlayerName, 'Player');

      container.dispose();
    });
  });
}
