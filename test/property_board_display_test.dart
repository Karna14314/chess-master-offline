import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

void main() {
  group('Property Tests - Board Display Correctness', () {
    test(
      'Feature: chessmaster-offline-overhaul, Property 2: Board display correctness',
      () {
        // Property 2: Board display correctness
        // For any initialized game, the Board_Display should show the correct
        // starting chess position with all 32 pieces in their proper initial locations.
        // Validates: Requirements 1.2

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
          final timeControl =
              AppConstants.timeControls[random.nextInt(
                AppConstants.timeControls.length,
              )];
          final gameMode =
              GameMode.values[random.nextInt(GameMode.values.length)];
          final allowTakeback = random.nextBool();
          final showHints = random.nextBool();
          final useTimer = random.nextBool();

          // Initialize game with random configuration
          gameNotifier.startNewGame(
            playerColor: playerColor,
            difficulty: difficulty,
            timeControl: timeControl,
            gameMode: gameMode,
            allowTakeback: allowTakeback,
            showHints: showHints,
            useTimer: useTimer,
          );

          final gameState = container.read(gameProvider);

          // Property assertions for board display correctness

          // 1. Board should show correct starting position FEN
          expect(
            gameState.fen,
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            reason: 'Board should display standard starting position FEN',
          );

          // 2. All 32 pieces should be in their proper initial locations
          expect(
            gameNotifier.validateStartingPieceCount(),
            true,
            reason: 'Board should have exactly 32 pieces in starting position',
          );

          // 3. White pieces should be on ranks 1 and 2
          final whitePieces = ['wR', 'wN', 'wB', 'wQ', 'wK', 'wB', 'wN', 'wR'];
          final whiteFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

          for (int j = 0; j < 8; j++) {
            expect(
              gameNotifier.getPieceAt('${whiteFiles[j]}1'),
              whitePieces[j],
              reason:
                  'White piece at ${whiteFiles[j]}1 should be ${whitePieces[j]}',
            );
            expect(
              gameNotifier.getPieceAt('${whiteFiles[j]}2'),
              'wP',
              reason: 'White pawn should be at ${whiteFiles[j]}2',
            );
          }

          // 4. Black pieces should be on ranks 7 and 8
          final blackPieces = ['bR', 'bN', 'bB', 'bQ', 'bK', 'bB', 'bN', 'bR'];

          for (int j = 0; j < 8; j++) {
            expect(
              gameNotifier.getPieceAt('${whiteFiles[j]}8'),
              blackPieces[j],
              reason:
                  'Black piece at ${whiteFiles[j]}8 should be ${blackPieces[j]}',
            );
            expect(
              gameNotifier.getPieceAt('${whiteFiles[j]}7'),
              'bP',
              reason: 'Black pawn should be at ${whiteFiles[j]}7',
            );
          }

          // 5. Ranks 3-6 should be empty
          for (int rank = 3; rank <= 6; rank++) {
            for (String file in whiteFiles) {
              expect(
                gameNotifier.getPieceAt('$file$rank'),
                null,
                reason:
                    'Square $file$rank should be empty in starting position',
              );
            }
          }

          // 6. Comprehensive board display validation should pass
          expect(
            gameNotifier.validateBoardDisplay(),
            true,
            reason: 'Complete board display validation should pass',
          );

          // 7. Specific piece type and color validation
          expect(
            gameNotifier.validatePiecePlacements(),
            true,
            reason: 'All pieces should be in correct starting positions',
          );

          // 8. Game should be ready to start (white to move)
          expect(
            gameState.isWhiteTurn,
            true,
            reason: 'Game should start with white to move',
          );

          // 9. No moves should have been made yet
          expect(
            gameState.moveHistory,
            isEmpty,
            reason: 'Starting position should have no move history',
          );

          container.dispose();
        }
      },
    );

    test(
      'Property test: Board display consistency across different configurations',
      () {
        // Test that board display is consistent regardless of game configuration
        final configurations = [
          {
            'playerColor': PlayerColor.white,
            'difficulty': AppConstants.difficultyLevels[0],
            'timeControl': AppConstants.timeControls[0],
            'gameMode': GameMode.bot,
          },
          {
            'playerColor': PlayerColor.black,
            'difficulty': AppConstants.difficultyLevels[5],
            'timeControl': AppConstants.timeControls[3],
            'gameMode': GameMode.localMultiplayer,
          },
          {
            'playerColor': PlayerColor.random,
            'difficulty': AppConstants.difficultyLevels[9],
            'timeControl': AppConstants.timeControls[7],
            'gameMode': GameMode.analysis,
          },
        ];

        for (final config in configurations) {
          final container = ProviderContainer();
          final gameNotifier = container.read(gameProvider.notifier);

          gameNotifier.startNewGame(
            playerColor: config['playerColor'] as PlayerColor,
            difficulty: config['difficulty'] as DifficultyLevel,
            timeControl: config['timeControl'] as TimeControl,
            gameMode: config['gameMode'] as GameMode,
          );

          final gameState = container.read(gameProvider);

          // All configurations should result in identical starting board display
          expect(
            gameState.fen,
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          );
          expect(gameNotifier.validateBoardDisplay(), true);
          expect(gameNotifier.validateStartingPieceCount(), true);
          expect(gameNotifier.validatePiecePlacements(), true);

          container.dispose();
        }
      },
    );

    test('Property test: Board display validation after piece movement', () {
      // Test that board display validation correctly identifies when position changes
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode:
            GameMode.localMultiplayer, // Use local multiplayer to avoid engine
      );

      // Initially should pass all validations
      expect(gameNotifier.validateBoardDisplay(), true);
      expect(gameNotifier.validateStartingPosition(), true);
      expect(gameNotifier.validateStartingPieceCount(), true);

      // Make various moves and verify validation responds correctly
      final testMoves = [
        ['e2', 'e4'], // Pawn move
        ['e7', 'e5'], // Pawn move
        ['g1', 'f3'], // Knight move
        ['b8', 'c6'], // Knight move
      ];

      for (final move in testMoves) {
        gameNotifier.selectSquare(move[0]);
        gameNotifier.selectSquare(move[1]);

        final gameState = container.read(gameProvider);

        // After any move, should no longer be starting position
        expect(
          gameNotifier.validateStartingPosition(),
          false,
          reason:
              'Should not be starting position after move ${move[0]}-${move[1]}',
        );
        expect(
          gameNotifier.validateBoardDisplay(),
          false,
          reason: 'Board display validation should fail after moves',
        );

        // But should still have valid piece count (no captures yet)
        expect(
          gameNotifier.validateAllPiecesPlaced(),
          true,
          reason: 'Should still have valid piece count after non-capture moves',
        );

        // Should have valid FEN
        expect(
          gameState.fen,
          isNotEmpty,
          reason: 'Should have valid FEN after move',
        );
        expect(
          gameState.fen,
          isNot('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
          reason: 'FEN should change after move',
        );
      }

      container.dispose();
    });

    test('Property test: Board display piece counting accuracy', () {
      // Test that piece counting is accurate in various scenarios
      final container = ProviderContainer();
      final gameNotifier = container.read(gameProvider.notifier);

      // Test starting position piece count
      gameNotifier.startNewGame(
        playerColor: PlayerColor.white,
        difficulty: AppConstants.difficultyLevels[0],
        timeControl: AppConstants.timeControls[0],
        gameMode: GameMode.localMultiplayer,
      );

      // Count pieces manually and verify
      int manualCount = 0;
      final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

      // Count all pieces on the board
      for (int rank = 1; rank <= 8; rank++) {
        for (String file in files) {
          if (gameNotifier.getPieceAt('$file$rank') != null) {
            manualCount++;
          }
        }
      }

      expect(
        manualCount,
        32,
        reason: 'Manual count should match expected 32 pieces',
      );
      expect(gameNotifier.validateStartingPieceCount(), true);

      // Verify specific piece types
      int whitePawns = 0, blackPawns = 0;
      int whiteRooks = 0, blackRooks = 0;
      int whiteKnights = 0, blackKnights = 0;
      int whiteBishops = 0, blackBishops = 0;
      int whiteQueens = 0, blackQueens = 0;
      int whiteKings = 0, blackKings = 0;

      for (int rank = 1; rank <= 8; rank++) {
        for (String file in files) {
          final piece = gameNotifier.getPieceAt('$file$rank');
          if (piece != null) {
            switch (piece) {
              case 'wP':
                whitePawns++;
                break;
              case 'bP':
                blackPawns++;
                break;
              case 'wR':
                whiteRooks++;
                break;
              case 'bR':
                blackRooks++;
                break;
              case 'wN':
                whiteKnights++;
                break;
              case 'bN':
                blackKnights++;
                break;
              case 'wB':
                whiteBishops++;
                break;
              case 'bB':
                blackBishops++;
                break;
              case 'wQ':
                whiteQueens++;
                break;
              case 'bQ':
                blackQueens++;
                break;
              case 'wK':
                whiteKings++;
                break;
              case 'bK':
                blackKings++;
                break;
            }
          }
        }
      }

      // Verify correct piece counts
      expect(whitePawns, 8, reason: 'Should have 8 white pawns');
      expect(blackPawns, 8, reason: 'Should have 8 black pawns');
      expect(whiteRooks, 2, reason: 'Should have 2 white rooks');
      expect(blackRooks, 2, reason: 'Should have 2 black rooks');
      expect(whiteKnights, 2, reason: 'Should have 2 white knights');
      expect(blackKnights, 2, reason: 'Should have 2 black knights');
      expect(whiteBishops, 2, reason: 'Should have 2 white bishops');
      expect(blackBishops, 2, reason: 'Should have 2 black bishops');
      expect(whiteQueens, 1, reason: 'Should have 1 white queen');
      expect(blackQueens, 1, reason: 'Should have 1 black queen');
      expect(whiteKings, 1, reason: 'Should have 1 white king');
      expect(blackKings, 1, reason: 'Should have 1 black king');

      container.dispose();
    });
  });
}
