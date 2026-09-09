import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/achievement_provider.dart';

const int kTotalJourneyLevels = 1000;
const List<int> kJourneyMilestones = [10, 25, 50, 100, 250, 500, 750, 1000];

class JourneyState {
  final int currentLevel; // 1 to 1000
  final int solvedCount; // 0 to 1000
  final Set<int> unlockedMilestones;
  final int? newlyUnlockedMilestone;

  const JourneyState({
    this.currentLevel = 1,
    this.solvedCount = 0,
    this.unlockedMilestones = const {},
    this.newlyUnlockedMilestone,
  });

  double get completionPercent =>
      ((solvedCount / kTotalJourneyLevels) * 100).clamp(0.0, 100.0);

  int get remainingCount => (kTotalJourneyLevels - solvedCount).clamp(0, kTotalJourneyLevels);

  JourneyState copyWith({
    int? currentLevel,
    int? solvedCount,
    Set<int>? unlockedMilestones,
    int? newlyUnlockedMilestone,
    bool clearNewMilestone = false,
  }) {
    return JourneyState(
      currentLevel: currentLevel ?? this.currentLevel,
      solvedCount: solvedCount ?? this.solvedCount,
      unlockedMilestones: unlockedMilestones ?? this.unlockedMilestones,
      newlyUnlockedMilestone: clearNewMilestone
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
    final milestonesRaw =
        prefs.getStringList('journey_unlocked_milestones') ?? [];
    final unlockedMilestones = milestonesRaw
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();

    if (!_isDisposed) {
      state = JourneyState(
        currentLevel: currentLevel.clamp(1, kTotalJourneyLevels),
        solvedCount: solvedCount.clamp(0, kTotalJourneyLevels),
        unlockedMilestones: unlockedMilestones,
      );
    }
  }

  /// Complete current journey level and return newly unlocked milestone if any
  Future<int?> completeCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final newSolvedCount = (state.solvedCount + 1).clamp(0, kTotalJourneyLevels);
    final nextLevel = (state.currentLevel + 1).clamp(1, kTotalJourneyLevels);

    int? unlockedMilestone;
    final updatedMilestones = Set<int>.from(state.unlockedMilestones);

    for (final milestone in kJourneyMilestones) {
      if (newSolvedCount >= milestone && !updatedMilestones.contains(milestone)) {
        updatedMilestones.add(milestone);
        unlockedMilestone = milestone;
      }
    }

    await prefs.setInt('journey_solved_count', newSolvedCount);
    await prefs.setInt('journey_current_level', nextLevel);
    await prefs.setStringList(
      'journey_unlocked_milestones',
      updatedMilestones.map((e) => e.toString()).toList(),
    );

    if (_isDisposed) return unlockedMilestone;

    state = state.copyWith(
      currentLevel: nextLevel,
      solvedCount: newSolvedCount,
      unlockedMilestones: updatedMilestones,
      newlyUnlockedMilestone: unlockedMilestone,
    );

    // Sync with achievements if appropriate
    _ref.read(achievementProvider.notifier).checkPuzzlesSolved(newSolvedCount);

    return unlockedMilestone;
  }

  void clearNewlyUnlockedMilestone() {
    if (!_isDisposed) {
      state = state.copyWith(clearNewMilestone: true);
    }
  }

  /// Map level (1 to 1000) to a Puzzle from the sorted 10,000 puzzles pool.
  Puzzle? getPuzzleForLevel(int level, List<Puzzle> allPuzzles) {
    if (allPuzzles.isEmpty) return null;

    final sorted = List<Puzzle>.from(allPuzzles)
      ..sort((a, b) => a.rating.compareTo(b.rating));

    final levelIndex = (level - 1).clamp(0, kTotalJourneyLevels - 1);
    final step = (sorted.length / kTotalJourneyLevels).floor();
    final targetIndex = (levelIndex * (step > 0 ? step : 1)).clamp(0, sorted.length - 1);

    return sorted[targetIndex];
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

final journeyProvider =
    StateNotifierProvider<JourneyNotifier, JourneyState>((ref) {
  return JourneyNotifier(ref);
});
