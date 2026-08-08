import 'package:chess/chess.dart' as chess;

/// Static Exchange Evaluation (SEE).
///
/// Answers "if I play this capture/move, and both sides then keep recapturing
/// on the destination square with their least valuable attacker, what is the
/// net material swing for the side that moved?"
///
/// Returns centipawns from the moving side's perspective:
///   > 0  the move wins material
///   == 0 the exchange is even
///   < 0  the move loses material (a sacrifice)
class StaticExchangeEvaluator {
  StaticExchangeEvaluator._();

  /// Centipawn values used for the swap-off. Deliberately simple and
  /// independent of positional terms — SEE is a pure material question.
  static final Map<chess.PieceType, int> pieceValues = {
    chess.PieceType.PAWN: 100,
    chess.PieceType.KNIGHT: 320,
    chess.PieceType.BISHOP: 330,
    chess.PieceType.ROOK: 500,
    chess.PieceType.QUEEN: 900,
    chess.PieceType.KING: 20000,
  };

  static int valueOf(chess.PieceType? type) =>
      type == null ? 0 : (pieceValues[type] ?? 0);

  /// Evaluate the move [from]->[to] on [board] (which must be the position
  /// BEFORE the move). The board is left unmodified.
  ///
  /// [promotion] is a UCI promotion suffix such as 'q' when applicable.
  static int evaluate(
    chess.Chess board,
    String from,
    String to, {
    String? promotion,
  }) {
    final target = board.get(to);
    final mover = board.get(from);
    if (mover == null) return 0;

    // Material immediately won by this move (0 for a quiet move).
    final captured = valueOf(target?.type);

    final moved = board.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });
    if (moved != true) return 0;

    try {
      // Opponent now recaptures on the same square if it is profitable.
      final recapture = _swapOff(board, to);
      return captured - recapture;
    } finally {
      board.undo();
    }
  }

  /// Value the side to move can win by capturing on [square], assuming optimal
  /// recapture from both sides. Never negative: a side declines a losing
  /// exchange rather than entering it.
  static int _swapOff(chess.Chess board, String square) {
    final occupant = board.get(square);
    if (occupant == null) return 0;
    final onSquare = valueOf(occupant.type);

    final capture = _leastValuableCaptureTo(board, square);
    if (capture == null) return 0;

    final moved = board.move({
      'from': capture.from,
      'to': square,
      if (capture.promotion != null) 'promotion': capture.promotion,
    });
    if (moved != true) return 0;

    try {
      final gain = onSquare - _swapOff(board, square);
      // A side is never forced into a losing capture.
      return gain > 0 ? gain : 0;
    } finally {
      board.undo();
    }
  }

  /// The cheapest legal capture onto [square] for the side to move.
  static ({String from, String? promotion})? _leastValuableCaptureTo(
    chess.Chess board,
    String square,
  ) {
    ({String from, String? promotion})? best;
    int bestValue = 1 << 30;

    for (final raw in board.moves({'verbose': true})) {
      final m = raw as Map;
      if (m['to'] != square) continue;
      if (m['captured'] == null) continue;

      final attacker = board.get(m['from'] as String);
      final value = valueOf(attacker?.type);
      if (value < bestValue) {
        bestValue = value;
        best = (
          from: m['from'] as String,
          promotion: m['promotion']?.toString(),
        );
      }
    }

    return best;
  }
}
