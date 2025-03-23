import 'dart:convert';

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
      version: 2, // Increase version number for migration
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE hashes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          hash TEXT,
          filename TEXT,
          file_type TEXT,
          file_size INTEGER,
          detection_count INTEGER,
          detection_ratio TEXT,
          first_seen TEXT,
          last_seen TEXT,
          popularity INTEGER,
          threat_level TEXT,
          threat_category TEXT,
          tags TEXT,
          signatures TEXT,
          av_labels TEXT,
          full_results TEXT,
          timestamp TEXT
        )
      ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add new columns to existing table
          await db.execute('ALTER TABLE hashes ADD COLUMN file_type TEXT');
          await db.execute('ALTER TABLE hashes ADD COLUMN file_size INTEGER');
          await db.execute(
            'ALTER TABLE hashes ADD COLUMN detection_count INTEGER',
          );
          await db.execute(
            'ALTER TABLE hashes ADD COLUMN detection_ratio TEXT',
          );
          await db.execute('ALTER TABLE hashes ADD COLUMN first_seen TEXT');
          await db.execute('ALTER TABLE hashes ADD COLUMN last_seen TEXT');
          await db.execute('ALTER TABLE hashes ADD COLUMN popularity INTEGER');
          await db.execute('ALTER TABLE hashes ADD COLUMN threat_level TEXT');
          await db.execute(
            'ALTER TABLE hashes ADD COLUMN threat_category TEXT',
          );
          await db.execute('ALTER TABLE hashes ADD COLUMN tags TEXT');
          await db.execute('ALTER TABLE hashes ADD COLUMN signatures TEXT');
          await db.execute('ALTER TABLE hashes ADD COLUMN av_labels TEXT');
          // Rename the old results column to full_results
          await db.execute(
            'ALTER TABLE hashes RENAME COLUMN results TO full_results',
          );
        }
      },
    );
  }

  Future<void> insertHash(String hash, Map<String, dynamic> vtData) async {
    final db = await database;

    final attributes = vtData['data']['attributes'];
    final stats = attributes['last_analysis_stats'];

    // Extract the most relevant AV labels
    List<String> avLabels = [];
    if (attributes.containsKey('last_analysis_results')) {
      final results = attributes['last_analysis_results'];
      results.forEach((engine, result) {
        if (result['category'] == 'malicious' && result['result'] != null) {
          avLabels.add('${engine}: ${result['result']}');
        }
      });
    }

    // Calculate threat level based on detection ratio
    String threatLevel = 'Clean';
    if (stats['malicious'] > 0) {
      double ratio =
          stats['malicious'] /
          (stats['malicious'] + stats['undetected'] + stats['harmless']);
      if (ratio > 0.5)
        threatLevel = 'High';
      else if (ratio > 0.2)
        threatLevel = 'Medium';
      else
        threatLevel = 'Low';
    }

    await db.insert('hashes', {
      'hash': hash,
      'filename': attributes['meaningful_name'] ?? 'Unknown',
      'file_type':
          attributes['type_description'] ?? attributes['type_tag'] ?? 'Unknown',
      'file_size': attributes['size'] ?? 0,
      'detection_count': stats['malicious'] ?? 0,
      'detection_ratio':
          '${stats['malicious']}/${stats['malicious'] + stats['undetected'] + stats['harmless']}',
      'first_seen':
          attributes.containsKey('first_submission_date')
              ? DateTime.fromMillisecondsSinceEpoch(
                attributes['first_submission_date'] * 1000,
              ).toIso8601String()
              : null,
      'last_seen':
          attributes.containsKey('last_analysis_date')
              ? DateTime.fromMillisecondsSinceEpoch(
                attributes['last_analysis_date'] * 1000,
              ).toIso8601String()
              : null,
      'popularity': attributes['times_submitted'] ?? 0,
      'threat_level': threatLevel,
      'threat_category':
          attributes.containsKey('popular_threat_classification')
              ? attributes['popular_threat_classification']['suggested_threat_label']
              : null,
      'tags':
          attributes.containsKey('tags')
              ? jsonEncode(attributes['tags'])
              : null,
      'signatures':
          attributes.containsKey('signature_info')
              ? jsonEncode(attributes['signature_info'])
              : null,
      'av_labels': jsonEncode(avLabels),
      'full_results': jsonEncode(vtData),
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
