// lib/services/virus_total_ip_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirusTotalIpService {
  static Future<Map<String, dynamic>> checkIp(String ipAddress) async {
    final apiKey = dotenv.env['VIRUSTOTAL_API_KEY'];
    if (apiKey == null) {
      throw Exception(
        'VirusTotal API key not found. Add it to your .env file.',
      );
    }

    final url = Uri.parse(
      'https://www.virustotal.com/api/v3/ip_addresses/$ipAddress',
    );

    final response = await http.get(
      url,
      headers: {'x-apikey': apiKey, 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception('IP address not found in VirusTotal database');
    } else {
      throw Exception('Failed to check IP address: ${response.statusCode}');
    }
  }

  // Method to get WHOIS data if needed
  static Future<Map<String, dynamic>> getWhoisData(String ipAddress) async {
    final apiKey = dotenv.env['VIRUSTOTAL_API_KEY'];
    if (apiKey == null) {
      throw Exception(
        'VirusTotal API key not found. Add it to your .env file.',
      );
    }

    final url = Uri.parse(
      'https://www.virustotal.com/api/v3/ip_addresses/$ipAddress/resolutions',
    );

    final response = await http.get(
      url,
      headers: {'x-apikey': apiKey, 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get WHOIS data: ${response.statusCode}');
    }
  }

  // Extract IP details from VirusTotal response
  static Map<String, dynamic> extractIpDetails(
    Map<String, dynamic> vtResponse, {
    Map<String, dynamic>? whoisData,
  }) {
    final attributes = vtResponse['data']['attributes'];
    final stats = attributes['last_analysis_stats'];

    // Get the IP address from the response ID
    final ipAddress = vtResponse['data']['id'] ?? 'Unknown';

    // Calculate detection percentage
    int total =
        stats['malicious'] +
        stats['undetected'] +
        stats['harmless'] +
        stats['suspicious'] +
        stats['timeout'];
    double detectionPercentage =
        total > 0 ? (stats['malicious'] / total) * 100 : 0;

    // Extract top 5 security vendor detections
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

    // Extract hostname resolutions if available
    List<Map<String, dynamic>> resolutions = [];
    if (attributes.containsKey('last_https_certificate')) {
      final cert = attributes['last_https_certificate'];
      if (cert.containsKey('extensions') &&
          cert['extensions'].containsKey('subject_alternative_name')) {
        final altNames = cert['extensions']['subject_alternative_name'];
        if (altNames is List) {
          for (var name in altNames) {
            resolutions.add({
              'hostname': name,
              'date':
                  cert.containsKey('last_seen_date')
                      ? DateTime.fromMillisecondsSinceEpoch(
                        cert['last_seen_date'] * 1000,
                      )
                      : null,
            });
          }
        }
      }
    }

    // Extract domain resolutions from WHOIS data if provided
    if (whoisData != null &&
        whoisData.containsKey('data') &&
        whoisData['data'] is List &&
        whoisData['data'].isNotEmpty) {
      for (var resolution in whoisData['data']) {
        if (resolution.containsKey('attributes') &&
            resolution['attributes'].containsKey('host_name')) {
          resolutions.add({
            'hostname': resolution['attributes']['host_name'],
            'date':
                resolution['attributes'].containsKey('date')
                    ? DateTime.fromMillisecondsSinceEpoch(
                      resolution['attributes']['date'] * 1000,
                    )
                    : null,
          });
        }
      }
    }

    // WHOIS registrar info
    Map<String, dynamic> whoisInfo = {};
    if (attributes.containsKey('whois')) {
      final whois = attributes['whois'] as String;
      // Extract key WHOIS info with basic parsing
      final regDateMatch = RegExp(
        r'Registration Date: (.*?)\n',
      ).firstMatch(whois);
      final regOrgMatch = RegExp(r'Registrar: (.*?)\n').firstMatch(whois);
      final adminContactMatch = RegExp(
        r'Admin Email: (.*?)\n',
      ).firstMatch(whois);

      whoisInfo = {
        'rawData': whois,
        'registrationDate': regDateMatch?.group(1)?.trim(),
        'registrar': regOrgMatch?.group(1)?.trim(),
        'adminContact': adminContactMatch?.group(1)?.trim(),
      };
    }

    return {
      'ip': attributes['network'] ?? ipAddress,
      'asOwner': attributes['as_owner'] ?? 'Unknown',
      'asn': attributes['asn'] ?? 0,
      'country': attributes['country'] ?? 'Unknown',
      'continent': attributes['continent'] ?? 'Unknown',
      'detectionStats': stats,
      'detectionPercentage': detectionPercentage.toStringAsFixed(1),
      'lastAnalysisDate':
          attributes.containsKey('last_analysis_date')
              ? DateTime.fromMillisecondsSinceEpoch(
                attributes['last_analysis_date'] * 1000,
              )
              : null,
      'reputation': attributes['reputation'] ?? 0,
      'tags': attributes['tags'] ?? [],
      'topDetections': topDetections,
      'regionalInternetRegistry':
          attributes['regional_internet_registry'] ?? 'Unknown',
      'network': attributes['network'] ?? 'Unknown',
      'whoisInfo': whoisInfo,
      'resolutions': resolutions,
      'totalResolutions': resolutions.length,
    };
  }
}
