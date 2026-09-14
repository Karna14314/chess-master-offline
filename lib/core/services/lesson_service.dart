import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// A major section in the Lichess curriculum (e.g., Checkmates, Tactics, Endgames).
class LessonSection {
  final String id;
  final String title;
  final String description;
  final String icon;
  final List<LessonCategory> categories;

  LessonSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.categories,
  });

  factory LessonSection.fromMap(Map<String, dynamic> map) {
    return LessonSection(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String? ?? 'book',
      categories: (map['categories'] as List? ?? [])
          .map((c) => LessonCategory.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }
}

/// A specific lesson category (e.g., The Pin, Lucena & Philidor, Anastasia's Mate).
class LessonCategory {
  final String id;
  final String title;
  final String subtitle;
  final String difficulty;
  final String icon;
  final List<String> chapterIds;

  LessonCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.difficulty,
    required this.icon,
    required this.chapterIds,
  });

  factory LessonCategory.fromMap(Map<String, dynamic> map) {
    return LessonCategory(
      id: map['id'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'Intermediate',
      icon: map['icon'] as String? ?? 'star',
      chapterIds: List<String>.from(map['chapterIds'] as List? ?? []),
    );
  }
}

/// An interactive lesson chapter with starting FEN, instruction, solution moves, and explanation.
///
/// v2 lessons add structured teaching fields: [type] (guided_try/walkthrough),
/// [concept] + [takeaway] bookends, per-move [narration], [mistakeText] for
/// wrong moves, and an optional [quiz]. All v2 fields are optional so legacy
/// chapters keep parsing.
class LessonChapter {
  final String id;
  final String categoryId;
  final String title;
  final String fen;
  final String instruction;
  final List<String> solutionMoves;
  final List<String> shapes;
  final List<String> hints;
  final String explanation;
  final String type;
  final String concept;
  final String takeaway;
  final List<String> narration;
  final String mistakeText;
  final String quizQuestion;
  final List<String> quizOptions;
  final int quizAnswer;

  LessonChapter({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.fen,
    required this.instruction,
    required this.solutionMoves,
    required this.shapes,
    required this.hints,
    required this.explanation,
    this.type = 'guided_try',
    this.concept = '',
    this.takeaway = '',
    this.narration = const [],
    this.mistakeText = '',
    this.quizQuestion = '',
    this.quizOptions = const [],
    this.quizAnswer = 0,
  });

  bool get hasConcept => concept.isNotEmpty;
  bool get hasQuiz => quizQuestion.isNotEmpty && quizOptions.length >= 2;

  /// Narration for the current player-move step (player moves are even indices).
  String narrationForMoveStep(int moveStep) {
    if (narration.isEmpty) return '';
    final playerIndex = moveStep ~/ 2;
    if (playerIndex < 0 || playerIndex >= narration.length) return '';
    return narration[playerIndex];
  }

  factory LessonChapter.fromMap(Map<String, dynamic> map) {
    // Openings store name/description instead of title/explanation.
    final title =
        (map['title'] ?? map['name'] ?? '') as String;
    return LessonChapter(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String? ?? '',
      title: title.isEmpty ? (map['id'] as String) : title,
      fen: map['fen'] as String,
      instruction: map['instruction'] as String? ?? '',
      solutionMoves: List<String>.from(map['solutionMoves'] as List? ?? []),
      shapes: List<String>.from(map['shapes'] as List? ?? []),
      hints: List<String>.from(map['hints'] as List? ?? []),
      explanation:
          (map['explanation'] ?? map['description'] ?? '') as String,
      type: map['type'] as String? ?? 'guided_try',
      concept: map['concept'] as String? ?? '',
      takeaway: map['takeaway'] as String? ?? '',
      narration: List<String>.from(map['narration'] as List? ?? []),
      mistakeText: map['mistakeText'] as String? ?? '',
      quizQuestion: (map['quiz'] as Map?)?['question'] as String? ?? '',
      quizOptions: List<String>.from(
        (map['quiz'] as Map?)?['options'] as List? ?? [],
      ),
      quizAnswer: (map['quiz'] as Map?)?['answer'] as int? ?? 0,
    );
  }
}

/// Core service managing multi-category lessons extracted from Lichess.
///
/// **Zero chess data is hardcoded in Dart source code.**
/// Everything loads dynamically from `assets/lessons/curriculum.json` and
/// `assets/lessons/lessons_data.json`.
class LessonService {
  LessonService._();
  static final LessonService instance = LessonService._();

  static const String _prefCompletedPrefix = 'lesson_completed_';

  final List<LessonSection> _sections = [];
  final Map<String, LessonChapter> _chapters = {};
  final Set<String> _completedChapterIds = {};
  bool _isLoaded = false;
  SharedPreferences? _prefs;

  bool get isLoaded => _isLoaded;
  List<LessonSection> get sections {
    _ensureLoadedFromFileSync();
    return List.unmodifiable(_sections);
  }

  int get totalChaptersCount {
    _ensureLoadedFromFileSync();
    return _chapters.length;
  }

  /// Initialize and load lessons from assets and load progress from SharedPreferences
  Future<void> initialize({String? customCurriculum, String? customLessons}) async {
    if (_isLoaded && customCurriculum == null && customLessons == null) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _loadProgressFromPrefs();
    } catch (_) {}

    try {
      final String curriculumStr;
      final String lessonsStr;

      if (customCurriculum != null) {
        curriculumStr = customCurriculum;
      } else {
        curriculumStr = await rootBundle.loadString('assets/lessons/curriculum.json');
      }

      if (customLessons != null) {
        lessonsStr = customLessons;
      } else {
        lessonsStr = await rootBundle.loadString('assets/lessons/lessons_data.json');
      }

      loadFromRawData(curriculumStr, lessonsStr);
    } catch (_) {
      // In standalone tests or non-bundle environments, fallback to File IO
      _ensureLoadedFromFileSync();
    }
  }

  /// Synchronous fallback loader for unit test environments
  void _ensureLoadedFromFileSync() {
    if (_isLoaded) return;
    try {
      final curriculumFile = File('assets/lessons/curriculum.json');
      final lessonsFile = File('assets/lessons/lessons_data.json');
      if (curriculumFile.existsSync() && lessonsFile.existsSync()) {
        loadFromRawData(
          curriculumFile.readAsStringSync(),
          lessonsFile.readAsStringSync(),
        );
      }
    } catch (_) {}
  }

  /// Load and parse curriculum and lesson maps from JSON strings
  void loadFromRawData(String curriculumJson, String lessonsJson) {
    _sections.clear();
    _chapters.clear();

    final Map<String, dynamic> curriculumMap = json.decode(curriculumJson);
    final List<dynamic> rawSections = curriculumMap['sections'] as List? ?? [];
    for (final s in rawSections) {
      _sections.add(LessonSection.fromMap(Map<String, dynamic>.from(s as Map)));
    }

    final Map<String, dynamic> chaptersMap = json.decode(lessonsJson);
    chaptersMap.forEach((key, val) {
      if (val is Map) {
        _chapters[key] = LessonChapter.fromMap(Map<String, dynamic>.from(val));
      }
    });

    _isLoaded = true;
  }

  void _loadProgressFromPrefs() {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys();
    for (final k in keys) {
      if (k.startsWith(_prefCompletedPrefix) && _prefs!.getBool(k) == true) {
        _completedChapterIds.add(k.substring(_prefCompletedPrefix.length));
      }
    }
  }

  /// Check if a chapter is marked completed
  bool isChapterCompleted(String chapterId) {
    return _completedChapterIds.contains(chapterId);
  }

  /// Mark a chapter as solved/completed and persist
  Future<void> markChapterCompleted(String chapterId) async {
    _completedChapterIds.add(chapterId);
    if (_prefs != null) {
      await _prefs!.setBool('$_prefCompletedPrefix$chapterId', true);
    }
  }

  /// Get total completed chapter count across all categories
  int get completedChaptersCount => _completedChapterIds.length;

  /// Find a category by ID
  LessonCategory? getCategory(String categoryId) {
    _ensureLoadedFromFileSync();
    for (final section in _sections) {
      for (final cat in section.categories) {
        if (cat.id == categoryId) return cat;
      }
    }
    return null;
  }

  /// Find a chapter by ID
  LessonChapter? getChapter(String chapterId) {
    _ensureLoadedFromFileSync();
    return _chapters[chapterId];
  }

  /// Get list of chapters for a given category in order
  List<LessonChapter> getChaptersForCategory(String categoryId) {
    _ensureLoadedFromFileSync();
    final cat = getCategory(categoryId);
    if (cat == null) return [];

    final List<LessonChapter> result = [];
    for (final chId in cat.chapterIds) {
      final ch = _chapters[chId];
      if (ch != null) {
        result.add(ch);
      }
    }
    return result;
  }

  /// Get completed chapters count for a specific category
  int getCompletedCount(String categoryId) {
    final chapters = getChaptersForCategory(categoryId);
    return chapters.where((c) => _completedChapterIds.contains(c.id)).length;
  }

  /// Get completion fraction (0.0 to 1.0) for a category
  double getCategoryProgress(String categoryId) {
    final chapters = getChaptersForCategory(categoryId);
    if (chapters.isEmpty) return 0.0;
    return getCompletedCount(categoryId) / chapters.length;
  }
}
