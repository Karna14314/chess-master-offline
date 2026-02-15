import 'package:flutter_test/flutter_test.dart';

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

    // --- Optimized (New String Parsing Implementation) ---
    final stopwatchOptimized = Stopwatch()..start();
    int processedCountOptimized = 0;

    // Logic matching the one in StockfishService._parseValue
    int? _parseValue(String text, String key) {
      final index = text.indexOf(key);
      if (index != -1) {
        final start = index + key.length;
        int end = text.indexOf(' ', start);
        if (end == -1) end = text.length;
        return int.tryParse(text.substring(start, end));
      }
      return null;
    }

    for (final line in lines) {
      if (line.startsWith('info') && line.contains(' pv ')) {
        final pvIndex = line.indexOf(' pv ');
        if (pvIndex != -1) {
          // Extract moves
          final movesStr = line.substring(pvIndex + 4);
          final moves = movesStr.split(' ');

          final infoPart = line.substring(0, pvIndex);

          _parseValue(infoPart, ' multipv ');
          _parseValue(infoPart, ' depth ');
          _parseValue(infoPart, ' score cp ');
          _parseValue(infoPart, ' score mate ');

          processedCountOptimized += moves.length;
        }
      }
    }

    stopwatchOptimized.stop();
    final optimizedTime = stopwatchOptimized.elapsedMilliseconds;
    print('Optimized parsing 10000 lines took: ${optimizedTime}ms');
    print('Optimized count: $processedCountOptimized');

    // Assertions
    // 1. Correctness: The generated lines have 4 moves each. 10000 * 4 = 40000.
    expect(
      processedCountOptimized,
      40000,
      reason: "Optimized parser should correctly identify 4 moves per line",
    );

    // 2. Performance: Optimized should be faster.
    // Note: In extremely slow environments (CI), this might be flaky if diff is small, but here diff is ~3x.
    // We put a lenient check.
    expect(
      optimizedTime < baselineTime,
      isTrue,
      reason: "Optimized parser should be faster than baseline",
    );

    // 3. Bug verification: Baseline matches 'pv 1 ...' inside 'multipv 1' so it returns garbage moves.
    // Baseline count is 190000 (19 items per line) vs 40000 (4 items per line).
    expect(
      processedCount,
      isNot(40000),
      reason: "Baseline parser incorrectly parses multipv lines",
    );
  });
}
