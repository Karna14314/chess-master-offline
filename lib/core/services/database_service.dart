import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chess_master.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Games table
    await db.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        name TEXT,
        pgn TEXT NOT NULL,
        fen_start TEXT,
        fen_current TEXT,
        result TEXT,
        result_reason TEXT,
        player_color TEXT,
        bot_elo INTEGER,
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
    await db.execute('CREATE INDEX idx_games_created ON games(created_at DESC)');
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

    // Puzzles table
    await db.execute('''
      CREATE TABLE puzzles (
        id INTEGER PRIMARY KEY,
        fen TEXT,
        moves TEXT,
        rating INTEGER,
        themes TEXT,
        popularity INTEGER
      )
    ''');

    // Index on rating for fast lookup
    await db.execute('CREATE INDEX idx_puzzles_rating ON puzzles(rating)');

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
    if (oldVersion < 2) {
      // Add puzzles table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS puzzles (
          id INTEGER PRIMARY KEY,
          fen TEXT,
          moves TEXT,
          rating INTEGER,
          themes TEXT,
          popularity INTEGER
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_puzzles_rating ON puzzles(rating)');
    }
  }

  // ==================== PUZZLE OPERATIONS ====================

  /// Insert puzzles in batch
  Future<void> insertPuzzles(List<Map<String, dynamic>> puzzles) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final puzzle in puzzles) {
        batch.insert(
          'puzzles',
          puzzle,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Get puzzles with filters
  Future<List<Map<String, dynamic>>> getPuzzles({
    int? minRating,
    int? maxRating,
    String? theme,
    int limit = 100,
    bool random = true,
    int? offset,
  }) async {
    final db = await database;
    String? where;
    List<dynamic> whereArgs = [];

    final conditions = <String>[];

    if (minRating != null) {
      conditions.add('rating >= ?');
      whereArgs.add(minRating);
    }

    if (maxRating != null) {
      conditions.add('rating <= ?');
      whereArgs.add(maxRating);
    }

    if (theme != null && theme != 'all') {
      conditions.add('themes LIKE ?');
      whereArgs.add('%$theme%');
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
    }

    return await db.query(
      'puzzles',
      where: where,
      whereArgs: whereArgs,
      orderBy: random ? 'RANDOM()' : 'id',
      limit: limit,
      offset: offset,
    );
  }

  /// Get total puzzle count
  Future<int> getPuzzleCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM puzzles');
    return Sqflite.firstIntValue(result) ?? 0;
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

  /// Get recent games
  Future<List<Map<String, dynamic>>> getRecentGames({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'games',
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

  /// Delete a game
  Future<void> deleteGame(String id) async {
    final db = await database;
    await db.delete(
      'games',
      where: 'id = ?',
      whereArgs: [id],
    );
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
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
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
  Future<void> saveAnalysis(String gameId, String fen, String moves, String analysisJson, int depth) async {
    final db = await database;
    await db.insert(
      'analysis_cache',
      {
        'game_id': gameId,
        'fen': fen,
        'moves': moves,
        'analysis_json': analysisJson,
        'engine_depth': depth,
        'analyzed_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final db = await database;
    final results = await db.query('statistics', where: 'id = 1');
    return results.isNotEmpty ? results.first : null;
  }

  /// Update statistics
  Future<void> updateStatistics(Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'statistics',
      {...updates, 'last_updated': DateTime.now().millisecondsSinceEpoch},
      where: 'id = 1',
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
