import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/models/game_session.dart';

/// Repository for managing GameSession persistence
class GameSessionRepository {
  final DatabaseService _dbService;

  GameSessionRepository(this._dbService);

  Future<Database> get _db => _dbService.database;

  /// Save or update a game session
  Future<void> saveSession(GameSession session) async {
    final db = await _db;
    await db.insert(
      'saved_games',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a specific game session by ID
  Future<GameSession?> getSession(String id) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return GameSession.fromMap(results.first);
    }
    return null;
  }

  /// Get all game sessions
  Future<List<GameSession>> getAllSessions({int? limit, int? offset}) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }

  /// Get unfinished real games (for Continue game screen)
  Future<List<GameSession>> getUnfinishedGames({int? limit}) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      where: 'result IS NULL AND isPuzzle = 0',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }
  
  /// Get real games history (finished and unfinished)
  Future<List<GameSession>> getRealGamesHistory({int? limit}) async {
    final db = await _db;
    final results = await db.query(
      'saved_games',
      where: 'isPuzzle = 0',
      orderBy: 'lastMoveTimeMs DESC',
      limit: limit,
    );

    return results.map((map) => GameSession.fromMap(map)).toList();
  }

  /// Delete a game session
  Future<void> deleteSession(String id) async {
    final db = await _db;
    await db.delete(
      'saved_games',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Clear all sessions
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('saved_games');
  }
}

/// Provider for the GameSessionRepository
final gameSessionRepositoryProvider = Provider<GameSessionRepository>((ref) {
  return GameSessionRepository(ref.watch(databaseServiceProvider));
});
