import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/home/home_screen.dart';
import 'package:chess_master/screens/puzzles/daily_puzzle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestableWidget({required ThemeMode themeMode}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen Redesign Tests', () {
    testWidgets(
      'Renders Bot Arena, 12-Level Campaign, Quick Play, Lessons and History in light theme',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 6000);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestableWidget(themeMode: ThemeMode.light),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 1. Verify Header and Streak
        expect(find.text('Welcome Back,'), findsOneWidget);
        expect(find.text('Chess Master'), findsOneWidget);

        // 2. Verify Bot Arena (#1 Section)
        expect(find.text('Bot Arena'), findsOneWidget);
        expect(find.textContaining('Personalities'), findsOneWidget);
        expect(find.text('Scrub ELO'), findsOneWidget);

        // 3. Verify 12-Level Master Campaign (#2 Section)
        expect(find.text('12-Level Master Campaign'), findsOneWidget);
        expect(find.text('View Map'), findsOneWidget);

        // 4. Verify Quick Play (#3 Section)
        expect(find.text('Quick Play'), findsOneWidget);
        expect(find.text('Pass & Play'), findsOneWidget);
        expect(find.text('Daily Puzzle'), findsOneWidget);
        expect(find.text('Analyze Game'), findsOneWidget);

        // 5. Verify Learn & Master (#4 Section)
        expect(find.text('Learn & Master'), findsOneWidget);
        expect(find.text('Chess Lessons'), findsOneWidget);
        expect(find.text('Opening Playbook'), findsOneWidget);

        // 6. Verify Recent Games (#5 Section)
        expect(find.text('Recent Games'), findsOneWidget);
      },
    );

    testWidgets('Renders dynamic dashboard cleanly in dark theme mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(themeMode: ThemeMode.dark));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Welcome Back,'), findsOneWidget);
      expect(find.text('Bot Arena'), findsOneWidget);
      expect(find.text('12-Level Master Campaign'), findsOneWidget);
    });

    testWidgets(
      'Tapping Daily Puzzle in Quick Play navigates to DailyPuzzleScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestableWidget(themeMode: ThemeMode.light),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final dailyPuzzleTile = find.text('Daily Puzzle');
        expect(dailyPuzzleTile, findsOneWidget);

        await tester.tap(dailyPuzzleTile);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(DailyPuzzleScreen), findsOneWidget);
      },
    );
  });
}
