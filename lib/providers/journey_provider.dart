import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/models/puzzle_model.dart';

const int kTotalJourneyLevels = 1000;
const List<int> kJourneyMilestones = [10, 25, 50, 100, 250, 500, 750, 1000];

class JourneyState {
  final int currentLevel; // 1 to 1000
  final int solvedCount; // 0 to 1000
  final Set<int> solvedLevels; // separate per-level indices, counted separately
  final Set<int> unlockedMilestones;
  final int? newlyUnlockedMilestone;

  const JourneyState({
    this.currentLevel = 1,
    this.solvedCount = 0,
    this.solvedLevels = const {},
    this.unlockedMilestones = const {},
    this.newlyUnlockedMilestone,
  });

  double get completionPercent =>
      ((solvedLevels.isEmpty ? solvedCount : solvedLevels.length) /
              kTotalJourneyLevels *
              100)
          .clamp(0.0, 100.0);

  int get remainingCount => (kTotalJourneyLevels -
          (solvedLevels.isEmpty ? solvedCount : solvedLevels.length))
      .clamp(0, kTotalJourneyLevels);

  bool isLevelSolved(int level) => solvedLevels.contains(level);

  bool get isCurrentLevelSolved => solvedLevels.contains(currentLevel);

  JourneyState copyWith({
    int? currentLevel,
    int? solvedCount,
    Set<int>? solvedLevels,
    Set<int>? unlockedMilestones,
    int? newlyUnlockedMilestone,
    bool clearNewMilestone = false,
  }) {
    return JourneyState(
      currentLevel: currentLevel ?? this.currentLevel,
      solvedCount: solvedCount ?? this.solvedCount,
      solvedLevels: solvedLevels ?? this.solvedLevels,
      unlockedMilestones: unlockedMilestones ?? this.unlockedMilestones,
      newlyUnlockedMilestone:
          clearNewMilestone
              ? null
              : (newlyUnlockedMilestone ?? this.newlyUnlockedMilestone),
    );
  }
}

class JourneyNotifier extends StateNotifier<JourneyState> {
  final Ref _ref;
  bool _isDisposed = false;

  JourneyNotifier(this._ref) : super(const JourneyState()) {
    loadJourneyState();
  }

  Future<void> loadJourneyState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;

    final currentLevel = prefs.getInt('journey_current_level') ?? 1;
    final solvedCount = prefs.getInt('journey_solved_count') ?? 0;
    final solvedRaw = prefs.getStringList('journey_solved_levels') ?? [];
    final solvedLevels =
        solvedRaw.map((e) => int.tryParse(e)).whereType<int>().toSet();
    // Backfill separate index from legacy counter so old progress is not lost.
    if (solvedLevels.isEmpty && solvedCount > 0) {
      for (var i = 1; i <= solvedCount.clamp(0, kTotalJourneyLevels); i++) {
        solvedLevels.add(i);
      }
    }
    final milestonesRaw =
        prefs.getStringList('journey_unlocked_milestones') ?? [];
    final unlockedMilestones =
        milestonesRaw.map((e) => int.tryParse(e)).whereType<int>().toSet();

    if (!_isDisposed) {
      final effectiveSolved =
          solvedLevels.isEmpty ? solvedCount : solvedLevels.length;
      state = JourneyState(
        currentLevel: currentLevel.clamp(1, kTotalJourneyLevels),
        solvedCount: effectiveSolved.clamp(0, kTotalJourneyLevels),
        solvedLevels: solvedLevels,
        unlockedMilestones: unlockedMilestones,
      );
    }
  }

  /// Complete current journey level and return newly unlocked milestone if any.
  /// Levels are stored separately in `journey_solved_levels` so the 1000
  /// journey puzzles are counted independently from generic puzzle history.
  Future<int?> completeCurrentLevel({int? level, int? puzzleId}) async {
    final prefs = await SharedPreferences.getInstance();

    // Read directly from prefs to prevent race conditions if state is out of sync
    final storedLevels =
        (prefs.getStringList('journey_solved_levels') ?? [])
            .map((e) => int.tryParse(e))
            .whereType<int>()
            .toSet();
    // Merge in-memory + stored so concurrent completions do not lose a level.
    final merged = <int>{...storedLevels, ...state.solvedLevels};
    final solvedLevel =
        (level ?? prefs.getInt('journey_current_level') ?? state.currentLevel)
            .clamp(1, kTotalJourneyLevels);

    final isNewSolve = !merged.contains(solvedLevel);
    merged.add(solvedLevel);

    final newSolvedCount = merged.length.clamp(0, kTotalJourneyLevels);
    // Advance past the highest solved level so progress never gets stuck
    // on a replayed level.
    final maxSolved = merged.isEmpty
        ? 0
        : merged.reduce((a, b) => a > b ? a : b);
    final storedCurrent =
        prefs.getInt('journey_current_level') ?? state.currentLevel;
    var nextLevel = (storedCurrent + 1).clamp(1, kTotalJourneyLevels);
    if (maxSolved + 1 <= kTotalJourneyLevels && maxSolved + 1 > nextLevel) {
      nextLevel = maxSolved + 1;
    }
    if (!isNewSolve) {
      // Re-solved an old level: keep progress, just ensure pointer is ahead.
      nextLevel = (maxSolved + 1).clamp(1, kTotalJourneyLevels);
    }

    int? unlockedMilestone;
    final updatedMilestones = Set<int>.from(state.unlockedMilestones);

    for (final milestone in kJourneyMilestones) {
      if (newSolvedCount >= milestone &&
          !updatedMilestones.contains(milestone)) {
        updatedMilestones.add(milestone);
        unlockedMilestone = milestone;
      }
    }

    await prefs.setInt('journey_solved_count', newSolvedCount);
    await prefs.setInt('journey_current_level', nextLevel);
    await prefs.setStringList(
      'journey_solved_levels',
      merged.map((e) => e.toString()).toList(),
    );
    if (puzzleId != null) {
      final doneIds = (prefs.getStringList('journey_completed_puzzle_ids') ?? [])
          .toSet()
        ..add(puzzleId.toString());
      await prefs.setStringList(
        'journey_completed_puzzle_ids',
        doneIds.toList(),
      );
    }
    await prefs.setStringList(
      'journey_unlocked_milestones',
      updatedMilestones.map((e) => e.toString()).toList(),
    );

    if (_isDisposed) return unlockedMilestone;

    state = state.copyWith(
      currentLevel: nextLevel,
      solvedCount: newSolvedCount,
      solvedLevels: merged,
      unlockedMilestones: updatedMilestones,
      newlyUnlockedMilestone: unlockedMilestone,
    );

    // Achievement unlocks are handled centrally in puzzle_provider's
    // _onPuzzleCompleted, which sees totals + streak + peak together.
    return unlockedMilestone;
  }

  void clearNewlyUnlockedMilestone() {
    if (!_isDisposed) {
      state = state.copyWith(clearNewMilestone: true);
    }
  }

  /// Debug/testing: wipe journey progress back to level 1.
  Future<void> resetJourney() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('journey_current_level');
    await prefs.remove('journey_solved_count');
    await prefs.remove('journey_solved_levels');
    await prefs.remove('journey_unlocked_milestones');
    await prefs.remove('journey_completed_puzzle_ids');
    if (!_isDisposed) {
      state = const JourneyState();
    }
  }

  /// Map level (1 to 1000) to a Puzzle from the sorted puzzles pool.
  /// Uses modulo stride so every consecutive level maps to a DISTINCT puzzle
  /// even when the pool is smaller than 1000 (proportional ~/ indexing
  /// collided, e.g. levels 1..10 all mapped to index 0 with a 100-pool,
  /// making the journey look stuck on the 1st puzzle).
  Puzzle? getPuzzleForLevel(int level, List<Puzzle> allPuzzles) {
    if (allPuzzles.isEmpty) return null;

    final sorted = List<Puzzle>.from(allPuzzles)
      ..sort((a, b) => a.rating.compareTo(b.rating));

    final levelIndex = (level - 1).clamp(0, kTotalJourneyLevels - 1);
    final targetIndex = levelIndex % sorted.length;

    return sorted[targetIndex];
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

final journeyProvider = StateNotifierProvider<JourneyNotifier, JourneyState>((
  ref,
) {
  return JourneyNotifier(ref);
});
