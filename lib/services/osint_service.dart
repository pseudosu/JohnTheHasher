// lib/services/osint_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class OSINTService {
  // Get Geolocation data
  static Future<Map<String, dynamic>> getIpGeolocation(String ipAddress) async {
    try {
      final response = await http.get(
        Uri.parse('https://ipapi.co/$ipAddress/json/'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to get geolocation data: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Check for IP in known blocklists (AbuseIPDB)
  static Future<Map<String, dynamic>> checkAbuseIPDB(String ipAddress) async {
    try {
      //Note: AbuseIPDB in progress
      final apiKey = 'placeholder';
      final response = await http.get(
        Uri.parse(
          'https://api.abuseipdb.com/api/v2/check?ipAddress=$ipAddress',
        ),
        headers: {'Key': apiKey, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to check AbuseIPDB: ${response.statusCode}');
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Check if IP is in Tor exit node list
  static Future<bool> checkTorExitNode(String ipAddress) async {
    try {
      final response = await http.get(
        Uri.parse('https://check.torproject.org/exit-addresses'),
      );

      if (response.statusCode == 200) {
        final exitNodes = response.body.split('\n');
        for (var line in exitNodes) {
          if (line.contains('ExitAddress') && line.contains(ipAddress)) {
            return true;
          }
        }
        return false;
      } else {
        throw Exception(
          'Failed to check Tor exit nodes: ${response.statusCode}',
        );
      }
    } catch (e) {
      return false;
    }
  }

  // Parse and extract WHOIS information
  static Map<String, String> parseWhoisData(String rawWhois) {
    final Map<String, String> result = {};

    // Common WHOIS fields to extract
    final fieldsToExtract = {
      'Registrar': RegExp(r'Registrar:\s*(.*?)(?:\n|$)'),
      'Organization': RegExp(r'Registrant Organization:\s*(.*?)(?:\n|$)'),
      'Country': RegExp(r'Registrant Country:\s*(.*?)(?:\n|$)'),
      'Creation Date': RegExp(r'Creation Date:\s*(.*?)(?:\n|$)'),
      'Updated Date': RegExp(r'Updated Date:\s*(.*?)(?:\n|$)'),
      'Expiration Date': RegExp(r'Registry Expiry Date:\s*(.*?)(?:\n|$)'),
      'Name Servers': RegExp(r'Name Server:\s*(.*?)(?:\n|$)'),
      'CIDR': RegExp(r'CIDR:\s*(.*?)(?:\n|$)'),
      'NetRange': RegExp(r'NetRange:\s*(.*?)(?:\n|$)'),
      'NetName': RegExp(r'NetName:\s*(.*?)(?:\n|$)'),
    };

    for (var field in fieldsToExtract.entries) {
      final match = field.value.firstMatch(rawWhois);
      if (match != null && match.groupCount > 0) {
        result[field.key] = match.group(1)!.trim();
      }
    }

    // Extract all name servers
    final nameServerMatches = RegExp(
      r'Name Server:\s*(.*?)(?:\n|$)',
    ).allMatches(rawWhois);
    if (nameServerMatches.isNotEmpty) {
      final nameServers =
          nameServerMatches
              .map((match) => match.group(1)?.trim() ?? '')
              .where((server) => server.isNotEmpty)
              .toList();
      result['Name Servers'] = nameServers.join(', ');
    }

    return result;
  }
}
