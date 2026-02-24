import 'package:chess_master/core/services/lightweight_engine_service.dart';

class EngineEvaluationBenchmark {
  late LightweightEngineService engine;
  // A mid-game position with more pieces/complexity
  final String complexFen =
      'r1bqk2r/pp2bppp/2n2n2/2pp4/3P4/2N2N2/PPP1BPPP/R1BQ1RK1 w kq - 4 8';

  void setup() {
    engine = LightweightEngineService.instance;
  }

  Future<void> runAsync() async {
    await engine.getBestMove(complexFen, 3);
  }
}

Future<void> main() async {
  // Custom manual benchmark
  final benchmark = EngineEvaluationBenchmark();
  benchmark.setup();

  print('Warming up...');
  for (int i = 0; i < 5; i++) {
    await benchmark.runAsync();
  }

  print('Running benchmark (20 iterations)...');
  final stopwatch = Stopwatch()..start();
  final iterations = 20;
  for (int i = 0; i < iterations; i++) {
    await benchmark.runAsync();
  }
  stopwatch.stop();

  print('Total time: ${stopwatch.elapsedMilliseconds} ms');
  print('Average time: ${stopwatch.elapsedMilliseconds / iterations} ms');
}
