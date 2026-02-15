import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/core/theme/board_themes.dart';

// Minimal MockCanvas to avoid errors
class MockCanvas implements Canvas {
  @override
  void drawRect(Rect rect, Paint paint) {}

  @override
  void drawCircle(Offset c, double radius, Paint paint) {}

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {}

  @override
  void drawPath(Path path, Paint paint) {}

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void translate(double dx, double dy) {}

  @override
  int getSaveCount() => 1;

  // Implement other methods as no-ops if needed, or rely on them not being called by BoardPainter
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Return something safe or null for void methods
    return null;
  }
}

void main() {
  test('BoardPainter Performance Benchmark', () {
    final painter = BoardPainter(
      theme: BoardTheme.classicWood,
      getPieceAt: (square) => null, // No pieces for this benchmark
      legalMoves: ['e2', 'e4'], // Add some legal moves to trigger that logic
    );

    final canvas = MockCanvas();
    final size = const Size(800, 800);

    // Warmup
    for (int i = 0; i < 100; i++) {
      painter.paint(canvas, size);
    }

    // Benchmark
    final stopwatch = Stopwatch()..start();
    const iterations = 10000;

    for (int i = 0; i < iterations; i++) {
      painter.paint(canvas, size);
    }

    stopwatch.stop();

    print(
      'Benchmark finished: ${stopwatch.elapsedMilliseconds}ms for $iterations iterations',
    );
    print(
      'Average time per paint: ${stopwatch.elapsedMicroseconds / iterations}µs',
    );
  });
}
