void main() {
  final fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  final parts = fen.split(' ');
  final ranks = parts[0].split('/');

  // Warmup
  for (int i = 0; i < 1000; i++) {
    _oldParse(ranks);
    _newParse(ranks);
    _codeUnitParse(ranks);
  }

  final stopwatch1 = Stopwatch()..start();
  for (int i = 0; i < 100000; i++) {
    _oldParse(ranks);
  }
  stopwatch1.stop();

  final stopwatch2 = Stopwatch()..start();
  for (int i = 0; i < 100000; i++) {
    _newParse(ranks);
  }
  stopwatch2.stop();

  final stopwatch3 = Stopwatch()..start();
  for (int i = 0; i < 100000; i++) {
    _codeUnitParse(ranks);
  }
  stopwatch3.stop();

  print('Old parse: ${stopwatch1.elapsedMilliseconds} ms');
  print('New parse: ${stopwatch2.elapsedMilliseconds} ms');
  print('Code Unit parse: ${stopwatch3.elapsedMilliseconds} ms');
}

void _oldParse(List<String> ranks) {
  final newBoard = List.generate(8, (_) => List<String?>.filled(8, null));
  for (int rank = 0; rank < 8; rank++) {
    int file = 0;
    for (final char in ranks[rank].split('')) {
      final num = int.tryParse(char);
      if (num != null) {
        file += num;
      } else {
        if (file < 8) {
          newBoard[rank][file] = char;
          file++;
        }
      }
    }
  }
}

void _newParse(List<String> ranks) {
  final newBoard = List.generate(8, (_) => List<String?>.filled(8, null));
  for (int rank = 0; rank < 8; rank++) {
    int file = 0;
    final rankStr = ranks[rank];
    for (int i = 0; i < rankStr.length; i++) {
      final char = rankStr[i];
      final num = int.tryParse(char);
      if (num != null) {
        file += num;
      } else {
        if (file < 8) {
          newBoard[rank][file] = char;
          file++;
        }
      }
    }
  }
}

void _codeUnitParse(List<String> ranks) {
  final newBoard = List.generate(8, (_) => List<String?>.filled(8, null));
  for (int rank = 0; rank < 8; rank++) {
    int file = 0;
    final rankStr = ranks[rank];
    for (int i = 0; i < rankStr.length; i++) {
      final codeUnit = rankStr.codeUnitAt(i);
      // '0' is 48, '9' is 57
      if (codeUnit >= 48 && codeUnit <= 57) {
        file += (codeUnit - 48);
      } else {
        if (file < 8) {
          newBoard[rank][file] = rankStr[i];
          file++;
        }
      }
    }
  }
}
