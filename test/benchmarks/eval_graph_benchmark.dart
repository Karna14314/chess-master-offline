class FlSpot {
  final double x;
  final double y;
  FlSpot(this.x, this.y);
}

void main() {
  // Setup data
  final evaluations = List.generate(10000, (i) => (i % 20) - 10.0 + (i % 5));

  // Warmup
  for (int i = 0; i < 100; i++) {
    runBaseline(evaluations);
    runOptimized(evaluations);
  }

  // Benchmark Baseline
  final stopwatchBaseline = Stopwatch()..start();
  for (int i = 0; i < 1000; i++) {
    runBaseline(evaluations);
  }
  stopwatchBaseline.stop();
  print('Baseline: ${stopwatchBaseline.elapsedMicroseconds} us');

  // Benchmark Optimized
  final stopwatchOptimized = Stopwatch()..start();
  for (int i = 0; i < 1000; i++) {
    runOptimized(evaluations);
  }
  stopwatchOptimized.stop();
  print('Optimized: ${stopwatchOptimized.elapsedMicroseconds} us');

  final improvement =
      (stopwatchBaseline.elapsedMicroseconds -
          stopwatchOptimized.elapsedMicroseconds) /
      stopwatchBaseline.elapsedMicroseconds *
      100;
  print('Improvement: ${improvement.toStringAsFixed(2)}%');
}

void runBaseline(List<double> evaluations) {
  // Clamp evaluations for display
  final clampedEvals = evaluations.map((e) => e.clamp(-10.0, 10.0)).toList();

  // Create spots for the line chart
  final spots = <FlSpot>[];
  for (int i = 0; i < clampedEvals.length; i++) {
    spots.add(FlSpot(i.toDouble(), clampedEvals[i]));
  }

  // Find min/max for gradient
  final minEval = clampedEvals.reduce((a, b) => a < b ? a : b);
  final maxEval = clampedEvals.reduce((a, b) => a > b ? a : b);

  // Prevent dead code elimination (though not strictly needed in Dart VM usually for side-effect free code unless advanced AOT)
  // But strictly speaking reduce returns a value, spots is created.
}

void runOptimized(List<double> evaluations) {
  final spots = List.generate(
    evaluations.length,
    (i) => FlSpot(i.toDouble(), evaluations[i].clamp(-10.0, 10.0)),
  );
}
