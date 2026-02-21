import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Database service for game persistence
class DatabaseService {
  static DatabaseService? _instance;
  Database? _database;

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  DatabaseService._();

  /// Get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'chess_master.db');

      return await openDatabase(
        path,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      debugPrint('Database initialization error: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Games table
    await db.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        name TEXT,
        custom_name TEXT,
        pgn TEXT NOT NULL,
        fen_start TEXT,
        fen_current TEXT,
        result TEXT,
        result_reason TEXT,
        player_color TEXT,
        bot_elo INTEGER,
        game_mode TEXT,
        time_control TEXT,
        white_time_remaining INTEGER,
        black_time_remaining INTEGER,
        created_at INTEGER,
        updated_at INTEGER,
        duration_seconds INTEGER,
        move_count INTEGER,
        is_saved INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        opening_name TEXT,
        hints_used INTEGER DEFAULT 0
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_games_created ON games(created_at DESC)',
    );
    await db.execute('CREATE INDEX idx_games_saved ON games(is_saved)');
    await db.execute('CREATE INDEX idx_games_completed ON games(is_completed)');

    // Statistics table (single row)
    await db.execute('''
      CREATE TABLE statistics (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total_games INTEGER DEFAULT 0,
        wins INTEGER DEFAULT 0,
        losses INTEGER DEFAULT 0,
        draws INTEGER DEFAULT 0,
        puzzles_solved INTEGER DEFAULT 0,
        puzzles_attempted INTEGER DEFAULT 0,
        current_puzzle_rating INTEGER DEFAULT 1200,
        games_by_elo TEXT,
        openings_played TEXT,
        last_updated INTEGER
      )
    ''');

    // Insert default statistics row
    await db.insert('statistics', {
      'id': 1,
      'total_games': 0,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    });

    // Puzzle progress table
    await db.execute('''
      CREATE TABLE puzzle_progress (
        puzzle_id INTEGER PRIMARY KEY,
        attempts INTEGER DEFAULT 0,
        solved INTEGER DEFAULT 0,
        last_attempted INTEGER
      )
    ''');

    // Analysis cache table
    await db.execute('''
      CREATE TABLE analysis_cache (
        game_id TEXT PRIMARY KEY,
        fen TEXT NOT NULL,
        moves TEXT NOT NULL,
        analysis_json TEXT NOT NULL,
        engine_depth INTEGER,
        analyzed_at INTEGER
      )
    ''');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');

    // Handle migrations between versions
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrateToVersion(db, version);
    }
  }

  /// Migrate database to specific version
  Future<void> _migrateToVersion(Database db, int version) async {
    switch (version) {
      case 1:
        // Initial version - tables should already be created by onCreate
        // But if we're upgrading from a version without tables, create them
        await _createTablesIfNotExist(db);
        break;
      case 2:
        // Add game_mode column to games table
        try {
          await db.execute('ALTER TABLE games ADD COLUMN game_mode TEXT');
          debugPrint('Added game_mode column to games table');
        } catch (e) {
          debugPrint('Error adding game_mode column (may already exist): $e');
        }
        break;
      case 3:
        // Add custom_name column to games table
        try {
          await db.execute('ALTER TABLE games ADD COLUMN custom_name TEXT');
          debugPrint('Added custom_name column to games table');
        } catch (e) {
          debugPrint('Error adding custom_name column (may already exist): $e');
        }
        break;
    }
  }

  /// Create tables if they don't exist (for migrations from version 0)
  Future<void> _createTablesIfNotExist(Database db) async {
    // Check if statistics table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='statistics'",
    );

    if (tables.isEmpty) {
      debugPrint('Creating missing tables during migration...');
      await _onCreate(db, 1);
    }
  }

  // ==================== GAME OPERATIONS ====================

  /// Save a game
  Future<void> saveGame(Map<String, dynamic> game) async {
    final db = await database;
    await db.insert(
      'games',
      game,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a game
  Future<void> updateGame(String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'games',
      {...updates, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get a game by ID
  Future<Map<String, dynamic>?> getGame(String id) async {
    final db = await database;
    final results = await db.query(
      'games',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all games
  Future<List<Map<String, dynamic>>> getAllGames({
    bool savedOnly = false,
    bool completedOnly = false,
    int? limit,
    int? offset,
  }) async {
    final db = await database;

    String? where;
    List<dynamic>? whereArgs;

    if (savedOnly && completedOnly) {
      where = 'is_saved = 1 AND is_completed = 1';
    } else if (savedOnly) {
      where = 'is_saved = 1';
    } else if (completedOnly) {
      where = 'is_completed = 1';
    }

    return await db.query(
      'games',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Get recent games (excluding completed ones for "Continue" section)
  Future<List<Map<String, dynamic>>> getRecentGames({
    int limit = 10,
    bool includeCompleted = true,
  }) async {
    final db = await database;

    String? where;
    if (!includeCompleted) {
      where = 'is_completed = 0';
    }

    return await db.query(
      'games',
      where: where,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  /// Get the most recent unfinished game
  Future<Map<String, dynamic>?> getLastUnfinishedGame() async {
    final db = await database;
    final results = await db.query(
      'games',
      where: 'is_completed = 0',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update game custom name
  Future<void> updateGameName(String id, String customName) async {
    final db = await database;
    await db.update(
      'games',
      {
        'custom_name': customName,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a game
  Future<void> deleteGame(String id) async {
    final db = await database;
    await db.delete('games', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all games
  Future<void> deleteAllGames() async {
    final db = await database;
    await db.delete('games');
  }

  /// Search games by date range
  Future<List<Map<String, dynamic>>> searchGamesByDate({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    return await db.query(
      'games',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
  }

  /// Search games by result
  Future<List<Map<String, dynamic>>> searchGamesByResult(String result) async {
    final db = await database;
    return await db.query(
      'games',
      where: 'result = ?',
      whereArgs: [result],
      orderBy: 'created_at DESC',
    );
  }

  // ==================== ANALYSIS OPERATIONS ====================

  /// Save analysis result
  Future<void> saveAnalysis(
    String gameId,
    String fen,
    String moves,
    String analysisJson,
    int depth,
  ) async {
    final db = await database;
    await db.insert('analysis_cache', {
      'game_id': gameId,
      'fen': fen,
      'moves': moves,
      'analysis_json': analysisJson,
      'engine_depth': depth,
      'analyzed_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get analysis result
  Future<Map<String, dynamic>?> getAnalysis(String gameId) async {
    final db = await database;
    final results = await db.query(
      'analysis_cache',
      where: 'game_id = ?',
      whereArgs: [gameId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ==================== STATISTICS OPERATIONS ====================

  /// Get statistics
  Future<Map<String, dynamic>?> getStatistics() async {
    try {
      final db = await database;
      final results = await db.query('statistics', where: 'id = 1');
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      // Return default statistics if table doesn't exist
      return {
        'id': 1,
        'total_games': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'puzzles_solved': 0,
        'puzzles_attempted': 0,
        'current_puzzle_rating': 1200,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// Update statistics
  Future<void> updateStatistics(Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('statistics', {
      ...updates,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = 1');
  }

  // ==================== PUZZLE PROGRESS ====================

  /// Save puzzle progress
  Future<void> savePuzzleProgress(int puzzleId, bool solved) async {
    final db = await database;
    final existing = await db.query(
      'puzzle_progress',
      where: 'puzzle_id = ?',
      whereArgs: [puzzleId],
    );

    int attempts = 1;
    if (existing.isNotEmpty) {
      attempts = (existing.first['attempts'] as int? ?? 0) + 1;
    }

    await db.insert('puzzle_progress', {
      'puzzle_id': puzzleId,
      'attempts': attempts,
      'solved':
          solved ? 1 : (existing.isNotEmpty ? existing.first['solved'] : 0),
      'last_attempted': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get puzzle history
  Future<List<Map<String, dynamic>>> getPuzzleHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'puzzle_progress',
      orderBy: 'last_attempted DESC',
      limit: limit,
    );
  }

  /// Increment game count
  Future<void> incrementGameStats({
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
    required int botElo,
  }) async {
    final stats = await getStatistics();
    if (stats == null) return;

    final updates = <String, dynamic>{
      'total_games': (stats['total_games'] as int) + 1,
    };

    if (isWin) {
      updates['wins'] = (stats['wins'] as int) + 1;
    } else if (isLoss) {
      updates['losses'] = (stats['losses'] as int) + 1;
    } else if (isDraw) {
      updates['draws'] = (stats['draws'] as int) + 1;
    }

    await updateStatistics(updates);
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

/// Provider for database service
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});
