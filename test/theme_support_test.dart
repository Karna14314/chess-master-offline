import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/main_screen.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'widget_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Theme Support Tests', () {
    testWidgets('AppTheme defines distinct light and dark ThemeData', (WidgetTester tester) async {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, equals(Brightness.light));
      expect(dark.brightness, equals(Brightness.dark));

      expect(light.scaffoldBackgroundColor, equals(AppTheme.backgroundLight));
      expect(dark.scaffoldBackgroundColor, equals(AppTheme.backgroundDark));

      expect(light.colorScheme.surface, equals(AppTheme.surfaceLight));
      expect(dark.colorScheme.surface, equals(AppTheme.surfaceDark));
    });

    testWidgets('Scaffolds adapt dynamically to light theme mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(MockDatabaseService()),
            stockfishServiceProvider.overrideWithValue(MockStockfishService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: const MainScreen(),
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNot(equals(AppTheme.backgroundDark)));
    });

    testWidgets('Scaffolds adapt dynamically to dark theme mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(MockDatabaseService()),
            stockfishServiceProvider.overrideWithValue(MockStockfishService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const MainScreen(),
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNot(equals(AppTheme.backgroundLight)));
    });
  });
}
