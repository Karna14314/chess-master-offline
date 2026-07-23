import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/screens/main_screen.dart';
import 'package:chess_master/screens/more/more_screen.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'widget_test.dart';

class _MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => 0;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  group('Cross-Promotion & MoreScreen Tests', () {
    testWidgets('MainScreen navigation contains More tab and loads MoreScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(MockDatabaseService()),
            stockfishServiceProvider.overrideWithValue(MockStockfishService()),
          ],
          child: const MaterialApp(home: MainScreen()),
        ),
      );
      await tester.pump();

      // Verify 'More' tab is present in BottomNavigationBar
      expect(find.text('More'), findsOneWidget);

      // Tap on 'More' tab (index 4)
      await tester.tap(find.text('More'));
      await tester.pump();

      // Verify MoreScreen is rendered
      expect(find.byType(MoreScreen), findsOneWidget);
    });

    testWidgets('MoreScreen displays Explore Karna Digital Games cross-promotion section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWithValue(MockDatabaseService()),
            stockfishServiceProvider.overrideWithValue(MockStockfishService()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MoreScreen()),
          ),
        ),
      );
      await tester.pump();

      // Verify cross-promotion section header
      expect(find.text('Explore Karna Digital Games'), findsOneWidget);

      // Verify individual game titles
      expect(find.text('Mahjong Master Offline'), findsOneWidget);
      expect(find.text('Block Puzzle Master'), findsOneWidget);
      expect(find.text('Sudoku Master Offline'), findsOneWidget);
      expect(find.text('More Ad-Free Games'), findsOneWidget);
    });
  });
}
