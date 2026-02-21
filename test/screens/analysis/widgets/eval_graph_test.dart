import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:chess_master/screens/analysis/widgets/eval_graph.dart';

void main() {
  testWidgets('EvalGraph renders correctly with data', (
    WidgetTester tester,
  ) async {
    final evaluations = [0.5, 12.0, -15.0, 3.0];

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: EvalGraph(evaluations: evaluations))),
    );

    // Verify chart is present
    expect(find.byType(LineChart), findsOneWidget);

    // Verify "No evaluation data" text is NOT present
    expect(find.text('No evaluation data'), findsNothing);

    // Verify Chart Data
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final data = chart.data;

    expect(data.lineBarsData.length, 1);
    final spots = data.lineBarsData[0].spots;

    expect(spots.length, 4);

    // Check clamping
    expect(spots[0].y, 0.5);
    expect(spots[1].y, 10.0); // Clamped to 10
    expect(spots[2].y, -10.0); // Clamped to -10
    expect(spots[3].y, 3.0);
  });

  testWidgets('EvalGraph displays message when empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EvalGraph(evaluations: []))),
    );

    expect(find.text('No evaluation data'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
