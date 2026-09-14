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

  const OpeningEntry({
    required this.eco,
    required this.name,
    required this.movesSan,
    required this.category,
    required this.description,
    required this.keyThemes,
    required this.fen,
    this.finalFen,
  });

  /// Position to practice from: the end of the line when known.
  String get practiceFen => finalFen ?? fen;

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
      );
}
