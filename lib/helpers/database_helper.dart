// lib/helpers/database_helper.dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:myapp/services/osint_service.dart';

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
    final path = join(await getDatabasesPath(), 'hash1_database.db');

    return await openDatabase(
      path,
      version: 3, // Set to version 3 for IP address support
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

        await db.execute('''
        CREATE TABLE ip_addresses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ip_address TEXT,
          as_owner TEXT,
          asn INTEGER,
          country TEXT,
          continent TEXT,
          detection_count INTEGER,
          detection_ratio TEXT,
          last_seen TEXT,
          reputation INTEGER,
          tags TEXT,
          av_labels TEXT,
          whois_info TEXT,
          resolutions TEXT,
          geolocation TEXT,
          is_tor_exit_node INTEGER,
          abuse_score INTEGER,
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

        if (oldVersion < 3) {
          // Add new IP table when upgrading to version 3
          await db.execute('''
          CREATE TABLE ip_addresses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip_address TEXT,
            as_owner TEXT,
            asn INTEGER,
            country TEXT,
            continent TEXT,
            detection_count INTEGER,
            detection_ratio TEXT,
            last_seen TEXT,
            reputation INTEGER,
            tags TEXT,
            av_labels TEXT,
            whois_info TEXT,
            resolutions TEXT,
            geolocation TEXT,
            is_tor_exit_node INTEGER,
            abuse_score INTEGER,
            full_results TEXT,
            timestamp TEXT
          )
          ''');
        }
      },
    );
  }

  // File Hash Methods
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

  // IP Address Methods
  Future<void> insertIp(
    String ipAddress,
    Map<String, dynamic> vtData, {
    Map<String, dynamic>? osintData,
  }) async {
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

    // Parse WHOIS information if available
    Map<String, dynamic> whoisInfo = {};
    if (attributes.containsKey('whois')) {
      final whois = attributes['whois'] as String;
      whoisInfo = OSINTService.parseWhoisData(whois);
    }

    // Prepare OSINT data
    Map<String, dynamic> geoData = {};
    bool isTorExitNode = false;
    int abuseScore = 0;

    if (osintData != null) {
      if (osintData.containsKey('geolocation')) {
        geoData = osintData['geolocation'];
      }
      if (osintData.containsKey('isTorExitNode')) {
        isTorExitNode = osintData['isTorExitNode'];
      }
      if (osintData.containsKey('abuseipdb') &&
          osintData['abuseipdb'].containsKey('data') &&
          osintData['abuseipdb']['data'].containsKey('abuseConfidenceScore')) {
        abuseScore = osintData['abuseipdb']['data']['abuseConfidenceScore'];
      }
    }

    await db.insert('ip_addresses', {
      'ip_address': ipAddress,
      'as_owner': attributes['as_owner'] ?? 'Unknown',
      'asn': attributes['asn'] ?? 0,
      'country': attributes['country'] ?? 'Unknown',
      'continent': attributes['continent'] ?? 'Unknown',
      'detection_count': stats['malicious'] ?? 0,
      'detection_ratio':
          '${stats['malicious']}/${stats['malicious'] + stats['undetected'] + stats['harmless']}',
      'last_seen':
          attributes.containsKey('last_analysis_date')
              ? DateTime.fromMillisecondsSinceEpoch(
                attributes['last_analysis_date'] * 1000,
              ).toIso8601String()
              : null,
      'reputation': attributes['reputation'] ?? 0,
      'tags':
          attributes.containsKey('tags')
              ? jsonEncode(attributes['tags'])
              : null,
      'av_labels': jsonEncode(avLabels),
      'whois_info': jsonEncode(whoisInfo),
      'resolutions':
          attributes.containsKey('resolutions')
              ? jsonEncode(attributes['resolutions'])
              : null,
      'geolocation': jsonEncode(geoData),
      'is_tor_exit_node': isTorExitNode ? 1 : 0,
      'abuse_score': abuseScore,
      'full_results': jsonEncode(vtData),
      'timestamp': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getIpAddresses() async {
    final db = await database;
    return await db.query('ip_addresses', orderBy: 'timestamp DESC');
  }

  // Common Methods
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('hashes');
    await db.delete('ip_addresses');
  }
}
