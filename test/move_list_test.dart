import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/screens/game/widgets/move_list.dart';
import 'package:chess_master/models/game_model.dart';

void main() {
  testWidgets('MoveList displays moves correctly', (WidgetTester tester) async {
    // Create dummy moves
    final moves = [
      ChessMove(
        from: 'e2',
        to: 'e4',
        san: 'e4',
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        isCastle: false,
        fen: 'fen1',
      ),
      ChessMove(
        from: 'e7',
        to: 'e5',
        san: 'e5',
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        isCastle: false,
        fen: 'fen2',
      ),
      ChessMove(
        from: 'g1',
        to: 'f3',
        san: 'Nf3',
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        isCastle: false,
        fen: 'fen3',
      ),
      ChessMove(
        from: 'b8',
        to: 'c6',
        san: 'Nc6',
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        isCastle: false,
        fen: 'fen4',
      ),
      ChessMove(
        from: 'f1',
        to: 'b5',
        san: 'Bb5',
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        isCastle: false,
        fen: 'fen5',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MoveList(moves: moves)),
        ),
      ),
    );

    // Verify move numbers
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);

    // Verify moves are displayed
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('Nf3'), findsOneWidget);
    expect(find.text('Nc6'), findsOneWidget);
    expect(find.text('Bb5'), findsOneWidget);
  });
}
