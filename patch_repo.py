import re

with open('lib/data/repositories/game_session_repository.dart', 'r') as f:
    content = f.read()

# Replace getRealGamesHistory
old_history = """  Future<List<GameSession>> getRealGamesHistory({int? limit}) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      where: 'isPuzzle = 0',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }"""

new_history = """  Future<List<GameSession>> getRealGamesHistory({int? limit}) async {
    final db = await _db;
    // Exclude puzzles (isPuzzle = 1) and game modes 2 (analysis) and 3 (puzzle)
    // GameMode enum: 0=bot, 1=localMultiplayer, 2=analysis, 3=puzzle
    final results = await db.query(
      'saved_games',
      where: 'isPuzzle = 0 AND gameMode NOT IN (2, 3)',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }"""

content = content.replace(old_history, new_history)

# Also update getUnfinishedGames just to be safe
old_unfinished = """  Future<List<GameSession>> getUnfinishedGames({int? limit}) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      where: 'result IS NULL AND isPuzzle = 0',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }"""

new_unfinished = """  Future<List<GameSession>> getUnfinishedGames({int? limit}) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      where: 'result IS NULL AND isPuzzle = 0 AND gameMode NOT IN (2, 3)',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }"""

content = content.replace(old_unfinished, new_unfinished)

with open('lib/data/repositories/game_session_repository.dart', 'w') as f:
    f.write(content)

print("Patch applied")
