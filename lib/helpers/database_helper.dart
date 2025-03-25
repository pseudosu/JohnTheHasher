// lib/helpers/database_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

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

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'argus_database.db');
    print('Initializing database at: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        print('Creating database tables...');

        // Create hashes table
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

        // Create ip_addresses table with minimum required columns
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
      },
    );
  }

  // File Hash Methods
  Future<void> insertHash(String hash, Map<String, dynamic> vtData) async {
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

  // IP Address Methods - Completely simplified
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
}
