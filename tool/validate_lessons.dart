/// Validates generated v2 lessons + openings. Fails loudly on any problem.
///
/// Run: dart tool/validate_lessons.dart
/// Checks:
///  1. Every chapter FEN parses.
///  2. Every solution move is legal from its position (full replay).
///  3. Quiz answer index in range; options non-empty.
///  4. No banned strings (Lichess brand, URLs, template leftovers).
///  5. No duplicate positions across chapters.
///  6. Every curriculum chapterId resolves; every category non-empty.
///  7. Opening SAN lists match replay; finalFen matches.
///  8. No duplicate theory lines across openings; moveNotes align with plies.
///  9. No category asks the same quiz question (or same answer slot) always.
library;

import 'dart:convert';
import 'dart:io';
import 'package:chess/chess.dart' as chess;

const kBanned = ['lichess', 'http://', 'https://', 'Lichess'];

String _normFen(String fen) {
  final parts = fen.split(' ');
  if (parts.length < 4) return fen;
  return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]}';
}

bool _replay(String fen, List<String> moves, List<String> errors, String id) {
  chess.Chess board;
  try {
    board = chess.Chess.fromFEN(fen);
  } catch (e) {
    errors.add('$id: bad FEN $fen');
    return false;
  }
  for (final raw in moves) {
    final u = raw.trim().toLowerCase();
    if (u.length < 4) {
      errors.add('$id: malformed move $raw');
      return false;
    }
    final from = u.substring(0, 2);
    final to = u.substring(2, 4);
    final promo = u.length >= 5 ? u.substring(4, 5) : null;
    try {
      final legal = board.moves({'verbose': true});
      var found = false;
      for (final m in legal) {
        final mm = Map<String, dynamic>.from(m as Map);
        if (mm['from'] == from && mm['to'] == to) {
          final mp = (mm['promotion'] ?? '').toString();
          if (promo != null && mp.isNotEmpty && mp[0] != promo) continue;
          found = true;
          break;
        }
      }
      if (!found) {
        errors.add('$id: illegal move $u');
        return false;
      }
      if (promo != null) {
        board.move({'from': from, 'to': to, 'promotion': promo});
      } else {
        board.move({'from': from, 'to': to});
      }
    } catch (e) {
      errors.add('$id: exception on $u: $e');
      return false;
    }
  }
  return true;
}

void main() {
  final errors = <String>[];
  var checked = 0;

  final chapters =
      json.decode(File('assets/lessons/lessons_data.json').readAsStringSync())
          as Map<String, dynamic>;
  final curriculum =
      json.decode(File('assets/lessons/curriculum.json').readAsStringSync())
          as Map<String, dynamic>;
  final openings =
      json.decode(File('assets/lessons/openings.json').readAsStringSync())
          as List;

  final seenFens = <String, String>{};

  chapters.forEach((id, raw) {
    checked++;
    final ch = Map<String, dynamic>.from(raw as Map);
    final fen = (ch['fen'] ?? '') as String;
    if (fen.isEmpty) errors.add('$id: missing fen');

    final isWalkthrough = (ch['type'] ?? '') == 'walkthrough';
    final key = _normFen(fen);
    // Walkthroughs (openings) legitimately share the starting position.
    if (!isWalkthrough) {
      if (seenFens.containsKey(key)) {
        errors.add('$id: duplicate position of ${seenFens[key]}');
      } else {
        seenFens[key] = id;
      }
    }

    final solutions = (ch['solutionMoves'] as List? ?? []).cast<String>();
    if (solutions.isEmpty) {
      errors.add('$id: empty solutionMoves');
    } else {
      _replay(fen, solutions, errors, id);
      final isWalkthrough = (ch['type'] ?? '') == 'walkthrough';
      if (!isWalkthrough && solutions.length % 2 == 0) {
        errors.add('$id: solution ends with opponent reply (user never plays the payoff)');
      }
      final cat = (ch['categoryId'] ?? '') as String;
      if (!isWalkthrough && cat.startsWith('mate_')) {
        try {
          final board = chess.Chess.fromFEN(fen);
          for (final raw in solutions) {
            final u = raw.trim().toLowerCase();
            if (u.length >= 5) {
              board.move({
                'from': u.substring(0, 2),
                'to': u.substring(2, 4),
                'promotion': u.substring(4, 5),
              });
            } else {
              board.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
            }
          }
          if (!board.in_checkmate) {
            errors.add('$id: mate lesson does not end in checkmate');
          }
        } catch (e) {
          errors.add('$id: mate replay failed: $e');
        }
      }
    }

    final titleText = ((ch['title'] ?? ch['name'] ?? '') as String);
    final explText = ((ch['explanation'] ?? ch['description'] ?? '') as String);
    if (titleText.isEmpty) errors.add('$id: empty title');
    if (explText.isEmpty) errors.add('$id: empty explanation');
    for (final banned in kBanned) {
      if (titleText.toLowerCase().contains(banned)) {
        errors.add('$id: banned string "$banned" in title');
      }
      if (explText.toLowerCase().contains(banned)) {
        errors.add('$id: banned string "$banned" in explanation');
      }
    }
    for (final field in ['concept', 'takeaway', 'instruction']) {
      final text = (ch[field] ?? '') as String;
      if (text.isEmpty) {
        errors.add('$id: empty $field');
        continue;
      }
      for (final banned in kBanned) {
        if (text.toLowerCase().contains(banned)) {
          errors.add('$id: banned string "$banned" in $field');
        }
      }
    }
    for (final n in (ch['narration'] as List? ?? [])) {
      for (final banned in kBanned) {
        if ((n as String).toLowerCase().contains(banned)) {
          errors.add('$id: banned string "$banned" in narration');
        }
      }
    }

    final quiz = ch['quiz'];
    if (quiz is Map) {
      final options = (quiz['options'] as List? ?? []).cast<String>();
      final answer = quiz['answer'] as int? ?? -1;
      if (options.length < 2) errors.add('$id: quiz needs 2+ options');
      if (answer < 0 || answer >= options.length) {
        errors.add('$id: quiz answer out of range');
      }
    }
  });

  // Openings cross-checks.
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  final seenLines = <String, String>{};
  for (final raw in openings) {
    final o = Map<String, dynamic>.from(raw as Map);
    final id = o['id'] as String? ?? '?opening';
    final uci = (o['solutionMoves'] as List? ?? []).cast<String>();
    final sans = (o['movesSan'] as List? ?? []).cast<String>();
    final lineKey = uci.map((u) => u.trim().toLowerCase()).join(' ');
    if (seenLines.containsKey(lineKey)) {
      errors.add('$id: duplicate theory line of ${seenLines[lineKey]}');
    } else {
      seenLines[lineKey] = id;
    }
    if (((o['goal'] ?? '') as String).isEmpty) {
      errors.add('$id: empty goal');
    }
    final notes = (o['moveNotes'] as List? ?? []);
    if (notes.length != sans.length) {
      errors.add(
        '$id: moveNotes (${notes.length}) do not align with plies (${sans.length})',
      );
    }
    if (uci.length != sans.length) {
      errors.add('$id: solutionMoves/SAN length mismatch');
    }
    final board = chess.Chess.fromFEN(startFen);
    var ok = true;
    final replayedSans = <String>[];
    for (final u in uci) {
      try {
        final legal = board.moves({'verbose': true});
        String? san;
        for (final m in legal) {
          final mm = Map<String, dynamic>.from(m as Map);
          if (mm['from'] == u.substring(0, 2) && mm['to'] == u.substring(2, 4)) {
            san = mm['san'] as String?;
            break;
          }
        }
        if (san == null) {
          ok = false;
          break;
        }
        replayedSans.add(san);
        board.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
      } catch (_) {
        ok = false;
        break;
      }
    }
    if (!ok) {
      errors.add('$id: opening line does not replay');
      continue;
    }
    for (var i = 0; i < sans.length && i < replayedSans.length; i++) {
      if (sans[i] != replayedSans[i]) {
        errors.add('$id: SAN mismatch at ply $i (${sans[i]} vs ${replayedSans[i]})');
      }
    }
    if ((o['finalFen'] as String? ?? '') != board.fen) {
      errors.add('$id: finalFen mismatch');
    }
    final desc = (o['description'] ?? '') as String;
    for (final banned in kBanned) {
      if (desc.toLowerCase().contains(banned)) {
        errors.add('$id: banned string in description');
      }
    }
  }

  // Curriculum linkage.
  final sections = (curriculum['sections'] as List? ?? []);
  if (sections.isEmpty) errors.add('curriculum: no sections');
  for (final raw in sections) {
    final s = Map<String, dynamic>.from(raw as Map);
    final cats = (s['categories'] as List? ?? []);
    if (cats.isEmpty) errors.add('section ${s['id']}: no categories');
    for (final rc in cats) {
      final c = Map<String, dynamic>.from(rc as Map);
      final ids = (c['chapterIds'] as List? ?? []).cast<String>();
      if (ids.isEmpty) errors.add('category ${c['id']}: empty chapterIds');
      for (final cid in ids) {
        if (!chapters.containsKey(cid)) {
          errors.add('category ${c['id']}: dangling chapterId $cid');
        }
      }
    }
  }

  // Category variety: no category may ask one quiz question (or pin the
  // answer to one slot) across all its chapters.
  final quizByCategory = <String, List<Map<String, dynamic>>>{};
  chapters.forEach((id, raw) {
    final ch = Map<String, dynamic>.from(raw as Map);
    final cat = (ch['categoryId'] ?? '') as String;
    final quiz = ch['quiz'];
    if (quiz is Map) {
      quizByCategory.putIfAbsent(cat, () => []).add({
        'id': id,
        'question': (quiz['question'] ?? '').toString(),
        'answer': quiz['answer'] as int? ?? -1,
      });
    }
  });
  // Opening categories are keyed by name in openings.json; map them onto
  // the same check via their category field.
  for (final raw in openings) {
    final o = Map<String, dynamic>.from(raw as Map);
    final quiz = o['quiz'];
    if (quiz is Map) {
      quizByCategory.putIfAbsent('opening:${o['category']}', () => []).add({
        'id': o['id'],
        'question': (quiz['question'] ?? '').toString(),
        'answer': quiz['answer'] as int? ?? -1,
      });
    }
  }
  quizByCategory.forEach((cat, list) {
    if (list.length < 2) return;
    final distinctQuestions = list.map((e) => e['question']).toSet();
    final wantDistinct = list.length >= 3 ? 3 : list.length;
    if (distinctQuestions.length < wantDistinct) {
      errors.add(
        'category $cat: only ${distinctQuestions.length} distinct quiz '
        'question(s) across ${list.length} chapters',
      );
    }
    final distinctAnswers = list.map((e) => e['answer']).toSet();
    if (distinctAnswers.length < 2) {
      errors.add(
        'category $cat: quiz answer pinned to one slot across '
        '${list.length} chapters',
      );
    }
  });

  print('=== LESSON VALIDATION ===');
  print('Chapters checked: $checked');
  print('Openings checked: ${openings.length}');
  if (errors.isEmpty) {
    print('PASS: all checks green.');
  } else {
    print('FAIL: ${errors.length} problems:');
    for (final e in errors.take(50)) {
      print('  - $e');
    }
    exit(1);
  }
}
