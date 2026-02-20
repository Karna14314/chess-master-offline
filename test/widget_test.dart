import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/main.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chess_master/providers/engine_provider.dart';

class MockDatabaseService implements DatabaseService {
  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getRecentGames({
    int limit = 10,
    bool includeCompleted = true,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getStatistics() async {
    return {
      'id': 1,
      'total_games': 0,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'puzzles_solved': 0,
      'puzzles_attempted': 0,
      'current_puzzle_rating': 1200,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    };
  }

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
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getAnalysis(String gameId) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getGame(String id) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getLastUnfinishedGame() async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getPuzzleHistory({int limit = 50}) async {
    return [];
  }

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
  Future<void> savePuzzleProgress(int puzzleId, bool solved) async {}

  @override
  Future<List<Map<String, dynamic>>> searchGamesByDate({
    required DateTime start,
    required DateTime end,
  }) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> searchGamesByResult(String result) async {
    return [];
  }

  @override
  Future<void> updateGame(String id, Map<String, dynamic> updates) async {}

  @override
  Future<void> updateGameName(String id, String customName) async {}

  @override
  Future<void> updateStatistics(Map<String, dynamic> updates) async {}
}

class MockStockfishService implements StockfishService {
  @override
  bool get isReady => true;

  @override
  bool get isUsingFallback => false;

  @override
  ValueNotifier<EngineStatus> get statusNotifier =>
      ValueNotifier(EngineStatus.ready);

  @override
  set forceFallback(bool value) {}

  @override
  Stream<String> get outputStream => Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<BestMoveResult> getBestMove({
    required String fen,
    required int depth,
    int? thinkTimeMs,
  }) async {
    return BestMoveResult(bestMove: 'e2e4');
  }

  @override
  Future<AnalysisResult> analyzePosition({
    required String fen,
    int depth = 15,
    int multiPv = 1,
  }) async {
    return AnalysisResult(evaluation: 0, lines: [], depth: depth);
  }

  @override
  void stopAnalysis() {}

  @override
  void dispose() {}

  @override
  void setSkillLevel(int elo) {}

  @override
  void newGame() {}
}

void main() {
  testWidgets('App launches and displays bottom navigation bar', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseServiceProvider.overrideWithValue(MockDatabaseService()),
          stockfishServiceProvider.overrideWithValue(MockStockfishService()),
        ],
        child: const ChessMasterApp(),
      ),
    );

    // Verify that the BottomNavigationBar is present.
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
