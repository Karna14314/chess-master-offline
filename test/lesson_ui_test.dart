import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/screens/lessons/lessons_screen.dart';
import 'package:chess_master/screens/lessons/lesson_player_screen.dart';

void main() {
  setUp(() async {
    await LessonService.instance.initialize();
  });

  testWidgets('LessonsScreen renders sections, categories, and search bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LessonsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title
    expect(find.text('Chess Lessons'), findsOneWidget);
    // Verify curriculum subtitle
    expect(find.text('Structured Mastery Curriculum'), findsOneWidget);
    // Verify at least one of the major section headings
    expect(find.text('Checkmate Mastery'), findsOneWidget);
    // Verify search bar presence
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('LessonPlayerScreen renders concept intro then chapter', (tester) async {
    final category = LessonService.instance.getCategory('mate_back_rank');
    expect(category, isNotNull);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LessonPlayerScreen(
            categoryId: 'mate_back_rank',
            initialChapterIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify exercise header
    expect(find.textContaining('Exercise 1 of'), findsOneWidget);
    // v2 concept intro shows the idea + start button
    expect(find.text('The Idea'), findsOneWidget);
    expect(find.text('Start Practicing'), findsOneWidget);

    // Enter play phase
    await tester.tap(find.text('Start Practicing'));
    await tester.pumpAndSettle();

    // Verify action buttons
    expect(find.text('Get Hint'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });
}
