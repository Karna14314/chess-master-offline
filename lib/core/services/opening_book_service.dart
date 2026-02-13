import 'dart:math';

/// Service to provide opening book moves
class OpeningBookService {
  static final OpeningBookService _instance = OpeningBookService._();
  static OpeningBookService get instance => _instance;

  OpeningBookService._();

  // Simple hardcoded book for common openings
  // Key: FEN (partial, just board state), Value: List of moves (UCI format)
  final Map<String, List<String>> _book = {
    // Starting position
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1': [
      'e2e4', // e4
      'd2d4', // d4
      'g1f3', // Nf3
      'c2c4', // c4
    ],
    // 1. e4
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1': [
      'e7e5', // e5
      'c7c5', // c5 (Sicilian)
      'e7e6', // e6 (French)
      'c7c6', // c6 (Caro-Kann)
      'd7d6', // d6 (Pirc)
    ],
    // 1. d4
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1': [
      'd7d5', // d5
      'g8f6', // Nf6
      'f7f5', // f5 (Dutch)
    ],
    // 1. Nf3
    'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 0 1': [
      'd7d5', // d5
      'g8f6', // Nf6
      'c7c5', // c5
    ],
    // 1. c4
    'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq - 0 1': [
      'e7e5', // e5
      'c7c5', // c5
      'g8f6', // Nf6
    ],
    // 1. e4 e5
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1': [
      'g1f3', // Nf3 (King's Knight)
      'f1c4', // Bc4 (Bishop's Opening)
      'b1c3', // Nc3 (Vienna)
      'f2f4', // f4 (King's Gambit)
    ],
    // 1. e4 e5 2. Nf3
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 0 1': [
      'b8c6', // Nc6
      'g8f6', // Nf6 (Petrov)
      'd7d6', // d6 (Philidor)
    ],
    // 1. e4 e5 2. Nf3 Nc6
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1': [
      'f1b5', // Bb5 (Ruy Lopez)
      'f1c4', // Bc4 (Italian)
      'd2d4', // d4 (Scotch)
      'b1c3', // Nc3 (Three/Four Knights)
    ],
    // 1. e4 c5 (Sicilian)
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1': [
      'g1f3', // Nf3
      'b1c3', // Nc3 (Closed Sicilian)
      'c2c3', // c3 (Alapin)
    ],
    // 1. d4 d5
    'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 1': [
      'c2c4', // c4 (Queen's Gambit)
      'g1f3', // Nf3
      'c1f4', // Bf4 (London)
    ],
    // 1. d4 Nf6
    'rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 1': [
      'c2c4', // c4
      'g1f3', // Nf3
      'c1g5', // Bg5 (Trompowsky)
    ],
    // 1. d4 Nf6 2. c4
    'rnbqkb1r/pppppppp/5n2/8/2PP4/8/PP2PPPP/RNBQKBNR b KQkq - 0 1': [
      'e7e6', // e6 (Nimzo/Queen's Indian)
      'g7g6', // g6 (King's Indian)
      'c7c5', // c5 (Benoni)
    ],
  };

  /// Get a book move for the given FEN
  /// Returns null if no move is found
  String? getMove(String fen) {
    // Basic normalization: trim move counts if necessary
    // This is a simple implementation; real opening books need robust FEN handling

    // Check exact match first
    if (_book.containsKey(fen)) {
      return _getRandomMove(_book[fen]!);
    }

    return null;
  }

  String? _getRandomMove(List<String> moves) {
    if (moves.isEmpty) return null;
    final random = Random();
    return moves[random.nextInt(moves.length)];
  }
}
