import re

with open('lib/providers/game_session_viewmodel.dart', 'r') as f:
    content = f.read()

# Replace the beginning of _recordStatisticsIfNeeded to check mounted.
old_stats2 = '''  Future<void> _recordStatisticsIfNeeded(GameSession currentSession) async {
    if (currentSession.isRecorded ||
        currentSession.status == GameStatus.active) {
      return;
    }

    final isWin = currentSession.result == GameResult.whiteWins &&
            currentSession.playerColor == chess.Color.WHITE ||
        currentSession.result == GameResult.blackWins &&
            currentSession.playerColor == chess.Color.BLACK;

    final isLoss = currentSession.result == GameResult.whiteWins &&
            currentSession.playerColor == chess.Color.BLACK ||
        currentSession.result == GameResult.blackWins &&
            currentSession.playerColor == chess.Color.WHITE;'''

new_stats2 = '''  Future<void> _recordStatisticsIfNeeded(GameSession currentSession) async {
    if (!mounted) return;
    if (currentSession.isRecorded ||
        currentSession.status == GameStatus.active) {
      return;
    }

    final isWin = currentSession.result == GameResult.whiteWins &&
            currentSession.playerColor == chess.Color.WHITE ||
        currentSession.result == GameResult.blackWins &&
            currentSession.playerColor == chess.Color.BLACK;

    final isLoss = currentSession.result == GameResult.whiteWins &&
            currentSession.playerColor == chess.Color.BLACK ||
        currentSession.result == GameResult.blackWins &&
            currentSession.playerColor == chess.Color.WHITE;'''

content = content.replace(old_stats2, new_stats2)

with open('lib/providers/game_session_viewmodel.dart', 'w') as f:
    f.write(content)
