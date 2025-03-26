import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirusTotalService {
  static final String _baseUrl = 'https://www.virustotal.com/api/v3';
  static final Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
  };

  // Get API key with cache to avoid repeated lookups
  static String? _cachedApiKey;
  static String get _apiKey {
    if (_cachedApiKey != null) return _cachedApiKey!;

    final apiKey = dotenv.env['VIRUSTOTAL_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'VirusTotal API key not found. Please add it to your .env file as VIRUSTOTAL_API_KEY=your_key_here',
      );
    }

    _cachedApiKey = apiKey;
    return apiKey;
  }

  // Get headers with API key
  static Map<String, String> get _headers => {
    ..._defaultHeaders,
    'x-apikey': _apiKey,
  };

  // Basic hash check
  static Future<Map<String, dynamic>> checkHash(String hash) async {
    final url = Uri.parse('$_baseUrl/files/$hash');
    final response = await _makeRequest(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('Hash not found in VirusTotal database');
    } else {
      throw Exception(
        'Failed to check hash: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Batch hash check - processes multiple hashes efficiently
  static Future<List<Map<String, dynamic>>> checkHashBatch(
    List<String> hashes,
  ) async {
    // Use collection to process in batches of 4
    final results = <Map<String, dynamic>>[];
    final errors = <String, String>{};

    // Process batches of 4 with concurrency
    for (var i = 0; i < hashes.length; i += 4) {
      final end = (i + 4 < hashes.length) ? i + 4 : hashes.length;
      final batch = hashes.sublist(i, end);

      // Get all hashes in this batch concurrently
      final batchResults = await Future.wait(
        batch.map(
          (hash) => checkHash(hash).catchError((e) {
            errors[hash] = e.toString();
            return <String, dynamic>{'error': e.toString()};
          }),
        ),
      );

      results.addAll(batchResults);

      // Add a small delay to respect API rate limits
      if (end < hashes.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }

  // Get behavioral data for malicious files
  static Future<Map<String, dynamic>> getBehaviorData(String hash) async {
    final url = Uri.parse('$_baseUrl/files/$hash/behaviours');
    final response = await _makeRequest(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('Behavior data not available for this file');
    } else {
      throw Exception(
        'Failed to get behavior data: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get file analysis - triggers a new analysis if available
  static Future<Map<String, dynamic>> analyzeFile(String hash) async {
    final url = Uri.parse('$_baseUrl/files/$hash/analyse');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 429) {
      // Handle quota limit
      throw Exception('Daily quota for file analysis exceeded');
    } else {
      throw Exception('Failed to analyze file: ${response.statusCode}');
    }
  }

  // Get MITRE ATT&CK data for the file
  static Future<Map<String, dynamic>> getMitreAttackData(String hash) async {
    final url = Uri.parse('$_baseUrl/files/$hash/behaviour_mitre_trees');
    final response = await _makeRequest(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('MITRE ATT&CK data not available for this file');
    } else {
      throw Exception(
        'Failed to get MITRE ATT&CK data: ${response.statusCode}',
      );
    }
  }

  // Get related samples (similar files)
  static Future<Map<String, dynamic>> getRelatedSamples(String hash) async {
    final url = Uri.parse('$_baseUrl/files/$hash/similar_files');
    final response = await _makeRequest(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('Related samples not available for this file');
    } else {
      throw Exception('Failed to get related samples: ${response.statusCode}');
    }
  }

  // Upload file with URL (for files larger than allowed via direct upload)
  static Future<Map<String, dynamic>> uploadUrlForAnalysis(
    String fileUrl,
  ) async {
    final url = Uri.parse('$_baseUrl/urls');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'url': fileUrl}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit URL: ${response.statusCode}');
    }
  }

  // Helper method to make request with retry logic
  static Future<http.Response> _makeRequest(Uri url, {int retries = 2}) async {
    http.Response? response;
    var attempts = 0;

    while (attempts <= retries) {
      try {
        response = await http.get(url, headers: _headers);

        // Return immediately on success or non-retriable errors
        if (response.statusCode == 200 ||
            response.statusCode == 404 ||
            response.statusCode == 400) {
          return response;
        }

        // Rate limit hit - wait and retry
        if (response.statusCode == 429) {
          await Future.delayed(
            Duration(seconds: math.pow(2, attempts).toInt()),
          );
          attempts++;
          continue;
        }

        // Other error - just return
        return response;
      } catch (e) {
        if (attempts == retries) rethrow;
        await Future.delayed(Duration(seconds: math.pow(2, attempts).toInt()));
        attempts++;
      }
    }

    // This should never happen but needed for compiler
    return response!;
  }

  // Extract file details from VT response
  static Map<String, dynamic> extractFileDetails(
    Map<String, dynamic> vtResponse,
  ) {
    final attributes = vtResponse['data']['attributes'];
    final stats = attributes['last_analysis_stats'];

    // Calculate detection percentage
    final total =
        stats['malicious'] +
        stats['undetected'] +
        stats['harmless'] +
        stats['suspicious'] +
        stats['timeout'];
    final detectionPercentage =
        total > 0 ? (stats['malicious'] / total) * 100 : 0;

    // Extract top 5 antivirus detections
    List<Map<String, String>> topDetections = [];
    if (attributes.containsKey('last_analysis_results')) {
      final results = attributes['last_analysis_results'];
      results.forEach((engine, result) {
        if (result['category'] == 'malicious' && result['result'] != null) {
          topDetections.add({'engine': engine, 'result': result['result']});
        }
      });
      // Sort by engine name for consistency
      topDetections.sort((a, b) => a['engine']!.compareTo(b['engine']!));
      // Keep only top 5
      if (topDetections.length > 5) {
        topDetections = topDetections.sublist(0, 5);
      }
    }

    // Extract threat categories
    String? threatCategory;
    List<String> threatCategories = [];
    if (attributes.containsKey('popular_threat_classification')) {
      final threatClassification = attributes['popular_threat_classification'];

      // Get main category
      if (threatClassification.containsKey('suggested_threat_label')) {
        threatCategory = threatClassification['suggested_threat_label'];
      }

      // Get all categories
      if (threatClassification.containsKey('popular_threat_category')) {
        for (var category in threatClassification['popular_threat_category']) {
          if (category.containsKey('value')) {
            threatCategories.add(category['value']);
          }
        }
      }
    }

    return {
      'fileName': attributes['meaningful_name'] ?? 'Unknown',
      'fileType':
          attributes['type_description'] ?? attributes['type_tag'] ?? 'Unknown',
      'fileSize': attributes['size'] ?? 0,
      'md5': attributes['md5'] ?? '',
      'sha1': attributes['sha1'] ?? '',
      'sha256': attributes['sha256'] ?? '',
      'detectionStats': stats,
      'detectionPercentage': detectionPercentage.toStringAsFixed(1),
      'firstSeen':
          attributes.containsKey('first_submission_date')
              ? DateTime.fromMillisecondsSinceEpoch(
                attributes['first_submission_date'] * 1000,
              )
              : null,
      'lastSeen':
          attributes.containsKey('last_analysis_date')
              ? DateTime.fromMillisecondsSinceEpoch(
                attributes['last_analysis_date'] * 1000,
              )
              : null,
      'popularityRank': attributes['times_submitted'] ?? 0,
      'tags': attributes['tags'] ?? [],
      'topDetections': topDetections,
      'signatureInfo': attributes['signature_info'] ?? {},
      'threatCategory': threatCategory ?? 'Unknown',
      'threatCategories': threatCategories,
    };
  }

  // Extract behavioral insights from behavior data
  static Map<String, dynamic> extractBehaviorInsights(
    Map<String, dynamic> behaviorData,
  ) {
    if (!behaviorData.containsKey('data') ||
        behaviorData['data'] is! List ||
        behaviorData['data'].isEmpty) {
      return {'error': 'No behavior data available'};
    }

    try {
      final behaviors = behaviorData['data'][0];
      final attributes = behaviors['attributes'];

      // Process capabilities
      final List<String> capabilities = [];
      if (attributes.containsKey('capabilities')) {
        for (var capability in attributes['capabilities']) {
          capabilities.add(capability);
        }
      }

      // Process MITRE ATT&CK tactics
      final List<Map<String, dynamic>> tactics = [];
      if (attributes.containsKey('tactics')) {
        for (var tactic in attributes['tactics']) {
          tactics.add({
            'tactic': tactic['tactic'],
            'techniques': tactic['techniques'] ?? [],
          });
        }
      }

      // Process file operations
      final List<Map<String, dynamic>> fileOps = [];
      if (attributes.containsKey('files_created')) {
        for (var file in attributes['files_created']) {
          fileOps.add({'operation': 'created', 'path': file['path']});
        }
      }

      if (attributes.containsKey('files_deleted')) {
        for (var file in attributes['files_deleted']) {
          fileOps.add({'operation': 'deleted', 'path': file['path']});
        }
      }

      // Process registry operations
      final List<Map<String, dynamic>> registryOps = [];
      if (attributes.containsKey('registry_keys_set')) {
        for (var key in attributes['registry_keys_set']) {
          registryOps.add({
            'operation': 'set',
            'key': key['key'],
            'value': key['value'],
          });
        }
      }

      // Process network operations
      final List<Map<String, dynamic>> networkOps = [];
      if (attributes.containsKey('network_connections')) {
        for (var conn in attributes['network_connections']) {
          networkOps.add({
            'destination': conn['dst_ip'],
            'port': conn['dst_port'],
            'protocol': conn['transport_layer_protocol'],
            'country': conn['country'],
          });
        }
      }

      // Build result
      return {
        'capabilities': capabilities,
        'tactics': tactics,
        'fileOperations': fileOps,
        'registryOperations': registryOps,
        'networkOperations': networkOps,
        'processes': attributes['processes'] ?? [],
        'summary': attributes['summary'] ?? {},
      };
    } catch (e) {
      return {'error': 'Failed to process behavior data: $e'};
    }
  }
}
