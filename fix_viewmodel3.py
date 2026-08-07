import re

with open('lib/providers/game_session_viewmodel.dart', 'r') as f:
    content = f.read()

# Replace the middle of _recordStatisticsIfNeeded to check mounted before reading providers.
old_stats3 = '''    if (currentSession.gameMode == GameMode.bot) {
      await statsNotifier.recordGameElo(
        botElo: currentSession.difficulty.elo,
        isWin: isWin,
        isLoss: isLoss,
        isDraw: isDraw,
      );
    }

    if (isWin) {
      _ref.read(achievementProvider.notifier).checkWins(
        difficultyLevel: currentSession.difficulty.level,
      );
    }

    final prevElo = statsNotifier.state.currentGameElo;'''

new_stats3 = '''    if (currentSession.gameMode == GameMode.bot) {
      await statsNotifier.recordGameElo(
        botElo: currentSession.difficulty.elo,
        isWin: isWin,
        isLoss: isLoss,
        isDraw: isDraw,
      );
    }

    if (!mounted) return;

    if (isWin) {
      _ref.read(achievementProvider.notifier).checkWins(
        difficultyLevel: currentSession.difficulty.level,
      );
    }

    final prevElo = statsNotifier.state.currentGameElo;'''

content = content.replace(old_stats3, new_stats3)

with open('lib/providers/game_session_viewmodel.dart', 'w') as f:
    f.write(content)
