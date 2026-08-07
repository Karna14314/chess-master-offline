import re

with open('lib/providers/game_session_viewmodel.dart', 'r') as f:
    content = f.read()

# Replace the end of _recordStatisticsIfNeeded to check mounted.
old_stats = '''    state = currentSession.copyWith(
      isRecorded: true,
      whiteAccuracy: isWhite ? accuracy : null,
      blackAccuracy: !isWhite ? accuracy : null,
    );
    await _repository.saveSession(state!);

    final newElo = statsNotifier.state.currentGameElo;
    if (newElo > prevElo && (newElo % 100 == 0 || (newElo > 1500 && newElo - prevElo > 50))) {
      NotificationService.instance.showRatingMilestone(newElo);
    }
  }'''

new_stats = '''    state = currentSession.copyWith(
      isRecorded: true,
      whiteAccuracy: isWhite ? accuracy : null,
      blackAccuracy: !isWhite ? accuracy : null,
    );
    await _repository.saveSession(state!);

    if (mounted) {
      final newElo = statsNotifier.state.currentGameElo;
      if (newElo > prevElo && (newElo % 100 == 0 || (newElo > 1500 && newElo - prevElo > 50))) {
        NotificationService.instance.showRatingMilestone(newElo);
      }
    }
  }'''

content = content.replace(old_stats, new_stats)

with open('lib/providers/game_session_viewmodel.dart', 'w') as f:
    f.write(content)
