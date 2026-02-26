import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/services/audio_service.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabaseService implements DatabaseService {
  @override
  Future<Map<String, dynamic>?> getStatistics() async {
    return {
      'current_puzzle_rating': 1200,
      'puzzles_solved': 0,
      'puzzles_attempted': 0,
    };
  }

  @override
  Future<void> savePuzzleProgress(int puzzleId, bool solved) async {}

  @override
  Future<void> updateStatistics(Map<String, dynamic> updates) async {}

  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteGame(String id) async {}

  @override
  Future<void> deleteAllGames() async {}

  @override
  Future<List<Map<String, dynamic>>> getAllGames({
    bool savedOnly = false,
    bool completedOnly = false,
    int? limit,
    int? offset,
  }) async => [];

  @override
  Future<Map<String, dynamic>?> getAnalysis(String gameId) async => null;

  @override
  Future<Map<String, dynamic>?> getGame(String id) async => null;

  @override
  Future<Map<String, dynamic>?> getLastUnfinishedGame() async => null;

  @override
  Future<List<Map<String, dynamic>>> getPuzzleHistory({int limit = 50}) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getRecentGames({
    int limit = 10,
    bool includeCompleted = true,
  }) async => [];

  @override
  Future<void> incrementGameStats({
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
    required int botElo,
  }) async {}

  @override
  Future<void> saveAnalysis(
    String gameId,
    String fen,
    String moves,
    String analysisJson,
    int depth,
  ) async {}

  @override
  Future<void> saveGame(Map<String, dynamic> game) async {}

  @override
  Future<List<Map<String, dynamic>>> searchGamesByDate({
    required DateTime start,
    required DateTime end,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> searchGamesByResult(String result) async =>
      [];

  @override
  Future<void> updateGame(String id, Map<String, dynamic> updates) async {}

  @override
  Future<void> updateGameName(String id, String customName) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Puzzle validation should strictly check promotion moves', () async {
    // Disable audio to avoid platform channel issues
    AudioService.instance.setEnabled(false);

    final container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(MockDatabaseService()),
      ],
    );

    final notifier = container.read(puzzleProvider.notifier);

    // FEN: Black to move. White pawn on a7.
    // Black moves Ka2-a3. White promotes a7-a8q.
    final puzzle = Puzzle(
      id: 1,
      fen: '8/P7/8/8/8/8/k7/7K b - - 0 1',
      moves: ['a2a3', 'a7a8q'],
      rating: 1000,
      themes: ['promotion'],
      searchableThemes: ['promotion'],
    );

    notifier.loadPuzzlesForTesting([puzzle]);

    // Start puzzle
    await notifier.startNewPuzzle();

    // Check initial state
    expect(container.read(puzzleProvider).currentPuzzle, isNotNull);

    // The player should move a7a8q.
    // We attempt to move a7a8 (without promotion char).
    notifier.tryMove('a7', 'a8');

    final state = container.read(puzzleProvider);

    // We expect the move to be REJECTED because it lacks promotion.
    // With the bug, it is accepted (PuzzleState.completed or correct).
    // So this assertion will fail until the bug is fixed.
    expect(
      state.state,
      PuzzleState.incorrect,
      reason: "Move without promotion should be rejected",
    );
  });
}
