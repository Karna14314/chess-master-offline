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
    testWidgets('Renders Daily Streak badge, Daily Puzzle Hero, and Game Mode tiles in light theme', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(themeMode: ThemeMode.light));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Header and Streak Badge
      expect(find.text('Welcome Back,'), findsOneWidget);
      expect(find.text('Chess Master'), findsOneWidget);
      expect(find.textContaining('Day'), findsWidgets);

      // Verify Daily Puzzle Hero
      expect(find.textContaining('TODAY\'S DAILY PUZZLE'), findsOneWidget);
      expect(find.text('Solve Daily Puzzle Now'), findsOneWidget);

      // Verify Game Modes Grid
      expect(find.text('Play Bot'), findsOneWidget);
      expect(find.text('Daily Puzzle'), findsOneWidget);
      expect(find.text('Play Friend'), findsOneWidget);
      expect(find.text('Analyze Game'), findsOneWidget);
    });

    testWidgets('Renders dynamic dashboard cleanly in dark theme mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(themeMode: ThemeMode.dark));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Welcome Back,'), findsOneWidget);
      expect(find.text('Quick Play vs AI'), findsOneWidget);
    });

    testWidgets('Tapping Solve Daily Puzzle Hero navigates to DailyPuzzleScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(themeMode: ThemeMode.light));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final solveButton = find.text('Solve Daily Puzzle Now');
      expect(solveButton, findsOneWidget);

      await tester.tap(solveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DailyPuzzleScreen), findsOneWidget);
    });
  });
}
