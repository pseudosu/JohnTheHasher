import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirusTotalService {
  static Future<Map<String, dynamic>> checkHash(String hash) async {
    final apiKey = dotenv.env['VIRUSTOTAL_API_KEY'];
    if (apiKey == null) {
      throw Exception(
        'VirusTotal API key not found. Add it to your .env file.',
      );
    }

    final url = Uri.parse('https://www.virustotal.com/api/v3/files/$hash');

    final response = await http.get(
      url,
      headers: {'x-apikey': apiKey, 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('Hash not found in VirusTotal database');
    } else {
      throw Exception('Failed to check hash: ${response.statusCode}');
    }
  }

  // Method to get additional behavioral data if needed
  static Future<Map<String, dynamic>> getBehaviorData(String hash) async {
    final apiKey = dotenv.env['VIRUSTOTAL_API_KEY'];
    if (apiKey == null) {
      throw Exception(
        'VirusTotal API key not found. Add it to your .env file.',
      );
    }

    final url = Uri.parse(
      'https://www.virustotal.com/api/v3/files/$hash/behaviours',
    );

    final response = await http.get(
      url,
      headers: {'x-apikey': apiKey, 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('Behavior data not available for this file');
    } else {
      throw Exception('Failed to get behavior data: ${response.statusCode}');
    }
  }

  // Method to get file details
  static Map<String, dynamic> extractFileDetails(
    Map<String, dynamic> vtResponse,
  ) {
    final attributes = vtResponse['data']['attributes'];
    final stats = attributes['last_analysis_stats'];

    // Calculate detection percentage
    int total =
        stats['malicious'] +
        stats['undetected'] +
        stats['harmless'] +
        stats['suspicious'] +
        stats['timeout'];
    double detectionPercentage =
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
      'threatCategory':
          attributes.containsKey('popular_threat_classification')
              ? attributes['popular_threat_classification']['suggested_threat_label']
              : 'Unknown',
    };
  }
}
