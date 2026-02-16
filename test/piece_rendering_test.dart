import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/core/theme/board_themes.dart';

void main() {
  group('Piece Rendering Tests', () {
    testWidgets('ChessPiece widget renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChessPiece(
                piece: 'wK',
                size: 64,
                pieceSet: PieceSet.traditional,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify the widget is present
      expect(find.byType(ChessPiece), findsOneWidget);
    });

    testWidgets('All piece types render', (tester) async {
      final pieces = [
        'wK',
        'wQ',
        'wR',
        'wB',
        'wN',
        'wP',
        'bK',
        'bQ',
        'bR',
        'bB',
        'bN',
        'bP',
      ];

      for (final piece in pieces) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChessPiece(
                  piece: piece,
                  size: 64,
                  pieceSet: PieceSet.traditional,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(ChessPiece), findsOneWidget);
      }
    });

    test('PieceSet generates correct asset paths', () {
      final traditional = PieceSet.traditional;
      expect(
        traditional.getAssetPath('wK'),
        'assets/pieces/traditional/wK.svg',
      );
      expect(
        traditional.getAssetPath('bQ'),
        'assets/pieces/traditional/bQ.svg',
      );

      final modern = PieceSet.modern;
      expect(modern.getAssetPath('wK'), 'assets/pieces/modern/wK.svg');
      expect(modern.getAssetPath('bQ'), 'assets/pieces/modern/bQ.svg');
    });
  });
}
