import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static const String _databaseName = 'walking_buddy.db';
  static const int _databaseVersion = 4;
  static const String _tableName = 'walk_entries';
  static const String _impactsTable = 'impacts';
  static const String _feedbackImpactsTable = 'feedback_impacts';
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createWalkEntriesTable(db);
    await _createImpactsTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createImpactsTables(db);
    }
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE $_impactsTable
        ADD COLUMN updated_at TEXT
      ''');
      await db.execute('''
        UPDATE $_impactsTable
        SET updated_at = created_at
        WHERE updated_at IS NULL
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE $_tableName
        ADD COLUMN route_name TEXT
      ''');
    }
  }

  Future<void> _createWalkEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        from_location TEXT NOT NULL,
        to_location TEXT NOT NULL,
        route_name TEXT,
        distance REAL NOT NULL,
        transport_mode TEXT NOT NULL,
        crowd_level TEXT NOT NULL,
        comfort_score INTEGER NOT NULL,
        latitude REAL,
        longitude REAL,
        user_id TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createImpactsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_impactsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        route_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('under_review', 'in_progress', 'resolved')),
        feedback_count INTEGER NOT NULL DEFAULT 0,
        date_first_reported TEXT NOT NULL,
        outcome_text TEXT,
        progress_note TEXT,
        date_resolved TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_feedbackImpactsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feedback_id INTEGER NOT NULL,
        impact_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(feedback_id, impact_id),
        FOREIGN KEY(feedback_id) REFERENCES $_tableName(id) ON DELETE CASCADE,
        FOREIGN KEY(impact_id) REFERENCES $_impactsTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertWalkEntry(Map<String, dynamic> entry) async {
    final db = await database;

    final normalizedEntry = <String, dynamic>{
      'name': entry['name'],
      'from_location': entry['from'] ?? entry['from_location'],
      'to_location': entry['to'] ?? entry['to_location'],
      'route_name': entry['route_name'],
      'distance': entry['distance'],
      'transport_mode': entry['transport'] ?? entry['transport_mode'],
      'crowd_level': entry['crowds'] ?? entry['crowd_level'],
      'comfort_score': entry['comfort'] ?? entry['comfort_score'],
      'latitude': entry['latitude'],
      'longitude': entry['longitude'],
      'user_id': entry['user_id'] ?? 'demo_user',
      'timestamp': entry['timestamp'],
    };

    return await db.insert(_tableName, normalizedEntry);
  }

  Future<List<Map<String, dynamic>>> getWalkEntries() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        id,
        name,
        from_location AS "from",
        to_location AS "to",
        route_name,
        distance,
        transport_mode AS transport,
        crowd_level AS crowds,
        comfort_score AS comfort,
        latitude,
        longitude,
        user_id,
        timestamp
      FROM $_tableName
      ORDER BY timestamp DESC
    ''');
  }

  Future<int> deleteWalkEntry(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertImpact(Map<String, dynamic> impact) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final withUpdatedAt = {
      ...impact,
      'updated_at': impact['updated_at'] ?? nowIso,
    };
    return await db.insert(_impactsTable, withUpdatedAt);
  }

  Future<int> updateImpact(int id, Map<String, dynamic> impact) async {
    final db = await database;
    final withUpdatedAt = {
      ...impact,
      'updated_at': DateTime.now().toIso8601String(),
    };
    return await db.update(
      _impactsTable,
      withUpdatedAt,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getImpacts() async {
    final db = await database;
    return db.query(
      _impactsTable,
      orderBy: 'updated_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getImpactBoardRows(
      String currentUserId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        i.id,
        i.title,
        i.category,
        i.route_id,
        i.status,
        i.feedback_count,
        i.date_first_reported,
        i.outcome_text,
        i.progress_note,
        i.date_resolved,
        i.created_at,
        i.updated_at,
        CASE WHEN EXISTS (
          SELECT 1
          FROM $_feedbackImpactsTable fi
          INNER JOIN $_tableName w ON w.id = fi.feedback_id
          WHERE fi.impact_id = i.id AND w.user_id = ?
        ) THEN 1 ELSE 0 END AS you_reported_this
      FROM $_impactsTable i
      ORDER BY COALESCE(i.updated_at, i.created_at) DESC
    ''', [currentUserId]);
  }

  Future<Map<String, int>> getImpactBoardMetrics() async {
    final db = await database;

    final totalSubmissionsRow = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_tableName',
    );
    final actedOnRow = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM $_impactsTable WHERE status IN ('in_progress', 'resolved')",
    );
    final contributorsRow = await db.rawQuery(
      "SELECT COUNT(DISTINCT user_id) AS c FROM $_tableName WHERE user_id IS NOT NULL AND user_id != ''",
    );

    return {
      'total_submissions':
          (totalSubmissionsRow.first['c'] as num?)?.toInt() ?? 0,
      'issues_acted_on': (actedOnRow.first['c'] as num?)?.toInt() ?? 0,
      'contributors': (contributorsRow.first['c'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<int>> getLinkedFeedbackIds(int impactId) async {
    final db = await database;
    final rows = await db.query(
      _feedbackImpactsTable,
      columns: ['feedback_id'],
      where: 'impact_id = ?',
      whereArgs: [impactId],
      orderBy: 'feedback_id DESC',
    );
    return rows
        .map((r) => (r['feedback_id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  Future<void> replaceImpactFeedbackLinks(
    int impactId,
    List<int> feedbackIds,
  ) async {
    final db = await database;
    final uniqueIds = feedbackIds.toSet().toList();
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        _feedbackImpactsTable,
        where: 'impact_id = ?',
        whereArgs: [impactId],
      );

      for (final feedbackId in uniqueIds) {
        await txn.insert(
          _feedbackImpactsTable,
          {
            'feedback_id': feedbackId,
            'impact_id': impactId,
            'created_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await txn.update(
        _impactsTable,
        {'feedback_count': uniqueIds.length},
        where: 'id = ?',
        whereArgs: [impactId],
      );
    });
  }
}
