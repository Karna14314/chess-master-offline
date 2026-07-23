import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/main.dart';
import 'package:chess_master/screens/onboarding/onboarding_screen.dart';
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

  group('Onboarding Flow Tests', () {
    testWidgets('First launch loads OnboardingScreen via AppOnboardingGateway', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AppOnboardingGateway(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('100% Offline & Ad-Free'), findsOneWidget);
    });

    testWidgets('Subsequent launch bypasses OnboardingScreen when completed', (tester) async {
      SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AppOnboardingGateway(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('Navigating through Onboarding pages and selecting Intermediate skill level', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1: Welcome
      expect(find.text('100% Offline & Ad-Free'), findsOneWidget);

      // Tap Continue to Page 2 (Skill Level Picker)
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Skill Level'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);

      // Select Intermediate skill level
      await tester.tap(find.text('Intermediate'));
      await tester.pumpAndSettle();

      // Tap Continue to Page 3 (Features)
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Everything You Need'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });
}
