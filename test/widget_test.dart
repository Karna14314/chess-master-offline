// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/main.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'dart:async';

// Mock Stockfish Service
class MockStockfishService implements StockfishService {
  final _analysisController = StreamController<AnalysisResult>.broadcast();

  @override
  bool get isReady => true;

  @override
  Stream<String> get outputStream => Stream.empty();

  @override
  Stream<AnalysisResult> get analysisStream => _analysisController.stream;

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
  void dispose() {
    _analysisController.close();
  }

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
          stockfishServiceProvider.overrideWithValue(MockStockfishService()),
        ],
        child: const ChessMasterApp(),
      ),
    );

    // Verify that the BottomNavigationBar is present.
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
