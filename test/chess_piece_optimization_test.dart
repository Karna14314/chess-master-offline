import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/core/theme/board_themes.dart';

void main() {
  testWidgets('ChessPiece is wrapped in RepaintBoundary', (
    WidgetTester tester,
  ) async {
    // Build the ChessPiece widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChessPiece(
            piece: 'wK',
            size: 50.0,
            pieceSet: PieceSet.traditional,
          ),
        ),
      ),
    );

    // Verify that RepaintBoundary is present specifically inside ChessPiece
    expect(
      find.descendant(
        of: find.byType(ChessPiece),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });
}
