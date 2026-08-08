import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/screens/analysis/widgets/move_navigation_bar.dart';

void main() {
  testWidgets('MoveNavigationBar renders without overflow on 360dp width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: MoveNavigationBar(
              canGoPrevious: true,
              canGoNext: true,
              currentMove: 10,
              totalMoves: 36,
              onFirst: () {},
              onPrevious: () {},
              onNext: () {},
              onLast: () {},
              onJumpToPreviousMistake: () {},
              onJumpToNextMistake: () {},
              onPracticeFromHere: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Prev Mistake'), findsOneWidget);
    expect(find.text('Next Mistake'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('MoveNavigationBar renders without overflow on 412dp width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: MoveNavigationBar(
              canGoPrevious: true,
              canGoNext: true,
              currentMove: 10,
              totalMoves: 36,
              onFirst: () {},
              onPrevious: () {},
              onNext: () {},
              onLast: () {},
              onJumpToPreviousMistake: () {},
              onJumpToNextMistake: () {},
              onPracticeFromHere: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Prev Mistake'), findsOneWidget);
    expect(find.text('Next Mistake'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
  });
}
