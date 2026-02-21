/// Puzzle model for tactical puzzles
class Puzzle {
  final int id;
  final String fen;
  final List<String> moves; // Solution moves in UCI format
  final int rating;
  final List<String> themes;
  final int popularity;

  const Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
    this.popularity = 0,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as int,
      fen: json['fen'] as String,
      moves: (json['moves'] as String).split(' '),
      rating: json['rating'] as int,
      themes:
          (json['themes'] as String? ?? '')
              .split(',')
              .where((t) => t.isNotEmpty)
              .toList(),
      popularity: json['popularity'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fen': fen,
      'moves': moves.join(' '),
      'rating': rating,
      'themes': themes.join(','),
      'popularity': popularity,
    };
  }

  /// Get the initial move (opponent's move that sets up the puzzle)
  /// NOTE: This is for CONTEXT only - the FEN already represents the puzzle position
  String? get contextMove => moves.isNotEmpty ? moves.first : null;

  /// Get the solution moves (all moves in the puzzle)
  List<String> get solutionMoves => moves;

  /// Check if a move at given index is correct
  bool isCorrectMove(int moveIndex, String move) {
    if (moveIndex >= moves.length) return false;
    return moves[moveIndex].toLowerCase() == move.toLowerCase();
  }

  /// Get the expected move at given index
  String? getExpectedMove(int moveIndex) {
    if (moveIndex >= moves.length) return null;
    return moves[moveIndex];
  }

  /// Total number of moves player needs to make
  int get solutionLength =>
      (moves.length + 1) ~/ 2; // Player moves only (every other move)
}

/// Puzzle progress tracking
class PuzzleProgress {
  final int puzzleId;
  final int attempts;
  final bool solved;
  final DateTime? lastAttempted;

  const PuzzleProgress({
    required this.puzzleId,
    this.attempts = 0,
    this.solved = false,
    this.lastAttempted,
  });

  factory PuzzleProgress.fromJson(Map<String, dynamic> json) {
    return PuzzleProgress(
      puzzleId: json['puzzle_id'] as int,
      attempts: json['attempts'] as int? ?? 0,
      solved: (json['solved'] as int? ?? 0) == 1,
      lastAttempted:
          json['last_attempted'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                json['last_attempted'] as int,
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'puzzle_id': puzzleId,
      'attempts': attempts,
      'solved': solved ? 1 : 0,
      'last_attempted': lastAttempted?.millisecondsSinceEpoch,
    };
  }

  PuzzleProgress copyWith({
    int? attempts,
    bool? solved,
    DateTime? lastAttempted,
  }) {
    return PuzzleProgress(
      puzzleId: puzzleId,
      attempts: attempts ?? this.attempts,
      solved: solved ?? this.solved,
      lastAttempted: lastAttempted ?? this.lastAttempted,
    );
  }
}

/// Puzzle categories/themes
enum PuzzleTheme {
  mate('Checkmate', 'mateIn'),
  tactics('Tactics', 'tactics'),
  fork('Fork', 'fork'),
  pin('Pin', 'pin'),
  skewer('Skewer', 'skewer'),
  discoveredAttack('Discovered Attack', 'discoveredAttack'),
  doubleCheck('Double Check', 'doubleCheck'),
  sacrifice('Sacrifice', 'sacrifice'),
  endgame('Endgame', 'endgame'),
  opening('Opening', 'opening'),
  middlegame('Middlegame', 'middlegame'),
  crushing('Crushing', 'crushing'),
  advantage('Advantage', 'advantage'),
  equality('Equality', 'equality'),
  deflection('Deflection', 'deflection'),
  decoy('Decoy', 'decoy'),
  clearance('Clearance', 'clearance'),
  interference('Interference', 'interference'),
  intermezzo('Intermezzo', 'intermezzo'),
  quietMove('Quiet Move', 'quietMove'),
  xRay('X-Ray', 'xRayAttack'),
  zugzwang('Zugzwang', 'zugzwang'),
  trappedPiece('Trapped Piece', 'trappedPiece'),
  exposedKing('Exposed King', 'exposedKing'),
  hangingPiece('Hanging Piece', 'hangingPiece'),
  backRankMate('Back Rank Mate', 'backRankMate'),
  smotheredMate('Smothered Mate', 'smotheredMate'),
  castling('Castling', 'castling'),
  enPassant('En Passant', 'enPassant'),
  promotion('Promotion', 'promotion'),
  underPromotion('Under Promotion', 'underPromotion'),
  kingsideAttack('Kingside Attack', 'kingsideAttack'),
  queensideAttack('Queenside Attack', 'queensideAttack');

  final String displayName;
  final String tag;

  const PuzzleTheme(this.displayName, this.tag);

  static PuzzleTheme? fromTag(String tag) {
    for (final theme in values) {
      if (theme.tag.toLowerCase() == tag.toLowerCase()) {
        return theme;
      }
    }
    return null;
  }
}

/// Puzzle session state
enum PuzzleState { loading, ready, playing, correct, incorrect, completed }
