import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = 'walking_buddy.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'walk_entries';

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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE  (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        distance REAL NOT NULL,
        duration INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertWalkEntry(Map<String, dynamic> entry) async {
    final db = await database;
    return await db.insert(_tableName, entry);
  }

  Future<List<Map<String, dynamic>>> getWalkEntries() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'timestamp DESC');
  }

  Future<int> deleteWalkEntry(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
