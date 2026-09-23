import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/core/theme/board_themes.dart';

void main() {
  testWidgets(
    'ChessPiece has no per-piece RepaintBoundary (v90 stability)',
    (WidgetTester tester) async {
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

      // v90 stability: per-piece boundaries (~32 GPU layers) caused
      // skgpu TClientMappedBufferManager SIGSEGVs on low-end arm64.
      // Isolation lives at the board level (one RepaintBoundary around the
      // whole stack in ChessBoard) instead of inside each piece.
      expect(
        find.descendant(
          of: find.byType(ChessPiece),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );
    },
  );
}
