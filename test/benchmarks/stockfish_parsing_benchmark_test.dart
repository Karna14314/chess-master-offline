import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/stockfish_service.dart';

void main() {
  test('Stockfish parsing benchmark and correctness', () {
    // Generate test data
    final lines = List.generate(10000, (i) {
      if (i % 10 == 0) {
        return 'info depth 20 seldepth 30 multipv 1 score mate ${i % 10} nodes 1000000 nps 1000000 hashfull 50 tbhits 0 time 1000 pv e2e4 e7e5 g1f3 b8c6';
      }
      return 'info depth ${i % 30} seldepth 30 multipv 1 score cp ${i * 10} nodes 1000000 nps 1000000 hashfull 50 tbhits 0 time 1000 pv e2e4 e7e5 g1f3 b8c6';
    });

    // --- Baseline (Old Regex Implementation) ---
    final stopwatch = Stopwatch()..start();
    final RegExp _scoreCpRegex = RegExp(r'score cp (-?\d+)');
    final RegExp _scoreMateRegex = RegExp(r'score mate (-?\d+)');
    final RegExp _multiPvRegex = RegExp(r'multipv (\d+)');
    final RegExp _depthRegex = RegExp(r'depth (\d+)');
    final RegExp _pvMovesRegex = RegExp(r'pv (.+)$');

    int processedCount = 0;

    for (final line in lines) {
      if (line.startsWith('info') && line.contains('pv')) {
        final pvMatch = _multiPvRegex.firstMatch(line);
        final depthMatch = _depthRegex.firstMatch(line);
        final scoreMatch = _scoreCpRegex.firstMatch(line);
        final mateMatch = _scoreMateRegex.firstMatch(line);
        final pvMovesMatch = _pvMovesRegex.firstMatch(line);

        if (pvMovesMatch != null) {
          // Parsing numbers (simulating work)
          if (pvMatch != null) int.parse(pvMatch.group(1)!);
          if (depthMatch != null) int.parse(depthMatch.group(1)!);
          if (scoreMatch != null) int.parse(scoreMatch.group(1)!);
          if (mateMatch != null) int.parse(mateMatch.group(1)!);

          final moves = pvMovesMatch.group(1)!.split(' ');
          processedCount += moves.length;
        }
      }
    }

    stopwatch.stop();
    final baselineTime = stopwatch.elapsedMilliseconds;
    print('Baseline parsing 10000 lines took: ${baselineTime}ms');
    print('Baseline count (known buggy): $processedCount');

    // --- Optimized (Actual Implementation) ---
    final stopwatchOptimized = Stopwatch()..start();
    int processedCountOptimized = 0;

    for (final line in lines) {
      // We use the actual production parser
      final info = StockfishParser.parse(line);
      if (info.moves.isNotEmpty) {
        processedCountOptimized += info.moves.length;
      }
    }

    stopwatchOptimized.stop();
    final optimizedTime = stopwatchOptimized.elapsedMilliseconds;
    print('Optimized parsing 10000 lines took: ${optimizedTime}ms');
    print('Optimized count: $processedCountOptimized');

    // Assertions
    // 1. Correctness: The generated lines have 4 moves each. 10000 * 4 = 40000.
    // However, some lines might be skipped if they are not 'info'.
    // Our test data only generates 'info' lines.
    expect(
      processedCountOptimized,
      40000,
      reason: "Optimized parser should correctly identify 4 moves per line",
    );

    // 2. Performance: Optimized should be faster.
    // Note: In extremely slow environments (CI), this might be flaky if diff is small.
    // But string splitting vs regex should be significant.
    expect(
      optimizedTime < baselineTime,
      isTrue,
      reason: "Optimized parser should be faster than baseline",
    );

    // 3. Bug verification: Baseline matches 'pv 1 ...' inside 'multipv 1' so it returns garbage moves.
    // Baseline count is typically much higher or wrong.
    expect(
      processedCount,
      isNot(40000),
      reason: "Baseline parser incorrectly parses multipv lines",
    );
  });
}
