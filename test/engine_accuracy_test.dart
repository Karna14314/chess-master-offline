import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/analysis_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/models/chess_models.dart';

void main() {
  group('Phase 8 — Accuracy & Move Quality Tests', () {
    // ── CPL Convention ──────────────────────────────────────────
    //
    // Centipawn Loss (CPL): positive = move was worse than the position before.
    //   White: CPL = evalBefore - evalAfter
    //   Black: CPL = evalAfter - evalBefore
    //   Zero/negative: move maintained or improved the position.
    //
    // Accuracy: 100 × exp(-0.003 × CPL), clamped to [0, 100].
    //   CPL = 0    → accuracy = 100.0
    //   CPL = 50   → accuracy ≈ 86.1
    //   CPL = 100  → accuracy ≈ 74.1
    //   CPL = 300  → accuracy ≈ 40.7
    //   CPL = 1000 → accuracy ≈  4.98
    //
    // Classification thresholds (centipawns):
    //   CPL ≤ 5    → Best
    //   CPL ≤ 20   → Excellent
    //   CPL ≤ 50   → Good
    //   CPL ≤ 100  → Inaccuracy
    //   CPL ≤ 200  → Mistake
    //   CPL > 200  → Blunder

    // ── computeCentipawnLoss ──────────────────────────────────────

    group('computeCentipawnLoss', () {
      test('white move: eval decreased → positive loss', () {
        expect(
          computeCentipawnLoss(
            evalBefore: 1.0,
            evalAfter: 0.5,
            isWhiteMove: true,
          ),
          equals(50.0), // (1.0 - 0.5) * 100 = 50 cp
        );
      });

      test('white move: eval increased → negative loss (improvement)', () {
        expect(
          computeCentipawnLoss(
            evalBefore: 0.5,
            evalAfter: 1.0,
            isWhiteMove: true,
          ),
          equals(-50.0), // (0.5 - 1.0) * 100 = -50 cp
        );
      });

      test('white move: no change → zero loss', () {
        expect(
          computeCentipawnLoss(
            evalBefore: 0.5,
            evalAfter: 0.5,
            isWhiteMove: true,
          ),
          equals(0.0),
        );
      });

      test('black move: eval increased → positive loss', () {
        expect(
          computeCentipawnLoss(
            evalBefore: 0.5,
            evalAfter: 1.0,
            isWhiteMove: false,
          ),
          equals(50.0), // (1.0 - 0.5) * 100 = 50 cp
        );
      });

      test('black move: eval decreased → negative loss (improvement)', () {
        expect(
          computeCentipawnLoss(
            evalBefore: 0.5,
            evalAfter: 0.0,
            isWhiteMove: false,
          ),
          equals(-50.0), // (0.0 - 0.5) * 100 = -50 cp
        );
      });

      test('white and black are symmetric for same eval swing', () {
        // White: eval drops from +1 to -1 = loss of 200cp
        final whiteLoss = computeCentipawnLoss(
          evalBefore: 1.0,
          evalAfter: -1.0,
          isWhiteMove: true,
        );
        // Black: eval rises from -1 to +1 = loss of 200cp
        final blackLoss = computeCentipawnLoss(
          evalBefore: -1.0,
          evalAfter: 1.0,
          isWhiteMove: false,
        );
        expect(whiteLoss, equals(200.0));
        expect(blackLoss, equals(200.0));
        expect(whiteLoss, equals(blackLoss));
      });
    });

    // ── computeAccuracy ─────────────────────────────────────────

    group('computeAccuracy', () {
      test('perfect move (no loss) → 100%', () {
        final acc = computeAccuracy(
          evalBefore: 0.5,
          evalAfter: 0.5,
          isWhiteMove: true,
        );
        expect(acc, equals(100.0));
      });

      test('improvement → 100%', () {
        final acc = computeAccuracy(
          evalBefore: 0.5,
          evalAfter: 1.0,
          isWhiteMove: true,
        );
        expect(acc, equals(100.0));
      });

      test('small loss (0.25 pawns = 25cp) → ~92.8%', () {
        final acc = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: 0.75,
          isWhiteMove: true,
        );
        // 100 * exp(-0.003 * 25) = 100 * exp(-0.075) ≈ 92.77
        expect(acc, closeTo(92.77, 0.1));
      });

      test('medium loss (1.0 pawns = 100cp) → ~74.1%', () {
        final acc = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: 0.0,
          isWhiteMove: true,
        );
        // 100 * exp(-0.003 * 100) = 100 * exp(-0.3) ≈ 74.08
        expect(acc, closeTo(74.08, 0.1));
      });

      test('large loss (3.0 pawns = 300cp) → ~40.7%', () {
        final acc = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: -2.0,
          isWhiteMove: true,
        );
        // 100 * exp(-0.003 * 300) = 100 * exp(-0.9) ≈ 40.66
        expect(acc, closeTo(40.66, 0.1));
      });

      test('severe blunder (10.0 pawns = 1000cp) → ~5.0%', () {
        final acc = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: -9.0,
          isWhiteMove: true,
        );
        // 100 * exp(-0.003 * 1000) = 100 * exp(-3) ≈ 4.98
        expect(acc, closeTo(4.98, 0.1));
      });

      test('black move accuracy is symmetric', () {
        // Black loses 100cp: eval goes from 0 to +1 (bad for black)
        final accBlack = computeAccuracy(
          evalBefore: 0.0,
          evalAfter: 1.0,
          isWhiteMove: false,
        );
        // White loses 100cp: eval goes from +1 to 0 (bad for white)
        final accWhite = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: 0.0,
          isWhiteMove: true,
        );
        expect(accBlack, closeTo(accWhite, 0.01));
      });
    });

    // ── EvalConstants ─────────────────────────────────────────

    group('EvalConstants', () {
      test('accuracyFromCpl: zero CPL → 100%', () {
        expect(EvalConstants.accuracyFromCpl(0), equals(100.0));
      });

      test('accuracyFromCpl: negative CPL → 100%', () {
        expect(EvalConstants.accuracyFromCpl(-50), equals(100.0));
      });

      test('accuracyFromCpl: 50cp → ~86.1%', () {
        expect(EvalConstants.accuracyFromCpl(50), closeTo(86.07, 0.1));
      });

      test('accuracyFromCpl: 1000cp → ~5%', () {
        expect(EvalConstants.accuracyFromCpl(1000), closeTo(4.98, 0.1));
      });

      test('accuracyFromCpl: very large CPL clamped to 0%', () {
        final acc = EvalConstants.accuracyFromCpl(10000);
        expect(acc, greaterThanOrEqualTo(0.0));
        expect(acc, lessThan(1.0));
      });

      test('classifyCpl: CPL ≤ 5 → Best', () {
        expect(EvalConstants.classifyCpl(0), equals(MoveClassification.best));
        expect(EvalConstants.classifyCpl(5), equals(MoveClassification.best));
      });

      test('classifyCpl: CPL 6-20 → Excellent', () {
        expect(
          EvalConstants.classifyCpl(6),
          equals(MoveClassification.excellent),
        );
        expect(
          EvalConstants.classifyCpl(20),
          equals(MoveClassification.excellent),
        );
      });

      test('classifyCpl: CPL 21-50 → Good', () {
        expect(EvalConstants.classifyCpl(21), equals(MoveClassification.good));
        expect(EvalConstants.classifyCpl(50), equals(MoveClassification.good));
      });

      test('classifyCpl: CPL 51-100 → Inaccuracy', () {
        expect(
          EvalConstants.classifyCpl(51),
          equals(MoveClassification.inaccuracy),
        );
        expect(
          EvalConstants.classifyCpl(100),
          equals(MoveClassification.inaccuracy),
        );
      });

      test('classifyCpl: CPL 101-200 → Mistake', () {
        expect(
          EvalConstants.classifyCpl(101),
          equals(MoveClassification.mistake),
        );
        expect(
          EvalConstants.classifyCpl(200),
          equals(MoveClassification.mistake),
        );
      });

      test('classifyCpl: CPL > 200 → Blunder', () {
        expect(
          EvalConstants.classifyCpl(201),
          equals(MoveClassification.blunder),
        );
        expect(
          EvalConstants.classifyCpl(500),
          equals(MoveClassification.blunder),
        );
      });

      test('toCentipawns converts correctly', () {
        expect(EvalConstants.toCentipawns(1.0), equals(100));
        expect(EvalConstants.toCentipawns(0.5), equals(50));
        expect(EvalConstants.toCentipawns(0.0), equals(0));
        expect(EvalConstants.toCentipawns(-1.5), equals(-150));
      });
    });

    // ── classifyMove ───────────────────────────────────────────

    group('classifyMove', () {
      test('best move match returns Best', () {
        final result = classifyMove(
          evalBefore: 0.5,
          evalAfter: 0.5,
          isWhiteMove: true,
          bestMove: 'e2e4',
          actualMove: 'e2e4',
        );
        expect(result, equals(MoveClassification.best));
      });

      test('best move match is case-insensitive', () {
        final result = classifyMove(
          evalBefore: 0.5,
          evalAfter: 0.5,
          isWhiteMove: true,
          bestMove: 'E2E4',
          actualMove: 'e2e4',
        );
        expect(result, equals(MoveClassification.best));
      });

      test('no bestMove falls through to CPL classification', () {
        final result = classifyMove(
          evalBefore: 0.5,
          evalAfter: 0.5,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'e2e4',
        );
        expect(result, equals(MoveClassification.best)); // CPL = 0
      });

      test('CPL = 0 → Best', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: 1.0,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'e2e4',
        );
        expect(result, equals(MoveClassification.best));
      });

      test('CPL = 10cp → Excellent', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: 0.9,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'd2d4',
        );
        expect(result, equals(MoveClassification.excellent));
      });

      test('CPL = 30cp → Good', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: 0.7,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'd2d4',
        );
        expect(result, equals(MoveClassification.good));
      });

      test('CPL = 75cp → Inaccuracy', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: 0.25,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'd2d4',
        );
        expect(result, equals(MoveClassification.inaccuracy));
      });

      test('CPL = 150cp → Mistake', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: -0.5,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'd2d4',
        );
        expect(result, equals(MoveClassification.mistake));
      });

      test('CPL = 300cp → Blunder', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: -2.0,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'd2d4',
        );
        expect(result, equals(MoveClassification.blunder));
      });

      test('improvement (< -50cp) → Excellent', () {
        final result = classifyMove(
          evalBefore: 0.0,
          evalAfter: 1.0,
          isWhiteMove: true,
          bestMove: null,
          actualMove: 'e2e4',
        );
        expect(result, equals(MoveClassification.excellent));
      });

      test('black move CPL = 300cp → Blunder', () {
        final result = classifyMove(
          evalBefore: -1.0,
          evalAfter: 2.0,
          isWhiteMove: false,
          bestMove: null,
          actualMove: 'e7e5',
        );
        // Loss: 2.0 - (-1.0) = 3.0 pawns = 300cp
        expect(result, equals(MoveClassification.blunder));
      });

      test('black move improvement → Excellent', () {
        final result = classifyMove(
          evalBefore: 1.0,
          evalAfter: -1.0,
          isWhiteMove: false,
          bestMove: null,
          actualMove: 'e7e5',
        );
        // Loss: -1.0 - 1.0 = -2.0 pawns = -200cp (improvement)
        expect(result, equals(MoveClassification.excellent));
      });
    });

    // ── Mate Handling in classifyMove ─────────────────────────

    group('classifyMove mate handling', () {
      test('mate score: best move match → Best', () {
        final result = classifyMove(
          evalBefore: 1500, // Mate score (white winning)
          evalAfter: 1500,
          isWhiteMove: true,
          bestMove: 'qg7h7',
          actualMove: 'qg7h7',
        );
        expect(result, equals(MoveClassification.best));
      });

      test(
        'mate score: blunder from non-mate to mate for player → Blunder',
        () {
          final result = classifyMove(
            evalBefore: 0.0, // Equal position
            evalAfter: 1500, // White now has forced mate — bad for black
            isWhiteMove: false,
            bestMove: null,
            actualMove: 'f7f6',
          );
          expect(result, equals(MoveClassification.blunder));
        },
      );
    });

    // ── MoveAnalysis ─────────────────────────────────────────────

    group('MoveAnalysis', () {
      MoveAnalysis makeAnalysis({
        double evalBefore = 0.0,
        double evalAfter = 0.0,
        bool isWhiteMove = true,
        MoveClassification classification = MoveClassification.best,
      }) {
        final cpl = computeCentipawnLoss(
          evalBefore: evalBefore,
          evalAfter: evalAfter,
          isWhiteMove: isWhiteMove,
        );
        final acc = computeAccuracy(
          evalBefore: evalBefore,
          evalAfter: evalAfter,
          isWhiteMove: isWhiteMove,
        );
        return MoveAnalysis(
          moveIndex: 0,
          san: 'e4',
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          evalBefore: evalBefore,
          evalAfter: evalAfter,
          bestMove: null,
          classification: classification,
          engineLines: const [],
          isWhiteMove: isWhiteMove,
          centipawnLoss: cpl,
          accuracy: acc,
        );
      }

      test('perfect move stores CPL=0 and accuracy=100', () {
        final m = makeAnalysis();
        expect(m.centipawnLoss, equals(0));
        expect(m.accuracy, equals(100.0));
        expect(m.evalLoss, equals(0.0));
      });

      test('blunder stores correct CPL and accuracy', () {
        final m = makeAnalysis(
          evalBefore: 1.0,
          evalAfter: -2.0,
          classification: MoveClassification.blunder,
        );
        expect(m.centipawnLoss, equals(300));
        expect(m.accuracy, lessThan(50));
        expect(m.wasBestMove, isFalse);
      });

      test('best move detection', () {
        final m = makeAnalysis(classification: MoveClassification.best);
        expect(m.wasBestMove, isTrue);
      });

      test('white evalLoss: positive = loss', () {
        final m = makeAnalysis(
          evalBefore: 1.0,
          evalAfter: 0.5,
          isWhiteMove: true,
          classification: MoveClassification.good,
        );
        expect(m.evalLoss, equals(0.5));
      });

      test('black evalLoss: positive = loss', () {
        final m = makeAnalysis(
          evalBefore: 0.0,
          evalAfter: 0.5,
          isWhiteMove: false,
          classification: MoveClassification.good,
        );
        expect(m.evalLoss, equals(0.5)); // 0.5 - 0.0 = 0.5
      });
    });

    // ── GameAnalysis.fromMoves ─────────────────────────────────

    group('GameAnalysis.fromMoves', () {
      test('empty moves → empty analysis', () {
        final ga = GameAnalysis.fromMoves([]);
        expect(ga.averageAccuracy, equals(0.0));
        expect(ga.averageCpl, equals(0));
        expect(ga.moves, isEmpty);
      });

      test('single perfect move', () {
        final moves = [
          MoveAnalysis(
            moveIndex: 0,
            san: 'e4',
            fen: '...',
            evalBefore: 0.0,
            evalAfter: 0.0,
            bestMove: null,
            classification: MoveClassification.best,
            engineLines: const [],
            isWhiteMove: true,
            centipawnLoss: 0,
            accuracy: 100.0,
          ),
        ];
        final ga = GameAnalysis.fromMoves(moves);
        expect(ga.averageAccuracy, equals(100.0));
        expect(ga.averageCpl, equals(0));
        expect(ga.bestMoves, equals(1));
        expect(ga.blunders, equals(0));
      });

      test('mixed quality game', () {
        final moves = [
          MoveAnalysis(
            moveIndex: 0,
            san: 'e4',
            fen: '...',
            evalBefore: 0.0,
            evalAfter: 0.2,
            bestMove: null,
            classification: MoveClassification.excellent,
            engineLines: const [],
            isWhiteMove: true,
            centipawnLoss: -20, // improvement
            accuracy: 100.0,
          ),
          MoveAnalysis(
            moveIndex: 1,
            san: 'e5',
            fen: '...',
            evalBefore: 0.2,
            evalAfter: 0.5,
            bestMove: null,
            classification: MoveClassification.inaccuracy,
            engineLines: const [],
            isWhiteMove: false,
            centipawnLoss: 30, // mild loss for black
            accuracy: 91.39,
          ),
          MoveAnalysis(
            moveIndex: 2,
            san: 'Nf3',
            fen: '...',
            evalBefore: 0.5,
            evalAfter: -2.5,
            bestMove: null,
            classification: MoveClassification.blunder,
            engineLines: const [],
            isWhiteMove: true,
            centipawnLoss: 300,
            accuracy: 40.66,
          ),
        ];
        final ga = GameAnalysis.fromMoves(moves);
        expect(ga.bestMoves, equals(0));
        expect(ga.excellentMoves, equals(1));
        expect(ga.inaccuracies, equals(1));
        expect(ga.blunders, equals(1));
        expect(ga.averageCpl, closeTo((-20 + 30 + 300) / 3, 0.01));
        expect(ga.averageAccuracy, closeTo((100 + 91.39 + 40.66) / 3, 0.1));
      });

      test('all classification types counted correctly', () {
        final classificationTypes = [
          MoveClassification.blunder,
          MoveClassification.miss,
          MoveClassification.mistake,
          MoveClassification.inaccuracy,
          MoveClassification.good,
          MoveClassification.great,
          MoveClassification.excellent,
          MoveClassification.brilliant,
          MoveClassification.best,
          MoveClassification.forced,
          MoveClassification.onlyMove,
          MoveClassification.book,
        ];
        final moves =
            classificationTypes.asMap().entries.map((e) {
              return MoveAnalysis(
                moveIndex: e.key,
                san: 'm${e.key}',
                fen: '...',
                evalBefore: 0.0,
                evalAfter: 0.0,
                bestMove: null,
                classification: e.value,
                engineLines: const [],
                isWhiteMove: true,
                centipawnLoss: 0,
                accuracy: 100.0,
              );
            }).toList();

        final ga = GameAnalysis.fromMoves(moves);
        expect(ga.blunders, equals(1));
        expect(ga.misses, equals(1));
        expect(ga.mistakes, equals(1));
        expect(ga.inaccuracies, equals(1));
        expect(ga.goodMoves, equals(1));
        expect(ga.greatMoves, equals(1));
        expect(ga.excellentMoves, equals(1));
        expect(ga.brilliantMoves, equals(1));
        expect(ga.bestMoves, equals(3)); // best + forced + onlyMove
        expect(ga.bookMoves, equals(1));
      });

      test('evaluations list includes initial eval before first move', () {
        final moves = [
          MoveAnalysis(
            moveIndex: 0,
            san: 'e4',
            fen: '...',
            evalBefore: 0.0,
            evalAfter: 0.2,
            bestMove: null,
            classification: MoveClassification.good,
            engineLines: const [],
            isWhiteMove: true,
            centipawnLoss: 0,
            accuracy: 100.0,
          ),
        ];
        final ga = GameAnalysis.fromMoves(moves);
        expect(ga.evaluations, hasLength(2)); // before + after
        expect(ga.evaluations[0], equals(0.0));
        expect(ga.evaluations[1], equals(0.2));
      });
    });

    // ── Accuracy Symmetry ─────────────────────────────────────

    group('Accuracy Symmetry', () {
      test('white losing 1 pawn = black losing 1 pawn → same accuracy', () {
        final whiteAcc = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: 0.0,
          isWhiteMove: true,
        );
        final blackAcc = computeAccuracy(
          evalBefore: 0.0,
          evalAfter: 1.0,
          isWhiteMove: false,
        );
        expect(whiteAcc, closeTo(blackAcc, 0.001));
      });

      test('white perfect play = black perfect play', () {
        final whiteAcc = computeAccuracy(
          evalBefore: 0.5,
          evalAfter: 0.5,
          isWhiteMove: true,
        );
        final blackAcc = computeAccuracy(
          evalBefore: 0.5,
          evalAfter: 0.5,
          isWhiteMove: false,
        );
        expect(whiteAcc, equals(100.0));
        expect(blackAcc, equals(100.0));
      });
    });

    // ── Edge cases ────────────────────────────────────────────

    group('Edge Cases', () {
      test('very large eval values do not overflow accuracy', () {
        final acc = computeAccuracy(
          evalBefore: 100.0,
          evalAfter: -100.0,
          isWhiteMove: true,
        );
        expect(acc, greaterThanOrEqualTo(0.0));
        expect(acc, lessThan(1.0)); // Severe blunder
      });

      test('zero eval before and after → perfect 100%', () {
        final acc = computeAccuracy(
          evalBefore: 0.0,
          evalAfter: 0.0,
          isWhiteMove: true,
        );
        expect(acc, equals(100.0));
      });

      test('negative eval improvement for white → 100%', () {
        final acc = computeAccuracy(
          evalBefore: -1.0,
          evalAfter: -0.5,
          isWhiteMove: true,
        );
        // evalBefore - evalAfter = -1.0 - (-0.5) = -0.5 (improvement)
        expect(acc, equals(100.0));
      });

      test('negative eval improvement for black → 100%', () {
        final acc = computeAccuracy(
          evalBefore: 1.0,
          evalAfter: -1.0,
          isWhiteMove: false,
        );
        // evalAfter - evalBefore = -1.0 - 1.0 = -2.0 (improvement)
        expect(acc, equals(100.0));
      });
    });
  });
}
