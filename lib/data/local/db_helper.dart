import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'tooby.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _onCreate(db, version);
      },
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE videos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT UNIQUE,
        title TEXT,
        duration TEXT,
        thumbnail TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tag_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        type_id INTEGER DEFAULT 1 REFERENCES tag_types(id) ON DELETE SET DEFAULT
      )
    ''');

    await db.execute('''
      CREATE TABLE video_tags(
        video_id INTEGER,
        tag_id INTEGER,
        PRIMARY KEY (video_id, tag_id),
        FOREIGN KEY (video_id) REFERENCES videos (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE watch_history(
        video_id INTEGER PRIMARY KEY,
        last_position INTEGER,
        last_watched INTEGER,
        FOREIGN KEY (video_id) REFERENCES videos (id) ON DELETE CASCADE
      )
    ''');

    // Insert default tag type
    await db.insert('tag_types', {'name': 'default'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Create tag_types table
      await db.execute('''
        CREATE TABLE tag_types(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE
        )
      ''');

      // 2. Insert default tag type (receives ID 1)
      await db.insert('tag_types', {'name': 'default'});

      // 3. Alter tags table to add type_id column
      await db.execute('ALTER TABLE tags ADD COLUMN type_id INTEGER DEFAULT 1 REFERENCES tag_types(id) ON DELETE SET DEFAULT');
    }
  }

  // Generic methods
  Future<int> insert(String table, Map<String, dynamic> data) async {
    Database db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    Database db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    Database db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> rawDelete(String sql, List<dynamic> args) async {
    Database db = await database;
    return await db.rawDelete(sql, args);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, List<dynamic> args) async {
    Database db = await database;
    return await db.rawQuery(sql, args);
  }
}
