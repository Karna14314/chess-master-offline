import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/opening_service.dart';

void main() {
  group('OpeningService Tests', () {
    final service = OpeningService.instance;

    test('Loads comprehensive opening list', () {
      expect(service.allOpenings.length, greaterThanOrEqualTo(30));
    });

    test('Identifies Italian Game correctly', () {
      final moves = ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'];
      final opening = service.identifyOpening(moves);
      expect(opening, isNotNull);
      expect(opening!.eco, equals('C50'));
      expect(opening.name, contains('Italian Game'));
    });

    test('Identifies Sicilian Defense: Najdorf Variation correctly', () {
      final moves = ['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'a6'];
      final opening = service.identifyOpening(moves);
      expect(opening, isNotNull);
      expect(opening!.eco, equals('B90'));
      expect(opening.name, contains('Najdorf'));
    });

    test('Recognizes book moves in opening theory', () {
      expect(service.isBookMove([], 'e4'), isTrue);
      expect(service.isBookMove([], 'd4'), isTrue);
      expect(service.isBookMove([], 'c4'), isTrue);
      expect(service.isBookMove([], 'Nf3'), isTrue);
      expect(service.isBookMove([], 'h4'), isFalse);

      // 1. e4 e5 2. Nf3
      expect(service.isBookMove(['e4', 'e5'], 'Nf3'), isTrue);
      // 1. e4 e5 2. Nf3 Nc6 3. Bc4
      expect(service.isBookMove(['e4', 'e5', 'Nf3', 'Nc6'], 'Bc4'), isTrue);
      // 1. e4 e5 2. Nf3 Nc6 3. Bb5 (Ruy Lopez)
      expect(service.isBookMove(['e4', 'e5', 'Nf3', 'Nc6'], 'Bb5'), isTrue);
    });

    test('Filters openings by category', () {
      final e4Openings = service.getOpeningsByCategory(OpeningService.categoryE4);
      final d4Openings = service.getOpeningsByCategory(OpeningService.categoryD4);
      final flank = service.getOpeningsByCategory(OpeningService.categoryFlank);

      expect(e4Openings.isNotEmpty, isTrue);
      expect(d4Openings.isNotEmpty, isTrue);
      expect(flank.isNotEmpty, isTrue);
    });

    test('Searches openings by query', () {
      final results = service.searchOpenings('Sicilian');
      expect(results.length, greaterThanOrEqualTo(3));
      for (final o in results) {
        expect(o.name.toLowerCase(), contains('sicilian'));
      }
    });

    test('Every line carries a distinct study goal', () {
      final goals = service.allOpenings.map((o) => o.displayGoal).toList();
      expect(goals, everyElement(isNotEmpty));
      // Goals must differentiate lines: near-unique across the playbook.
      expect(goals.toSet().length, greaterThanOrEqualTo(70));
    });

    test('Move notes align with plies and start-position note exists', () {
      for (final o in service.allOpenings) {
        expect(
          o.moveNotes.length,
          equals(o.movesSan.length),
          reason: '${o.name}: moveNotes/plies mismatch',
        );
        expect(o.noteForPly(0), isNotEmpty);
        expect(o.noteForPly(o.movesSan.length), isNotEmpty);
      }
    });

    test('No duplicate theory lines across the playbook', () {
      final seen = <String>{};
      for (final o in service.allOpenings) {
        final key =
            '${o.eco}:${o.movesSan.map((m) => m.toLowerCase()).join(' ')}';
        expect(seen, isNot(contains(key)), reason: 'duplicate: ${o.name}');
        seen.add(key);
      }
    });

    test('Quiz answers are not pinned to one slot', () {
      // OpeningEntry does not parse quizzes; check the bundled JSON
      // directly (same file the service loads).
      final raw =
          File('assets/lessons/openings.json').readAsStringSync();
      final decoded = json.decode(raw) as List;
      final answers = <int>{};
      for (final item in decoded) {
        final quiz = (item as Map)['quiz'];
        if (quiz is Map) answers.add((quiz['answer'] as num).toInt());
      }
      expect(answers.length, greaterThanOrEqualTo(2));
    });

    test('Quiz questions vary within each category', () {
      final raw =
          File('assets/lessons/openings.json').readAsStringSync();
      final decoded = json.decode(raw) as List;
      final byCategory = <String, Set<String>>{};
      for (final item in decoded) {
        final m = item as Map;
        final quiz = m['quiz'];
        if (quiz is Map) {
          byCategory
              .putIfAbsent(m['category'].toString(), () => <String>{})
              .add(quiz['question'].toString());
        }
      }
      for (final entry in byCategory.entries) {
        expect(
          entry.value.length,
          greaterThanOrEqualTo(3),
          reason: 'category ${entry.key} repeats one question',
        );
      }
    });
  });
}
