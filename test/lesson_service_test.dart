import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/lesson_service.dart';

void main() {
  group('LessonService Tests (Structured v2 Curriculum)', () {
    final service = LessonService.instance;

    test('Loads 6 sections and 40+ categories', () {
      final sections = service.sections;
      expect(sections.isNotEmpty, isTrue);
      expect(sections.length, equals(6));

      int totalCategories = 0;
      for (final s in sections) {
        totalCategories += s.categories.length;
      }
      expect(totalCategories, greaterThanOrEqualTo(40));
    });

    test('Contains all six learning sections', () {
      final sectionIds = service.sections.map((s) => s.id).toList();
      expect(sectionIds, contains('checkmates'));
      expect(sectionIds, contains('fundamental_tactics'));
      expect(sectionIds, contains('advanced_tactics'));
      expect(sectionIds, contains('endgames'));
      expect(sectionIds, contains('middlegame_strategy'));
      expect(sectionIds, contains('openings'));
    });

    test('Ships 500+ structured chapters', () {
      expect(service.totalChaptersCount, greaterThanOrEqualTo(500));
    });

    test('Every category links non-empty chapters', () {
      for (final s in service.sections) {
        for (final c in s.categories) {
          expect(
            c.chapterIds,
            isNotEmpty,
            reason: 'category ${c.id} has no chapters',
          );
        }
      }
    });

    test('Resolves fork category and v2 chapter fields', () {
      final forkCategory = service.getCategory('tactic_fork');
      expect(forkCategory, isNotNull);
      expect(forkCategory!.title, equals('The Fork'));
      expect(forkCategory.chapterIds.length, equals(30));

      final first = service.getChapter(forkCategory.chapterIds.first);
      expect(first, isNotNull);
      expect(first!.fen.isNotEmpty, isTrue);
      expect(first.solutionMoves.isNotEmpty, isTrue);
      expect(first.instruction.isNotEmpty, isTrue);
      expect(first.explanation.isNotEmpty, isTrue);
      // v2 teaching fields
      expect(first.concept.isNotEmpty, isTrue);
      expect(first.takeaway.isNotEmpty, isTrue);
      expect(first.mistakeText.isNotEmpty, isTrue);
      expect(first.narration.isNotEmpty, isTrue);
      expect(first.hasQuiz, isTrue);
    });

    test('Resolves rook endgames category', () {
      final rookCategory = service.getCategory('end_rook_endings');
      expect(rookCategory, isNotNull);
      expect(rookCategory!.title, contains('Rook Endgames'));

      final chapters = service.getChaptersForCategory('end_rook_endings');
      expect(chapters.length, equals(20));
    });

    test('Opening lessons carry plans, not stubs', () {
      final italian = service.getChapter('op_1');
      expect(italian, isNotNull);
      expect(italian!.type, equals('walkthrough'));
      expect(italian.concept.contains('White plan'), isTrue);
      expect(italian.solutionMoves.isNotEmpty, isTrue);
    });

    test('Handles chapter completion tracking', () async {
      const chapterId = 'fork_1';
      // Reset-tolerant: completion persists across runs via prefs.
      await service.markChapterCompleted(chapterId);
      expect(service.isChapterCompleted(chapterId), isTrue);

      final catProgress = service.getCategoryProgress('tactic_fork');
      expect(catProgress, greaterThan(0.0));
      expect(catProgress, lessThanOrEqualTo(1.0));
    });
  });
}
