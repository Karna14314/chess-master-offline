import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

void main() {
  group('Property Tests - Game Initialization Reliability', () {
    test(
      'Feature: chessmaster-offline-overhaul, Property 1: Game initialization reliability',
      () {
        // Property 1: Game initialization reliability
        // For any game mode configuration, when a user starts a game,
        // the Game_Engine should successfully initialize within 2 seconds
        // and create a valid game state ready to accept moves.
        // Validates: Requirements 1.1, 1.3, 1.5

        final random = Random(42); // Fixed seed for reproducible tests

        // Run property test with 100+ iterations
        for (int i = 0; i < 100; i++) {
          final container = ProviderContainer();
          final gameNotifier = container.read(gameProvider.notifier);

          // Generate random but valid game configuration
          final playerColor =
              PlayerColor.values[random.nextInt(PlayerColor.values.length)];
          final difficulty =
              AppConstants.difficultyLevels[random.nextInt(
                AppConstants.difficultyLevels.length,
              )];
          final timeControl = AppConstants
              .timeControls[random.nextInt(AppConstants.timeControls.length)];
          final gameMode =
              GameMode.values[random.nextInt(GameMode.values.length)];
          final allowTakeback = random.nextBool();
          final showHints = random.nextBool();
          final useTimer = random.nextBool();

          // Measure initialization time
          final stopwatch = Stopwatch()..start();

          // Start game with random configuration
          gameNotifier.startNewGame(
            playerColor: playerColor,
            difficulty: difficulty,
            timeControl: timeControl,
            gameMode: gameMode,
            allowTakeback: allowTakeback,
            showHints: showHints,
            useTimer: useTimer,
          );

          stopwatch.stop();
          final gameState = container.read(gameProvider);

          // Property assertions

          // 1. Game should initialize within 2 seconds (in practice, much faster)
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(2000),
            reason:
                'Game initialization took ${stopwatch.elapsedMilliseconds}ms, should be < 2000ms',
          );

          // 2. Game state should be properly created and active
          expect(
            gameState.status,
            GameStatus.active,
            reason: 'Game status should be active after initialization',
          );

          // 3. Game should be ready to accept moves (valid chess position)
          expect(
            gameState.board.fen,
            isNotEmpty,
            reason: 'Game board should have valid FEN position',
          );
          expect(
            gameState.board.fen,
            contains('w'),
            reason: 'FEN should indicate whose turn it is',
          );

          // 4. Player color should be resolved (no random color in final state)
          expect(
            gameState.playerColor == PlayerColor.white ||
                gameState.playerColor == PlayerColor.black,
            true,
            reason: 'Player color should be resolved to white or black',
          );

          // 5. Game should have valid starting position
          expect(
            gameState.moveHistory,
            isEmpty,
            reason: 'New game should have empty move history',
          );
          expect(
            gameState.isWhiteTurn,
            true,
            reason: 'New game should start with white to move',
          );

          // 6. Game configuration should be preserved
          expect(
            gameState.difficulty,
            difficulty,
            reason: 'Difficulty should match input',
          );
          expect(
            gameState.gameMode,
            gameMode,
            reason: 'Game mode should match input',
          );
          expect(
            gameState.allowTakeback,
            allowTakeback,
            reason: 'Takeback setting should match input',
          );

          // 7. Game should be able to generate legal moves (ready to accept moves)
          final legalMoves = gameNotifier.getAllLegalMoves();
          expect(
            legalMoves,
            isNotEmpty,
            reason: 'New game should have legal moves available',
          );
          expect(
            legalMoves.length,
            greaterThanOrEqualTo(16),
            reason:
                'Starting position should have at least 16 legal moves (8 pawns + 8 pieces)',
          );

          container.dispose();
        }
      },
    );

    test('Property test: Game initialization handles edge cases', () {
      // Test edge cases and boundary conditions
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Test with minimum difficulty
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels.first,
        timeControl: AppConstants.timeControls.first,
        gameMode: GameMode.bot,
      );

      var gameState = container.read(gameProvider);
      expect(gameState.status, GameStatus.active);

      // Test with maximum difficulty
      gameNotifier.startNewGame(
        playerColor: PlayerColor.black,
        difficulty: AppConstants.difficultyLevels.last,
        timeControl: AppConstants.timeControls.last,
        gameMode: GameMode.localMultiplayer,
      );

      gameState = container.read(gameProvider);
      expect(gameState.status, GameStatus.active);
      expect(gameState.playerColor, PlayerColor.black);

      container.dispose();
    });

    test(
      'Property test: Game initialization is deterministic for same inputs',
      () {
        // Same inputs should produce equivalent game states
        final config = {
          'playerColor': PlayerColor.white,
          'difficulty': AppConstants.difficultyLevels[3],
          'timeControl': AppConstants.timeControls[2],
          'gameMode': GameMode.bot,
          'allowTakeback': true,
          'showHints': true,
          'useTimer': false,
        };

        // Initialize same game twice
        final container1 = ProviderContainer();
        final gameNotifier1 = container1.read(gameProvider.notifier);
        gameNotifier1.startNewGame(
          playerColor: config['playerColor'] as PlayerColor,
          difficulty: config['difficulty'] as DifficultyLevel,
          timeControl: config['timeControl'] as TimeControl,
          gameMode: config['gameMode'] as GameMode,
          allowTakeback: config['allowTakeback'] as bool,
          showHints: config['showHints'] as bool,
          useTimer: config['useTimer'] as bool,
        );

        final container2 = ProviderContainer();
        final gameNotifier2 = container2.read(gameProvider.notifier);
        gameNotifier2.startNewGame(
          playerColor: config['playerColor'] as PlayerColor,
          difficulty: config['difficulty'] as DifficultyLevel,
          timeControl: config['timeControl'] as TimeControl,
          gameMode: config['gameMode'] as GameMode,
          allowTakeback: config['allowTakeback'] as bool,
          showHints: config['showHints'] as bool,
          useTimer: config['useTimer'] as bool,
        );

        final gameState1 = container1.read(gameProvider);
        final gameState2 = container2.read(gameProvider);

        // Both games should have equivalent starting states
        expect(gameState1.fen, gameState2.fen);
        expect(gameState1.status, gameState2.status);
        expect(gameState1.playerColor, gameState2.playerColor);
        expect(gameState1.difficulty.level, gameState2.difficulty.level);
        expect(gameState1.gameMode, gameState2.gameMode);
        expect(gameState1.allowTakeback, gameState2.allowTakeback);

        container1.dispose();
        container2.dispose();
      },
    );
  });
}
