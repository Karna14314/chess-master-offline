import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess/chess.dart' as chess_lib;

// Mock Service
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
    return AnalysisResult(
      evaluation: 50,
      lines: [
        EngineLine(evaluation: 50, depth: depth, moves: ['e2e4']),
      ],
      depth: depth,
    );
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
  test('Analysis Benchmark - Baseline', () async {
    // 1. Generate a game with random moves (or just legal moves)
    final game = chess_lib.Chess();
    final moves = <ChessMove>[];

    // Play a simple game of approx 40 moves (80 half-moves)
    // We'll just play random legal moves until game over or enough moves
    int moveCount = 0;
    while (!game.game_over && moveCount < 50) {
      final legalMoves = game.moves();
      if (legalMoves.isEmpty) break;

      // Pick first move
      // Note: game.moves() returns list of SAN strings or Move objects depending on args.
      // default is strings.
      // We need Move objects to create ChessMove
      final moveObj = (game.moves({'asObjects': true})).first as chess_lib.Move;
      final san = game.move_to_san(moveObj);

      game.move(moveObj);
      moves.add(
        ChessMove(
          from: moveObj.fromAlgebraic,
          to: moveObj.toAlgebraic,
          san: san,
          promotion: moveObj.promotion?.name,
          isCapture: moveObj.captured != null,
          isCheck: game.in_check,
          isCheckmate: game.in_checkmate,
          isCastle: false,
          fen: game.fen,
        ),
      );
      moveCount++;
    }

    print('Generated ${moves.length} moves for benchmark.');

    // 2. Setup AnalysisNotifier with MockStockfishService
    final mockService = MockStockfishService();
    final notifier = AnalysisNotifier(mockService);

    // 3. Load game
    await notifier.loadGame(moves: moves);

    // 4. Analyze full game
    final stopwatch = Stopwatch()..start();
    await notifier.analyzeFullGame();
    stopwatch.stop();

    print('Analysis took ${stopwatch.elapsedMilliseconds}ms');
    print('State updates: ${notifier.stateUpdateCount}');

    // 5. Verify optimized updates
    // Batch size is 5.
    final expectedUpdates = (moves.length / 5).ceil();
    expect(
      notifier.stateUpdateCount,
      expectedUpdates,
      reason: 'State should update every 5 moves',
    );

    // Verify results
    expect(notifier.state.analyzedMoves.length, moves.length);
    expect(notifier.state.analysisProgress, 1.0);
  });
}
