import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';

void main() {
  test('All chess piece assets exist on disk', () {
    final sets = [PieceSet.traditional, PieceSet.modern];
    final pieces = PieceAssets.allPieceCodes;

    for (final set in sets) {
      for (final piece in pieces) {
        final path = set.getAssetPath(piece);
        final file = File(path);

        // Check if file exists
        expect(file.existsSync(), isTrue,
          reason: 'Asset not found at path: $path (Set: ${set.name}, Piece: $piece)');

        // Check if file is not empty
        expect(file.lengthSync(), greaterThan(0),
          reason: 'Asset is empty at path: $path (Set: ${set.name}, Piece: $piece)');
      }
    }
  });
}
