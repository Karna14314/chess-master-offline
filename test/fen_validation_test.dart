import 'package:flutter_test/flutter_test.dart';

bool isValidFenDebug(String fen) {
  final fenSpaceRegex = RegExp(r'\s+');
  final fenDigitRegex = RegExp(r'[1-8]');
  final fenPieceRegex = RegExp(r'[prnbqkPRNBQK]');

  if (fen.isEmpty) return false;
  final parts = fen.trim().split(fenSpaceRegex);
  if (parts.length < 4) return false;

  final boardPart = parts[0];
  final rows = boardPart.split('/');
  if (rows.length != 8) return false;

  int whiteKingCount = 0;
  int blackKingCount = 0;
  int whitePawnCount = 0;
  int blackPawnCount = 0;
  int whiteNonPawnCount = 0;
  int blackNonPawnCount = 0;

  int? whiteKingRow, whiteKingCol, blackKingRow, blackKingCol;

  for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
    final row = rows[rowIdx];
    int count = 0;
    for (int i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == 'K') {
        whiteKingCount++;
        whiteKingRow = rowIdx;
        whiteKingCol = count;
      }
      if (char == 'k') {
        blackKingCount++;
        blackKingRow = rowIdx;
        blackKingCol = count;
      }
      if (char == 'P') whitePawnCount++;
      if (char == 'p') blackPawnCount++;

      if (fenPieceRegex.hasMatch(char)) {
        count += 1;
        if (char != 'K' && char != 'k' && char != 'P' && char != 'p') {
          if (char == char.toUpperCase()) {
            whiteNonPawnCount++;
          } else {
            blackNonPawnCount++;
          }
        }
      } else if (fenDigitRegex.hasMatch(char)) {
        count += int.parse(char);
      } else {
        print('  FAIL: Invalid character "$char" in row $rowIdx');
        return false;
      }
    }
    if (count != 8) {
      print('  FAIL: Row $rowIdx count=$count (expected 8)');
      return false;
    }
  }

  if (whiteKingCount != 1 || blackKingCount != 1) {
    print('  FAIL: King counts W=$whiteKingCount B=$blackKingCount');
    return false;
  }

  // Kings must not be adjacent
  if (whiteKingRow != null && blackKingRow != null &&
      whiteKingCol != null && blackKingCol != null) {
    final rowDiff = (whiteKingRow - blackKingRow).abs();
    final colDiff = (whiteKingCol - blackKingCol).abs();
    if (rowDiff <= 1 && colDiff <= 1) {
      print('  FAIL: Kings adjacent');
      return false;
    }
  }

  // No pawns on rank 1 or 8
  if (rows[0].contains('P') || rows[0].contains('p')) {
    print('  FAIL: Pawns on rank 8');
    return false;
  }
  if (rows[7].contains('P') || rows[7].contains('p')) {
    print('  FAIL: Pawns on rank 1');
    return false;
  }

  if (whitePawnCount > 8 || blackPawnCount > 8) {
    print('  FAIL: Pawn count W=$whitePawnCount B=$blackPawnCount');
    return false;
  }

  if (whiteNonPawnCount > 8 || blackNonPawnCount > 8) {
    print('  FAIL: Non-pawn count W=$whiteNonPawnCount B=$blackNonPawnCount');
    return false;
  }

  final color = parts[1];
  if (color != 'w' && color != 'b') {
    print('  FAIL: Invalid color "$color"');
    return false;
  }

  final castling = parts[2];
  if (castling != '-') {
    final validCastling = RegExp(r'^[KQkq]+$');
    if (!validCastling.hasMatch(castling)) {
      print('  FAIL: Invalid castling "$castling"');
      return false;
    }
    if (castling.length != castling.split('').toSet().length) {
      print('  FAIL: Duplicate castling flags');
      return false;
    }
    print('  Castling="$castling", whiteKingRow=$whiteKingRow, blackKingRow=$blackKingRow');
    if (castling.contains('K') && !rows[7].contains('K')) {
      print('  FAIL: K flag but no king on rank 1');
      return false;
    }
    if ((castling.contains('K') || castling.contains('Q')) && whiteKingRow != 7) {
      print('  FAIL: White castling but king not on row 7');
      return false;
    }
    if ((castling.contains('k') || castling.contains('q')) && blackKingRow != 0) {
      print('  FAIL: Black castling but king not on row 0');
      return false;
    }
  }

  final ep = parts[3];
  if (ep != '-') {
    final validEp = RegExp(r'^[a-h][36]$');
    if (!validEp.hasMatch(ep)) {
      print('  FAIL: Invalid EP "$ep"');
      return false;
    }
  }

  if (parts.length >= 5) {
    final halfmove = int.tryParse(parts[4]);
    if (halfmove == null || halfmove < 0) {
      print('  FAIL: Invalid halfmove "${parts[4]}"');
      return false;
    }
  }
  if (parts.length >= 6) {
    final fullmove = int.tryParse(parts[5]);
    if (fullmove == null || fullmove <= 0) {
      print('  FAIL: Invalid fullmove "${parts[5]}"');
      return false;
    }
  }

  return true;
}

void main() {
  test('FEN with en passant after e4 is valid', () {
    const fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
    final result = isValidFenDebug(fen);
    expect(result, isTrue);
  });
}
