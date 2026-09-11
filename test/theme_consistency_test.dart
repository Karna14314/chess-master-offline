import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/analysis/pgn_import_screen.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Theme-Aware Color Helpers', () {
    testWidgets('cardColor returns cardLight in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              expect(AppTheme.cardColor(context), equals(AppTheme.cardLight));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('cardColor returns cardDark in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              expect(AppTheme.cardColor(context), equals(AppTheme.cardDark));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('borderColorFor returns borderLight in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              expect(
                AppTheme.borderColorFor(context),
                equals(AppTheme.borderLight),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('borderColorFor returns borderColor in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              expect(
                AppTheme.borderColorFor(context),
                equals(AppTheme.borderColor),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('textPrimaryFor returns textPrimaryLight in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              expect(
                AppTheme.textPrimaryFor(context),
                equals(AppTheme.textPrimaryLight),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('textPrimaryFor returns textPrimary in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              expect(
                AppTheme.textPrimaryFor(context),
                equals(AppTheme.textPrimary),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('surfaceColor returns surfaceLight in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              expect(
                AppTheme.surfaceColor(context),
                equals(AppTheme.surfaceLight),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('surfaceColor returns surfaceDark in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              expect(
                AppTheme.surfaceColor(context),
                equals(AppTheme.surfaceDark),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('Screen Rendering Tests', () {
    testWidgets('PgnImportScreen renders in light mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            home: const PgnImportScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Import PGN'), findsOneWidget);
      expect(find.text('Analyze Game'), findsOneWidget);
    });

    testWidgets('PgnImportScreen renders in dark mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const PgnImportScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Import PGN'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders in light mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => SettingsNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Appearance'), findsOneWidget);
    });
  });
}
