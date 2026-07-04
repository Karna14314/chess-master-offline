/// Generates opening book JSON files from opening lines.
/// Run: dart tool/generate_openings.dart
library;

import 'dart:convert';
import 'dart:io';
import 'package:chess/chess.dart' as chess;

/// An opening line with a weight.
/// Weight represents how often this move should be chosen (percentage).
class WeightedMove {
  final String uci;
  final int weight;
  WeightedMove(this.uci, this.weight);
}

/// An opening entry: FEN + list of candidate moves with weights.
class OpeningEntry {
  final String fen;
  final List<WeightedMove> moves;
  OpeningEntry(this.fen, this.moves);
}

/// Play through opening lines, recording every position + responses.
class OpeningBookBuilder {
  final Map<String, Map<String, int>> _positions = {};

  /// Add an opening line as a space-separated sequence of UCI moves.
  /// Moves before the `|` are the main line; moves after are alternatives
  /// at the last position.
  /// Weights distribute naturally: last move's alternatives get equal weight.
  void addLine(List<String> uciMoves) {
    final board = chess.Chess();
    for (int i = 0; i < uciMoves.length; i++) {
      final fen = _normalizeFen(board.fen);
      final move = uciMoves[i];

      // Skip invalid moves
      try {
        board.move(move);
      } catch (_) {
        break;
      }

      // Record that from this FEN, this move was played
      _positions.putIfAbsent(fen, () => {});
      _positions[fen]!.update(move, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  /// Add alternative moves at a given position.
  /// First play through the sequence to reach the position, then add alts.
  void addVariation(List<String> mainLine, List<String> alternatives) {
    final board = chess.Chess();
    for (final uci in mainLine) {
      board.move(uci);
    }
    final fen = _normalizeFen(board.fen);

    // Give each alternative weight 1 (they'll be normalized later)
    for (final alt in alternatives) {
      _positions.putIfAbsent(fen, () => {});
      _positions[fen]!.update(alt, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  String _normalizeFen(String fen) {
    final parts = fen.split(' ');
    // Keep: position, turn, castling, en passant (strip move counters)
    return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]}';
  }

  /// Normalize weights so they sum to 100 per position.
  Map<String, List<Map<String, dynamic>>> build() {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in _positions.entries) {
      final total = entry.value.values.fold(0, (a, b) => a + b);
      result[entry.key] =
          entry.value.entries.map((e) {
              return {
                'uci': e.key,
                'weight': (e.value * 100 / total).round().clamp(1, 99),
              };
            }).toList()
            ..sort(
              (a, b) => (b['weight'] as int).compareTo(a['weight'] as int),
            );
    }
    return result;
  }
}

/// Define all opening lines for each personality level.
/// Format: list of UCI move sequences.
Map<String, List<List<String>>> get beginnerBook => {
  '1.e4 responses': [
    ['e2e4', 'e7e5'],
    ['e2e4', 'c7c5'],
    ['e2e4', 'e7e6'],
    ['e2e4', 'c7c6'],
    ['e2e4', 'd7d5'],
  ],
  '1.d4 responses': [
    ['d2d4', 'd7d5'],
    ['d2d4', 'g8f6'],
    ['d2d4', 'e7e6'],
    ['d2d4', 'f7f5'],
  ],
  'Italian Game': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4'],
  ],
  'Spanish': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5'],
  ],
  'Scotch': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'd2d4'],
  ],
  'Two Knights': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'],
  ],
  'Queen\'s Gambit': [
    ['d2d4', 'd7d5', 'c2c4'],
  ],
  'London System': [
    ['d2d4', 'd7d5', 'c1f4'],
    ['d2d4', 'g8f6', 'c1f4'],
  ],
};

Map<String, List<List<String>>> get casualBook => {
  ...beginnerBook,
  'Sicilian Open': [
    ['e2e4', 'c7c5', 'g1f3'],
    ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4'],
    ['e2e4', 'c7c5', 'g1f3', 'b8c6', 'd2d4'],
    ['e2e4', 'c7c5', 'g1f3', 'e7e6', 'd2d4'],
  ],
  'French': [
    ['e2e4', 'e7e6', 'd2d4', 'd7d5'],
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3'],
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'e4e5'],
  ],
  'Caro-Kann': [
    ['e2e4', 'c7c6', 'd2d4', 'd7d5'],
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3'],
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'e4e5'],
  ],
  'King\'s Indian': [
    ['d2d4', 'g8f6', 'c2c4', 'g7g6'],
    ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'f8g7'],
  ],
  'Nimzo-Indian': [
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4'],
  ],
  'Queen\'s Indian': [
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'b7b6'],
  ],
  'English': [
    ['c2c4'],
    ['c2c4', 'e7e5'],
    ['c2c4', 'c7c5'],
  ],
  'Reti': [
    ['g1f3'],
    ['g1f3', 'd7d5'],
    ['g1f3', 'g8f6'],
  ],
};

Map<String, List<List<String>>> get intermediateBook => {
  ...casualBook,
  'Italian Main Lines': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5'],
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'c2c3'],
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'd2d3'],
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8e7'],
  ],
  'Spanish Main Lines': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6'],
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'g8f6'],
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'f8c5'],
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'd7d6'],
  ],
  'Sicilian Najdorf': [
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'a7a6',
    ],
  ],
  'Sicilian Dragon': [
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'g7g6',
    ],
  ],
  'French Winawer': [
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'f8b4'],
  ],
  'Caro-Kann Classical': [
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3', 'd5e4', 'c3e4'],
  ],
  'Queen\'s Gambit Declined': [
    ['d2d4', 'd7d5', 'c2c4', 'e7e6'],
    ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6'],
  ],
  'Slav': [
    ['d2d4', 'd7d5', 'c2c4', 'c7c6'],
  ],
  'Grünfeld': [
    ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'd7d5'],
  ],
};

Map<String, List<List<String>>> get advancedBook => {
  ...intermediateBook,
  'Italian — Giuoco Piano': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'c2c3', 'g8f6', 'd2d3'],
  ],
  'Italian — Evans Gambit': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'b2b4'],
  ],
  'Spanish — Open Defence': [
    [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1b5',
      'a7a6',
      'b5a4',
      'g8f6',
      'e1g1',
      'f6e4',
    ],
  ],
  'Spanish — Closed Defence': [
    [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1b5',
      'a7a6',
      'b5a4',
      'g8f6',
      'e1g1',
      'f8e7',
    ],
  ],
  'Spanish — Berlin': [
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'g8f6'],
  ],
  'Sicilian — Kan': [
    ['e2e4', 'c7c5', 'g1f3', 'e7e6', 'd2d4', 'c5d4', 'f3d4', 'a7a6'],
  ],
  'Sicilian — Taimanov': [
    ['e2e4', 'c7c5', 'g1f3', 'e7e6', 'd2d4', 'c5d4', 'f3d4', 'b8c6'],
  ],
  'French — Classical': [
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3', 'g8f6'],
  ],
  'French — Tarrasch': [
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1d2'],
  ],
  'Caro-Kann — Advance': [
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'e4e5'],
  ],
  'Queen\'s Gambit Accepted': [
    ['d2d4', 'd7d5', 'c2c4', 'd5c4'],
  ],
  'Queen\'s Gambit — Exchange': [
    ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6', 'c4d5', 'e6d5'],
  ],
  'King\'s Indian — Classical': [
    [
      'd2d4',
      'g8f6',
      'c2c4',
      'g7g6',
      'b1c3',
      'f8g7',
      'e2e4',
      'd7d6',
      'g1f3',
      'e8g8',
    ],
  ],
  'English — Symmetrical': [
    ['c2c4', 'c7c5'],
    ['c2c4', 'c7c5', 'g1f3', 'g8f6'],
  ],
  'Dutch': [
    ['d2d4', 'f7f5'],
    ['d2d4', 'f7f5', 'c2c4', 'g8f6'],
    ['d2d4', 'f7f5', 'g1f3', 'g8f6'],
  ],
};

Map<String, List<List<String>>> get masterBook => {
  ...advancedBook,
  'Sicilian — Najdorf Main Line': [
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'a7a6',
      'f1e2',
      'e7e5',
    ],
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'a7a6',
      'c1e3',
      'e7e5',
    ],
  ],
  'Spanish — Marshall Attack': [
    [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1b5',
      'a7a6',
      'b5a4',
      'g8f6',
      'e1g1',
      'f8e7',
      'f1e1',
      'b7b5',
      'a4b3',
      'e8g8',
      'c2c3',
      'd7d5',
    ],
  ],
  'Italian — Modern': [
    [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1c4',
      'f8c5',
      'c2c3',
      'g8f6',
      'd2d4',
      'e5d4',
      'c3d4',
      'c5b4',
    ],
  ],
  'Queen\'s Indian — Main Line': [
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'b7b6', 'a2a3'],
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'b7b6', 'g2g3'],
  ],
  'Catalan': [
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g2g3'],
    ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'g1f3', 'g8f6', 'g2g3'],
  ],
  'Pirc': [
    ['e2e4', 'd7d6', 'd2d4', 'g8f6', 'b1c3', 'g7g6'],
  ],
  'Modern': [
    ['e2e4', 'g7g6', 'd2d4', 'f8g7'],
  ],
  'Alekhine': [
    ['e2e4', 'g8f6'],
    ['e2e4', 'g8f6', 'e4e5', 'f6d5'],
  ],
  'Scandinavian': [
    ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
    ['e2e4', 'd7d5', 'e4d5', 'g8f6'],
  ],
  'Bogo-Indian': [
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'g1f3', 'f8b4'],
  ],
  'Benoni': [
    ['d2d4', 'g8f6', 'c2c4', 'c7c5'],
  ],
};

void main() {
  final personalities = {
    'beginner': beginnerBook,
    'casual': casualBook,
    'intermediate': intermediateBook,
    'advanced': advancedBook,
    'master': masterBook,
  };

  final dir = Directory('assets/openings');
  dir.createSync(recursive: true);

  for (final entry in personalities.entries) {
    final builder = OpeningBookBuilder();
    for (final lines in entry.value.values) {
      for (final line in lines) {
        builder.addLine(line);
      }
    }
    final book = builder.build();
    final json = const JsonEncoder.withIndent('  ').convert(book);
    File('${dir.path}/${entry.key}.json').writeAsStringSync(json);
    print('${entry.key}.json: ${book.length} positions');
  }

  print('\nDone!');
}
