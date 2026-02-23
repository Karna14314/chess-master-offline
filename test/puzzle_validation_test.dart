import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/models/puzzle_model.dart';

void main() {
  group('Puzzle Model Validation', () {
    test('Puzzle.fromJson parses valid JSON correctly', () {
      final json = {
        'id': 123,
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': 'e2e4 e7e5',
        'rating': 1500,
        'themes': 'opening',
        'popularity': 100,
      };

      final puzzle = Puzzle.fromJson(json);

      expect(puzzle.id, 123);
      expect(puzzle.moves, ['e2e4', 'e7e5']);
    });

    test('Puzzle.fromJson handles extra spaces in moves string', () {
      final json = {
        'id': 124,
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': ' e2e4   e7e5  ',
        'rating': 1500,
        'themes': 'opening',
        'popularity': 100,
      };

      final puzzle = Puzzle.fromJson(json);

      // This expectation might fail currently if logic is flawed
      expect(puzzle.moves, ['e2e4', 'e7e5']);
    });

    test('Puzzle.fromJson handles empty moves string gracefully', () {
      final json = {
        'id': 125,
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': '',
        'rating': 1500,
        'themes': 'opening',
        'popularity': 100,
      };

      final puzzle = Puzzle.fromJson(json);
      expect(puzzle.moves, isEmpty);
    });

    test('Puzzle.fromJson handles moves string with only spaces', () {
      final json = {
        'id': 126,
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': '   ',
        'rating': 1500,
        'themes': 'opening',
        'popularity': 100,
      };

      final puzzle = Puzzle.fromJson(json);
      expect(puzzle.moves, isEmpty);
    });
  });
}
