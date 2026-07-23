import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_test.dart';

class MockGameSessionRepository extends Fake implements GameSessionRepository {
  @override
  Future<void> saveSession(GameSession session) async {}

  @override
  Future<GameSession?> getSession(String id) async => null;

  @override
  Future<List<GameSession>> getAllSessions({int? limit, int? offset}) async => [];

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<void> clearAll() async {}
}

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
      overrides: [
        databaseServiceProvider.overrideWithValue(MockDatabaseService()),
        stockfishServiceProvider.overrideWithValue(MockStockfishService()),
        gameSessionRepositoryProvider.overrideWithValue(MockGameSessionRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const GameScreenLoader(),
      ),
    );
  }

  group('Mid-Game Control Bar Tests', () {
    testWidgets('Primary control bar renders 4 action buttons (Undo, Hint, Flip, Resign)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(themeMode: ThemeMode.light));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byTooltip('Undo Move'), findsOneWidget);
      expect(find.byTooltip('Engine Hint'), findsOneWidget);
      expect(find.byTooltip('Flip Board'), findsWidgets);
      expect(find.byTooltip('Resign Game'), findsOneWidget);
    });

    testWidgets('Tapping Resign Game button opens confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(themeMode: ThemeMode.dark));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final resignButton = find.byTooltip('Resign Game');
      expect(resignButton, findsOneWidget);

      await tester.tap(resignButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Resign Game?'), findsOneWidget);
      expect(find.text('Are you sure you want to resign this match?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}

class GameScreenLoader extends ConsumerStatefulWidget {
  const GameScreenLoader({super.key});

  @override
  ConsumerState<GameScreenLoader> createState() => _GameScreenLoaderState();
}

class _GameScreenLoaderState extends ConsumerState<GameScreenLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameSessionProvider.notifier).startNewGame(
            gameMode: GameMode.bot,
            difficulty: AppConstants.difficultyLevels.first,
            timeControl: AppConstants.timeControls[0],
            playerColor: PlayerColor.white,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const GameScreen();
  }
}
