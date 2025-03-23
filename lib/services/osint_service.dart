// lib/services/osint_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OSINTService {
  // Get Geolocation data with improved error handling and debugging
  static Future<Map<String, dynamic>> getIpGeolocation(String ipAddress) async {
    try {
      // Use ip-api.com as primary source (has higher rate limits)
      print('Making API request to ip-api.com for IP: $ipAddress');
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/$ipAddress'),
      );

      print('ip-api.com response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully decoded geolocation JSON from ip-api.com: $data');

        // Map the response to match our expected format
        return {
          'ip': ipAddress,
          'city': data['city'],
          'region': data['regionName'],
          'country_name': data['country'],
          'country_code': data['countryCode'],
          'latitude': data['lat'],
          'longitude': data['lon'],
          'timezone': data['timezone'],
          'org': data['isp'],
          'postal': data['zip'],
        };
      } else {
        print(
          'Failed to get geolocation data from ip-api.com: ${response.statusCode}',
        );
        // If primary source fails, fall back to the getFallbackGeolocation method
        return getFallbackGeolocation();
      }
    } catch (e) {
      print('Exception during geolocation lookup from ip-api.com: $e');
      return getFallbackGeolocation();
    }
  }

  // Alternative IP geolocation service as backup
  static Future<Map<String, dynamic>> getIpGeolocationAlternative(
    String ipAddress,
  ) async {
    try {
      // Try freegeoip.app as an alternative
      print(
        'Making API request to alternative geolocation service for IP: $ipAddress',
      );
      final response = await http.get(
        Uri.parse('https://ipinfo.io/$ipAddress/json'),
      );

      print('Alternative geolocation response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully decoded alternative geolocation data: $data');

        // Split the loc field which contains "latitude,longitude"
        List<String> coordinates = ['0', '0'];
        if (data.containsKey('loc') && data['loc'] is String) {
          coordinates = data['loc'].split(',');
        }

        // Map the response to match our expected format
        return {
          'ip': data['ip'],
          'city': data['city'],
          'region': data['region'],
          'country_name': data['country'],
          'country_code': data['country'],
          'latitude':
              coordinates.length > 0
                  ? double.tryParse(coordinates[0]) ?? 0.0
                  : 0.0,
          'longitude':
              coordinates.length > 1
                  ? double.tryParse(coordinates[1]) ?? 0.0
                  : 0.0,
          'timezone': data['timezone'],
          'org': data['org'],
          'postal': data['postal'],
        };
      } else {
        print(
          'Failed to get alternative geolocation data: ${response.statusCode}',
        );
        return getFallbackGeolocation();
      }
    } catch (e) {
      print('Exception during alternative geolocation lookup: $e');
      return getFallbackGeolocation();
    }
  }

  // Fallback geolocation data to prevent UI errors
  static Map<String, dynamic> getFallbackGeolocation() {
    return {
      'ip': 'Unknown',
      'city': 'Unknown',
      'region': 'Unknown',
      'country_name': 'Unknown',
      'country_code': 'XX',
      'continent': 'Unknown',
      'latitude': 0.0,
      'longitude': 0.0,
      'timezone': 'Unknown',
      'org': 'Unknown',
      'asn': '0',
    };
  }

  // Check for IP in known blocklists (AbuseIPDB)
  static Future<Map<String, dynamic>> checkAbuseIPDB(String ipAddress) async {
    try {
      final apiKey = dotenv.env['ABUSEIPDB_API_KEY'];
      if (apiKey == null) {
        throw Exception(
          'VirusTotal API key not found. Add it to your .env file.',
        );
      }
      final response = await http.get(
        Uri.parse(
          'https://api.abuseipdb.com/api/v2/check?ipAddress=$ipAddress',
        ),
        headers: {'Key': apiKey, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('AbuseIPDB response successful');
        return jsonDecode(response.body);
      } else {
        print('Failed to check AbuseIPDB: ${response.statusCode}');
        return {
          'error': response.statusCode.toString(),
          'data': {'abuseConfidenceScore': 0},
        };
      }
    } catch (e) {
      print('Exception during AbuseIPDB check: $e');
      return {
        'error': e.toString(),
        'data': {'abuseConfidenceScore': 0},
      };
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
            print('IP identified as Tor exit node');
            return true;
          }
        }
        return false;
      } else {
        print('Failed to check Tor exit nodes: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception during Tor exit node check: $e');
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
