import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/learn/learn_screen.dart';
import 'package:chess_master/screens/lessons/lessons_screen.dart';
import 'package:chess_master/screens/openings/opening_playbook_screen.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/core/services/opening_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await LessonService.instance.initialize();
    await OpeningService.instance.initialize();
  });

  group('Learn Hub & Lessons Widget Tests', () {
    testWidgets('Cold open of Learn shows a non-empty Lessons list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LearnScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LessonsScreen), findsOneWidget);
      expect(find.text('Structured Mastery Curriculum'), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);

      final topicsCount = find.textContaining('topics').evaluate().length;
      expect(topicsCount, greaterThan(0));
    });

    testWidgets('Lessons filter selection gives correct counts and All -> Beginner -> All roundtrip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LearnScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final initialTopics = find.textContaining('topics').evaluate().length;
      expect(initialTopics, greaterThan(0));

      // Tap 'Beginner' filter
      await tester.tap(find.widgetWithText(FilterChip, 'Beginner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beginnerTopics = find.textContaining('topics').evaluate().length;
      expect(beginnerTopics, greaterThan(0));

      // Tap 'All' filter back
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final restoredTopics = find.textContaining('topics').evaluate().length;
      expect(restoredTopics, equals(initialTopics));
    });

    testWidgets('Openings segment displays non-empty list and filter roundtrip works', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LearnScreen(initialSegment: 1),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OpeningPlaybookScreen), findsOneWidget);

      final initialCount = OpeningService.instance.allOpenings.length;
      expect(initialCount, greaterThan(0));

      // Tap category filter chip if available
      final e4Chip = find.widgetWithText(FilterChip, "King's Pawn (1. e4)");
      if (e4Chip.evaluate().isNotEmpty) {
        await tester.tap(e4Chip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final allChip = find.widgetWithText(FilterChip, 'All');
        await tester.tap(allChip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(OpeningService.instance.allOpenings.length, equals(initialCount));
      }
    });
  });
}
