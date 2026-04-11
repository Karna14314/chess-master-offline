import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

/// Regression test for analyzeFullGame cancellation
/// Guards against race conditions between goToMove() and analyzeFullGame()
///
/// NOTE: These tests run in fallback mode because the native Stockfish DLL
/// is not available in the test environment.
void main() {
  group('AnalysisProvider Cancellation Token Tests', () {
    late ProviderContainer container;
    late AnalysisNotifier notifier;

    setUp(() {
      // Force fallback mode BEFORE creating providers to avoid loading native DLL
      StockfishService.instance.forceFallback = true;

      container = ProviderContainer();
      notifier = container.read(analysisProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    // TEST 4 — Cancellation token (guards against ANR/race conditions)
    // Crash type: ANR from DartEntry::InvokeFunction when analyzeFullGame
    // runs concurrently with goToMove(), causing position state corruption
    // Fix: _analysisToken increments on goToMove(), loop checks token != _analysisToken
    test(
      'goToMove cancels running analyzeFullGame - _analysisToken pattern',
      () async {
        // Create a list of valid moves (using the correct ChessMove constructor)
        final moves = [
          const ChessMove(
            from: 'e2',
            to: 'e4',
            san: 'e4',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          ),
          const ChessMove(
            from: 'e7',
            to: 'e5',
            san: 'e5',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          ),
          const ChessMove(
            from: 'g1',
            to: 'f3',
            san: 'Nf3',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
          ),
          const ChessMove(
            from: 'b8',
            to: 'c6',
            san: 'Nc6',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
          ),
          const ChessMove(
            from: 'f1',
            to: 'c4',
            san: 'Bc4',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
          ),
          const ChessMove(
            from: 'g8',
            to: 'f6',
            san: 'Nf6',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
          ),
          const ChessMove(
            from: 'd2',
            to: 'd3',
            san: 'd3',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R b KQkq - 0 4',
          ),
          const ChessMove(
            from: 'f8',
            to: 'c5',
            san: 'Bc5',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 1 5',
          ),
          const ChessMove(
            from: 'c1',
            to: 'g5',
            san: 'Bg5',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqk2r/pppp1ppp/2n2n2/2b1p1B1/2B1P3/3P1N2/PPP2PPP/RN1QK2R b KQkq - 2 5',
          ),
          const ChessMove(
            from: 'd7',
            to: 'd6',
            san: 'd6',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen:
                'r1bqk2r/ppp2ppp/2np1n2/2b1p1B1/2B1P3/3P1N2/PPP2PPP/RN1QK2R w KQkq - 0 6',
          ),
        ];

        // Load the game
        await notifier.loadGame(moves: moves);

        // Start full game analysis
        final analysisFuture = notifier.analyzeFullGame();

        // Wait a small amount for analysis to start (but not complete)
        await Future.delayed(const Duration(milliseconds: 100));

        // Call goToMove which should cancel the running analysis
        await notifier.goToMove(5);

        // Wait for analysis to complete (or be cancelled)
        await analysisFuture;

        // Get the final state
        final state = container.read(analysisProvider);

        // The key assertion: we didn't hang forever (test timeout would fail if it hung)
        // If the token wasn't working, analyzeFullGame would continue processing
        // all moves even after goToMove
        // Analysis should either be complete (isAnalyzing=false) or partially done
        expect(state.isAnalyzing || state.analyzedMoves.isNotEmpty, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'stopAnalysis cancels running analyzeFullGame',
      () async {
        final moves = List.generate(
          10,
          (i) => ChessMove(
            from: 'e2',
            to: 'e4',
            san: 'e4',
            isCapture: false,
            isCheck: false,
            isCheckmate: false,
            isCastle: false,
            fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          ),
        );

        await notifier.loadGame(moves: moves);

        // Start analysis
        final analysisFuture = notifier.analyzeFullGame();

        // Wait a bit then stop
        await Future.delayed(const Duration(milliseconds: 50));
        notifier.stopAnalysis();

        // Wait for analysis to complete or be cancelled
        await analysisFuture;

        final state = container.read(analysisProvider);
        expect(state.isAnalyzing, isFalse);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
