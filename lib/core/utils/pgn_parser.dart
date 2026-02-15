/// PGN (Portable Game Notation) Parser and Generator
/// Handles import/export of chess games in standard PGN format
library;

class PgnParser {
  /// Parse a PGN string and extract game data
  static PgnGame? parse(String pgn) {
    try {
      final headers = <String, String>{};
      final movesBuilder = StringBuffer();

      final lines = pgn.split('\n');
      bool inMoves = false;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          if (headers.isNotEmpty) {
            inMoves = true;
          }
          continue;
        }

        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          // Parse header
          final headerMatch = RegExp(r'\[(\w+)\s+"(.*)"\]').firstMatch(trimmed);
          if (headerMatch != null) {
            headers[headerMatch.group(1)!] = headerMatch.group(2)!;
          }
        } else {
          inMoves = true;
          if (inMoves) {
            movesBuilder.write(' $trimmed');
          }
        }
      }

      // Parse moves
      final movesText = movesBuilder.toString().trim();
      final moves = _parseMoves(movesText);

      return PgnGame(
        event: headers['Event'],
        site: headers['Site'],
        date: headers['Date'],
        round: headers['Round'],
        white: headers['White'],
        black: headers['Black'],
        result: headers['Result'],
        eco: headers['ECO'],
        fen: headers['FEN'],
        moves: moves,
        rawMoves: movesText,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse move text into a list of individual moves
  static List<String> _parseMoves(String movesText) {
    final moves = <String>[];

    // Remove comments (curly braces)
    var cleaned = movesText.replaceAll(RegExp(r'\{[^}]*\}'), '');

    // Remove variations (parentheses)
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');

    // Remove move numbers and result
    cleaned = cleaned.replaceAll(RegExp(r'\d+\.'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'1-0|0-1|1/2-1/2|\*'), '');

    // Split by whitespace and filter valid moves
    final tokens = cleaned.split(RegExp(r'\s+'));
    for (final token in tokens) {
      final trimmed = token.trim();
      if (trimmed.isNotEmpty && _isValidMove(trimmed)) {
        moves.add(trimmed);
      }
    }

    return moves;
  }

  /// Check if a token looks like a valid chess move
  static bool _isValidMove(String token) {
    // Basic move patterns
    if (token.isEmpty) return false;
    if (token == '...') return false;

    // Move should contain chess notation characters
    final validChars = RegExp(
      r'^[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8][=QRBN]?[+#]?$',
    );
    final castling = RegExp(r'^O-O(-O)?[+#]?$');

    return validChars.hasMatch(token) || castling.hasMatch(token);
  }

  /// Generate PGN from game data
  static String generate({
    String? event,
    String? site,
    String? date,
    String? round,
    String? white,
    String? black,
    String? result,
    String? eco,
    String? fen,
    required List<String> moves,
  }) {
    final buffer = StringBuffer();

    // Write headers
    buffer.writeln('[Event "${event ?? "Casual Game"}"]');
    buffer.writeln('[Site "${site ?? "ChessMaster Offline"}"]');
    buffer.writeln('[Date "${date ?? _formatDate(DateTime.now())}"]');
    buffer.writeln('[Round "${round ?? "-"}"]');
    buffer.writeln('[White "${white ?? "Player"}"]');
    buffer.writeln('[Black "${black ?? "Bot"}"]');
    buffer.writeln('[Result "${result ?? "*"}"]');
    if (eco != null) {
      buffer.writeln('[ECO "$eco"]');
    }
    if (fen != null &&
        fen != 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1') {
      buffer.writeln('[FEN "$fen"]');
      buffer.writeln('[SetUp "1"]');
    }
    buffer.writeln();

    // Write moves
    final movesText = _formatMoves(moves);
    buffer.write(movesText);
    if (result != null) {
      buffer.write(' $result');
    }

    return buffer.toString();
  }

  /// Format moves with move numbers
  static String _formatMoves(List<String> moves) {
    final buffer = StringBuffer();
    int moveNumber = 1;

    for (int i = 0; i < moves.length; i++) {
      if (i % 2 == 0) {
        if (i > 0) buffer.write(' ');
        buffer.write('$moveNumber.');
        moveNumber++;
      }
      buffer.write(moves[i]);
      if (i < moves.length - 1 && i % 2 == 0) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  /// Format date for PGN
  static String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// Validate PGN string
  static ValidationResult validate(String pgn) {
    if (pgn.trim().isEmpty) {
      return ValidationResult(isValid: false, error: 'PGN is empty');
    }

    final game = parse(pgn);
    if (game == null) {
      return ValidationResult(isValid: false, error: 'Failed to parse PGN');
    }

    if (game.moves.isEmpty && game.rawMoves.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: 'No valid moves found in PGN',
      );
    }

    return ValidationResult(isValid: true, game: game);
  }
}

/// Represents a parsed PGN game
class PgnGame {
  final String? event;
  final String? site;
  final String? date;
  final String? round;
  final String? white;
  final String? black;
  final String? result;
  final String? eco;
  final String? fen;
  final List<String> moves;
  final String rawMoves;

  const PgnGame({
    this.event,
    this.site,
    this.date,
    this.round,
    this.white,
    this.black,
    this.result,
    this.eco,
    this.fen,
    required this.moves,
    required this.rawMoves,
  });

  /// Check if this is a custom starting position
  bool get hasCustomStart =>
      fen != null &&
      fen != 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// Get a display title for this game
  String get displayTitle {
    if (white != null && black != null) {
      return '$white vs $black';
    }
    if (event != null) {
      return event!;
    }
    return 'Chess Game';
  }
}

/// Result of PGN validation
class ValidationResult {
  final bool isValid;
  final String? error;
  final PgnGame? game;

  const ValidationResult({required this.isValid, this.error, this.game});
}
