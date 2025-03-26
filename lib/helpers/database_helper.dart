// lib/helpers/database_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  // Database version - increment this when schema changes
  static const int _databaseVersion = 2;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'argussy_database.db');
    print('Initializing database at: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    print('Creating database tables...');

    // Create hashes table with expanded fields
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
      behavior_data TEXT,
      mitre_attack_data TEXT,
      sha1 TEXT,
      md5 TEXT,
      timestamp TEXT
    )
    ''');

    // Create ip_addresses table
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
      dns_data TEXT,
      geolocation TEXT,
      is_tor_exit_node INTEGER,
      abuse_score INTEGER,
      full_results TEXT,
      timestamp TEXT
    )
    ''');

    print('Database tables created successfully');
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Migration from version 1 to 2
      try {
        // Add new columns to hashes table
        await db.execute('ALTER TABLE hashes ADD COLUMN behavior_data TEXT');
        await db.execute(
          'ALTER TABLE hashes ADD COLUMN mitre_attack_data TEXT',
        );
        await db.execute('ALTER TABLE hashes ADD COLUMN sha1 TEXT');
        await db.execute('ALTER TABLE hashes ADD COLUMN md5 TEXT');

        print('Database upgraded to version 2');
      } catch (e) {
        print('Error during database upgrade: $e');
      }
    }
  }

  // Force database recreation by deleting the file
  Future<void> forceRecreateDatabase() async {
    try {
      // Close existing database if open
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }

      // Get path and delete file
      final path = join(await getDatabasesPath(), 'argus_database.db');
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('Database file deleted successfully');
      }
    } catch (e) {
      print('Error recreating database: $e');
    }
  }

  // File Hash Methods
  Future<void> insertHash(
    String hash,
    Map<String, dynamic> vtData, {
    Map<String, dynamic>? behaviorData,
    Map<String, dynamic>? mitreData,
  }) async {
    try {
      final db = await database;
      final attributes = vtData['data']['attributes'];
      final stats = attributes['last_analysis_stats'];

      // Extract AV labels
      List<String> avLabels = [];
      if (attributes.containsKey('last_analysis_results')) {
        final results = attributes['last_analysis_results'];
        results.forEach((engine, result) {
          if (result['category'] == 'malicious' && result['result'] != null) {
            avLabels.add('${engine}: ${result['result']}');
          }
        });
      }

      // Calculate threat level
      String threatLevel = 'Clean';
      if (stats['malicious'] > 0) {
        double ratio =
            stats['malicious'] /
            (stats['malicious'] + stats['undetected'] + stats['harmless']);
        if (ratio > 0.5) {
          threatLevel = 'High';
        } else if (ratio > 0.2) {
          threatLevel = 'Medium';
        } else {
          threatLevel = 'Low';
        }
      }

      // Safely extract threat category
      String? threatCategory;
      if (attributes.containsKey('popular_threat_classification') &&
          attributes['popular_threat_classification'] != null &&
          attributes['popular_threat_classification'].containsKey(
            'suggested_threat_label',
          )) {
        threatCategory =
            attributes['popular_threat_classification']['suggested_threat_label'];
      }

      await db.insert('hashes', {
        'hash': hash,
        'filename': attributes['meaningful_name'] ?? 'Unknown',
        'file_type':
            attributes['type_description'] ??
            attributes['type_tag'] ??
            'Unknown',
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
        'threat_category': threatCategory,
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
        'behavior_data': behaviorData != null ? jsonEncode(behaviorData) : null,
        'mitre_attack_data': mitreData != null ? jsonEncode(mitreData) : null,
        'sha1': attributes['sha1'] ?? null,
        'md5': attributes['md5'] ?? null,
        'timestamp': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('Hash record inserted successfully');
    } catch (e) {
      print('Error inserting hash: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getHashes() async {
    try {
      final db = await database;
      return await db.query('hashes', orderBy: 'timestamp DESC');
    } catch (e) {
      print('Error getting hashes: $e');
      return [];
    }
  }

  // Search and filtering methods
  Future<List<Map<String, dynamic>>> searchHashes(String query) async {
    try {
      final db = await database;
      return await db.query(
        'hashes',
        where:
            'hash LIKE ? OR filename LIKE ? OR file_type LIKE ? OR tags LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
        orderBy: 'timestamp DESC',
      );
    } catch (e) {
      print('Error searching hashes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> filterHashes({
    bool? isMalicious,
    String? fileType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;

      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];

      if (isMalicious != null) {
        whereConditions.add('detection_count ${isMalicious ? '>' : '='} 0');
      }

      if (fileType != null) {
        whereConditions.add('file_type = ?');
        whereArgs.add(fileType);
      }

      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereConditions.add('timestamp <= ?');
        whereArgs.add(endDate.toIso8601String());
      }

      String whereClause =
          whereConditions.isEmpty
              ? ''
              : 'WHERE ${whereConditions.join(' AND ')}';

      return await db.rawQuery(
        'SELECT * FROM hashes $whereClause ORDER BY timestamp DESC',
        whereArgs,
      );
    } catch (e) {
      print('Error filtering hashes: $e');
      return [];
    }
  }

  // Batch operations
  Future<void> insertBatchHashes(List<Map<String, dynamic>> entries) async {
    try {
      final db = await database;
      final batch = db.batch();

      for (var entry in entries) {
        batch.insert(
          'hashes',
          entry,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      print(
        'Batch insertion completed successfully (${entries.length} records)',
      );
    } catch (e) {
      print('Error during batch insertion: $e');
      throw e;
    }
  }

  // IP Address Methods
  Future<void> insertIp(
    String ipAddress,
    Map<String, dynamic> vtData, {
    Map<String, dynamic>? osintData,
  }) async {
    try {
      print('Inserting IP address: $ipAddress');
      final db = await database;
      final attributes = vtData['data']['attributes'];
      final stats = attributes['last_analysis_stats'];

      // Extract AV labels
      final avLabels = <String>[];
      if (attributes.containsKey('last_analysis_results')) {
        final results = attributes['last_analysis_results'];
        results.forEach((engine, result) {
          if (result['category'] == 'malicious' && result['result'] != null) {
            avLabels.add('${engine}: ${result['result']}');
          }
        });
      }

      // Extract OSINT data
      Map<String, dynamic> geoData = {};
      List<Map<String, dynamic>> dnsRecords = [];
      bool isTorExitNode = false;
      int abuseScore = 0;

      if (osintData != null) {
        // Safely extract geolocation
        if (osintData.containsKey('geolocation')) {
          geoData = osintData['geolocation'] ?? {};
        }

        // Safely extract DNS records
        if (osintData.containsKey('dnsRecords')) {
          final records = osintData['dnsRecords'];
          if (records is List) {
            for (var record in records) {
              if (record is Map) {
                dnsRecords.add(Map<String, dynamic>.from(record));
              }
            }
          }
        }

        // Extract other OSINT data
        isTorExitNode = osintData['isTorExitNode'] ?? false;
        if (osintData.containsKey('abuseipdb') &&
            osintData['abuseipdb'] is Map &&
            osintData['abuseipdb'].containsKey('data') &&
            osintData['abuseipdb']['data'] is Map &&
            osintData['abuseipdb']['data'].containsKey(
              'abuseConfidenceScore',
            )) {
          abuseScore =
              osintData['abuseipdb']['data']['abuseConfidenceScore'] ?? 0;
        }
      }

      // If no DNS records found, create a placeholder
      if (dnsRecords.isEmpty) {
        dnsRecords = [
          {
            'type': 'INFO',
            'value': 'No domain information available',
            'ttl': 0,
            'date': DateTime.now().toIso8601String(),
            'source': 'Auto-generated',
          },
        ];
      }

      // Insert record
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
        'whois_info': jsonEncode(
          attributes.containsKey('whois') ? attributes['whois'] : {},
        ),
        'dns_data': jsonEncode(dnsRecords),
        'geolocation': jsonEncode(geoData),
        'is_tor_exit_node': isTorExitNode ? 1 : 0,
        'abuse_score': abuseScore,
        'full_results': jsonEncode(vtData),
        'timestamp': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('IP record inserted successfully');
    } catch (e) {
      print('Error inserting IP: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getIpAddresses() async {
    try {
      print('Getting IP addresses');
      final db = await database;
      final ipRecords = await db.query(
        'ip_addresses',
        orderBy: 'timestamp DESC',
      );
      print('Retrieved ${ipRecords.length} IP records');

      // Process each IP record to ensure compatibility with UI
      return ipRecords.map((ip) {
        final processedIp = Map<String, dynamic>.from(ip);

        // Extract DNS records and add to 'resolutions' field for UI compatibility
        if (ip.containsKey('dns_data') && ip['dns_data'] != null) {
          try {
            // Parse the DNS data - always jsonDecode first
            final dnsDataStr =
                ip['dns_data'] as String; // Explicitly cast to String
            final dnsData = jsonDecode(dnsDataStr);

            // Add the decoded DNS data as 'resolutions' for backward compatibility
            processedIp['resolutions'] = dnsDataStr; // Use the original string
          } catch (e) {
            print('Error processing DNS data: $e');
            // Provide fallback
            processedIp['resolutions'] = jsonEncode([
              {
                'type': 'INFO',
                'value': 'Error processing domain data',
                'ttl': 0,
                'date': DateTime.now().toIso8601String(),
                'source': 'Error',
              },
            ]);
          }
        } else {
          // No DNS data, provide fallback
          processedIp['resolutions'] = jsonEncode([
            {
              'type': 'INFO',
              'value': 'No domain information available',
              'ttl': 0,
              'date': DateTime.now().toIso8601String(),
              'source': 'None',
            },
          ]);
        }

        return processedIp;
      }).toList();
    } catch (e) {
      print('Error getting IP addresses: $e');
      return [];
    }
  }

  // IP address search and filtering
  Future<List<Map<String, dynamic>>> searchIpAddresses(String query) async {
    try {
      final db = await database;
      final ipRecords = await db.query(
        'ip_addresses',
        where: 'ip_address LIKE ? OR country LIKE ? OR as_owner LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'timestamp DESC',
      );

      // Process results for UI compatibility (same as getIpAddresses)
      return _processIpRecords(ipRecords);
    } catch (e) {
      print('Error searching IP addresses: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> filterIpAddresses({
    bool? isMalicious,
    String? country,
    bool? isTorExitNode,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;

      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];

      if (isMalicious != null) {
        whereConditions.add('detection_count ${isMalicious ? '>' : '='} 0');
      }

      if (country != null) {
        whereConditions.add('country = ?');
        whereArgs.add(country);
      }

      if (isTorExitNode != null) {
        whereConditions.add('is_tor_exit_node = ?');
        whereArgs.add(isTorExitNode ? 1 : 0);
      }

      if (startDate != null) {
        whereConditions.add('timestamp >= ?');
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereConditions.add('timestamp <= ?');
        whereArgs.add(endDate.toIso8601String());
      }

      String whereClause =
          whereConditions.isEmpty
              ? ''
              : 'WHERE ${whereConditions.join(' AND ')}';

      final ipRecords = await db.rawQuery(
        'SELECT * FROM ip_addresses $whereClause ORDER BY timestamp DESC',
        whereArgs,
      );

      // Process results for UI compatibility
      return _processIpRecords(ipRecords);
    } catch (e) {
      print('Error filtering IP addresses: $e');
      return [];
    }
  }

  // Helper to process IP records for UI compatibility
  List<Map<String, dynamic>> _processIpRecords(
    List<Map<String, dynamic>> ipRecords,
  ) {
    return ipRecords.map((ip) {
      final processedIp = Map<String, dynamic>.from(ip);

      // Add resolutions field for backward compatibility
      if (ip.containsKey('dns_data') && ip['dns_data'] != null) {
        try {
          final dnsDataStr = ip['dns_data'] as String;
          jsonDecode(dnsDataStr); // Validate JSON but don't modify
          processedIp['resolutions'] = dnsDataStr;
        } catch (e) {
          print('Error processing DNS data: $e');
          processedIp['resolutions'] = jsonEncode([
            {
              'type': 'INFO',
              'value': 'Error processing domain data',
              'ttl': 0,
              'date': DateTime.now().toIso8601String(),
              'source': 'Error',
            },
          ]);
        }
      } else {
        processedIp['resolutions'] = jsonEncode([
          {
            'type': 'INFO',
            'value': 'No domain information available',
            'ttl': 0,
            'date': DateTime.now().toIso8601String(),
            'source': 'None',
          },
        ]);
      }

      return processedIp;
    }).toList();
  }

  // Statistics methods
  Future<Map<String, dynamic>> getHashStatistics() async {
    try {
      final db = await database;

      // Total count
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM hashes',
      );
      final totalCount = Sqflite.firstIntValue(totalResult) ?? 0;

      // Malicious count
      final maliciousResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM hashes WHERE detection_count > 0',
      );
      final maliciousCount = Sqflite.firstIntValue(maliciousResult) ?? 0;

      // Clean count
      final cleanCount = totalCount - maliciousCount;

      // File type distribution
      final typeResult = await db.rawQuery(
        'SELECT file_type, COUNT(*) as count FROM hashes GROUP BY file_type ORDER BY count DESC',
      );
      final fileTypes =
          typeResult
              .map((row) => {'type': row['file_type'], 'count': row['count']})
              .toList();

      // Detection ratio stats
      final avgDetectionResult = await db.rawQuery(
        'SELECT AVG(detection_count) as avg FROM hashes WHERE detection_count > 0',
      );
      final avgDetection =
          avgDetectionResult.first['avg'] != null
              ? (avgDetectionResult.first['avg'] as num).toDouble()
              : 0.0;

      // Date distribution (by month)
      final dateResult = await db.rawQuery(
        "SELECT substr(timestamp, 1, 7) as month, COUNT(*) as count FROM hashes GROUP BY month ORDER BY month",
      );
      final dateDistribution =
          dateResult
              .map((row) => {'month': row['month'], 'count': row['count']})
              .toList();

      return {
        'totalCount': totalCount,
        'maliciousCount': maliciousCount,
        'cleanCount': cleanCount,
        'fileTypes': fileTypes,
        'avgDetection': avgDetection,
        'dateDistribution': dateDistribution,
      };
    } catch (e) {
      print('Error getting hash statistics: $e');
      return {
        'totalCount': 0,
        'maliciousCount': 0,
        'cleanCount': 0,
        'fileTypes': [],
        'avgDetection': 0.0,
        'dateDistribution': [],
      };
    }
  }

  // General utility methods
  Future<void> clearDatabase() async {
    try {
      print('Clearing database');
      final db = await database;
      await db.delete('hashes');
      await db.delete('ip_addresses');
      print('Database cleared successfully');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }

  // Export functionality
  Future<List<Map<String, dynamic>>> exportHashes() async {
    try {
      final db = await database;
      final results = await db.query('hashes');

      // Create export-friendly format
      return results.map((row) {
        // Parse JSON fields
        final Map<String, dynamic> exportRow = {};

        // Copy all fields
        row.forEach((key, value) {
          // Skip large JSON blobs for export
          if (key == 'full_results' ||
              key == 'behavior_data' ||
              key == 'mitre_attack_data') {
            return;
          }

          // Parse JSON fields
          if (value != null &&
              (key == 'tags' || key == 'av_labels' || key == 'signatures')) {
            try {
              exportRow[key] = jsonDecode(value.toString());
            } catch (e) {
              exportRow[key] = value;
            }
          } else {
            exportRow[key] = value;
          }
        });

        return exportRow;
      }).toList();
    } catch (e) {
      print('Error exporting hashes: $e');
      return [];
    }
  }
}
