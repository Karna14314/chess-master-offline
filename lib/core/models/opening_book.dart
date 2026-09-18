/// Model definitions for chess openings and playbook entries.
class OpeningEntry {
  final String eco;
  final String name;
  final List<String> movesSan;
  final String category;
  final String description;
  final List<String> keyThemes;
  final String fen;

  /// Final position after the line. Falls back to [fen] for legacy entries.
  final String? finalFen;

  /// One-line study goal for this line. Falls back to [description].
  final String goal;

  /// Per-ply study notes aligned with [movesSan]. Empty for legacy entries.
  final List<String> moveNotes;

  const OpeningEntry({
    required this.eco,
    required this.name,
    required this.movesSan,
    required this.category,
    required this.description,
    required this.keyThemes,
    required this.fen,
    this.finalFen,
    this.goal = '',
    this.moveNotes = const [],
  });

  /// Position to practice from: the end of the line when known.
  String get practiceFen => finalFen ?? fen;

  /// Display goal: per-line study goal, falling back to the description.
  String get displayGoal => goal.isNotEmpty ? goal : description;

  /// Study note for a board position at [ply] (0 = start). Empty when none.
  String noteForPly(int ply) {
    if (ply <= 0) return 'Starting position — follow the main line below.';
    if (ply - 1 < moveNotes.length) return moveNotes[ply - 1];
    return '';
  }

  /// Formatted move sequence string (e.g., "1. e4 e5 2. Nf3 Nc6 3. Bc4")
  String get formattedMoves {
    final buffer = StringBuffer();
    for (int i = 0; i < movesSan.length; i++) {
      if (i % 2 == 0) {
        final moveNum = (i ~/ 2) + 1;
        buffer.write('$moveNum. ');
      }
      buffer.write(movesSan[i]);
      if (i < movesSan.length - 1) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  /// Total ply count of the opening line
  int get plies => movesSan.length;

  /// Quick map representation for serialization/debugging
  Map<String, dynamic> toMap() => {
        'eco': eco,
        'name': name,
        'movesSan': movesSan,
        'category': category,
        'description': description,
        'keyThemes': keyThemes,
        'fen': fen,
        if (finalFen != null) 'finalFen': finalFen,
        if (goal.isNotEmpty) 'goal': goal,
        if (moveNotes.isNotEmpty) 'moveNotes': moveNotes,
      };

  factory OpeningEntry.fromMap(Map<String, dynamic> map) => OpeningEntry(
        eco: map['eco'] as String,
        name: map['name'] as String,
        movesSan: List<String>.from(map['movesSan'] as List),
        category: map['category'] as String,
        description: map['description'] as String,
        keyThemes: List<String>.from(map['keyThemes'] as List),
        fen: map['fen'] as String,
        finalFen: map['finalFen'] as String?,
        goal: map['goal'] as String? ?? '',
        moveNotes: List<String>.from(map['moveNotes'] as List? ?? []),
      );
}
