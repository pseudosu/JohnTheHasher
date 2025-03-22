import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'hash_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE hashes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash TEXT,
            filename TEXT,
            results TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertHash(String hash, String filename, String results) async {
    final db = await database;
    print("hash subd");
    await db.insert('hashes', {
      'hash': hash,
      'filename': filename,
      'results': results,
      'timestamp': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getHashes() async {
    final db = await database;
    return await db.query('hashes', orderBy: 'timestamp DESC');
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('hashes');
  }
}
