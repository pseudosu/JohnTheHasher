// lib/services/virus_total_ip_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:myapp/services/osint_service.dart';

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
    List<Map<String, dynamic>>? dnsRecords,
  }) {
    final attributes = vtResponse['data']['attributes'];
    final stats = attributes['last_analysis_stats'] ?? {};

    // Calculate detection percentage
    int total =
        (stats['malicious'] ?? 0) +
        (stats['undetected'] ?? 0) +
        (stats['harmless'] ?? 0) +
        (stats['suspicious'] ?? 0) +
        (stats['timeout'] ?? 0);
    double detectionPercentage =
        total > 0 ? (stats['malicious'] ?? 0) / total * 100 : 0;

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

    // Use the provided DNS records if available, otherwise extract from VT response
    List<Map<String, dynamic>> resolutions = dnsRecords ?? [];

    // If no external DNS records provided, try to extract from VT response
    if (resolutions.isEmpty && attributes.containsKey('last_dns_records')) {
      try {
        for (var record in attributes['last_dns_records']) {
          resolutions.add({
            'type': record['type'] ?? 'Unknown',
            'value': record['value'] ?? 'Unknown',
            'ttl': record['ttl'] ?? 0,
            'date':
                attributes.containsKey('last_dns_records_date')
                    ? DateTime.fromMillisecondsSinceEpoch(
                      attributes['last_dns_records_date'] * 1000,
                    )
                    : DateTime.now(),
          });
        }
      } catch (e) {
        print('Error extracting DNS records from VT response: $e');
      }
    }

    // WHOIS registrar info
    Map<String, dynamic> whoisInfo = {};
    if (attributes.containsKey('whois')) {
      final whois = attributes['whois'] as String;
      // Extract key WHOIS info with basic parsing
      whoisInfo = OSINTService.parseWhoisData(whois);
    }

    return {
      'ip': attributes['network'] ?? vtResponse['data']['id'],
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
