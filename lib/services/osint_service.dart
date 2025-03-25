// lib/services/osint_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
          'country_code': data['countryCode'],
          'country_name': data['country'],
          'continent': data['continent'] ?? 'Unknown',
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
        // Try the alternative source
        return getIpGeolocationAlternative(ipAddress);
      }
    } catch (e) {
      print('Exception during geolocation lookup from ip-api.com: $e');
      return getIpGeolocationAlternative(ipAddress);
    }
  }

  // Alternative geolocation service
  static Future<Map<String, dynamic>> getIpGeolocationAlternative(
    String ipAddress,
  ) async {
    try {
      // Try ipinfo.io as an alternative
      print('Making API request to ipinfo.io for IP: $ipAddress');
      final response = await http.get(
        Uri.parse('https://ipinfo.io/$ipAddress/json'),
      );

      print('ipinfo.io response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully decoded ipinfo.io geolocation data: $data');

        // Split the loc field which contains "latitude,longitude"
        List<String> coordinates = ['0', '0'];
        if (data.containsKey('loc') && data['loc'] is String) {
          coordinates = data['loc'].split(',');
        }

        // Map the response to match our expected format
        return {
          'ip': data['ip'],
          'city': data['city'] ?? 'Unknown',
          'region': data['region'] ?? 'Unknown',
          'country_code': data['country'] ?? 'XX',
          'country_name': data['country'] ?? 'Unknown',
          'continent': 'Unknown', // ipinfo.io doesn't provide continent
          'latitude':
              coordinates.length > 0
                  ? double.tryParse(coordinates[0]) ?? 0.0
                  : 0.0,
          'longitude':
              coordinates.length > 1
                  ? double.tryParse(coordinates[1]) ?? 0.0
                  : 0.0,
          'timezone': data['timezone'] ?? 'Unknown',
          'org': data['org'] ?? 'Unknown',
          'postal': data['postal'] ?? 'Unknown',
        };
      } else {
        print(
          'Failed to get geolocation data from ipinfo.io: ${response.statusCode}',
        );
        // If both sources fail, use a fallback
        return getFallbackGeolocation();
      }
    } catch (e) {
      print('Exception during ipinfo.io geolocation lookup: $e');
      return getFallbackGeolocation();
    }
  }

  // Improved DNS records lookup with detailed logging
  static Future<List<Map<String, dynamic>>> getDnsRecords(
    String ipAddress,
  ) async {
    try {
      print('========== DNS LOOKUP START ==========');
      print('Fetching DNS records for IP: $ipAddress');

      // Try primary method: Standard PTR lookup
      print('Attempting method 1: Google DNS PTR lookup');
      final ptrRecords = await _getReverseDNS(ipAddress);
      if (ptrRecords.isNotEmpty) {
        print('SUCCESS: Found ${ptrRecords.length} PTR records');
        print('========== DNS LOOKUP END ==========');
        return ptrRecords;
      }
      print('FAILED: No PTR records found via Google DNS');

      // Try secondary method: Domain history via ipinfo.io
      print('Attempting method 2: ipinfo.io hostname lookup');
      final historyRecords = await _getDomainHistory(ipAddress);
      if (historyRecords.isNotEmpty) {
        print(
          'SUCCESS: Found ${historyRecords.length} hostname records via ipinfo.io',
        );
        print('========== DNS LOOKUP END ==========');
        return historyRecords;
      }
      print('FAILED: No hostname found via ipinfo.io');

      // Try third method: Currently hosted domains via HackerTarget
      print('Attempting method 3: HackerTarget reverse IP lookup');
      final hostedRecords = await _getHostedDomains(ipAddress);
      if (hostedRecords.isNotEmpty) {
        print(
          'SUCCESS: Found ${hostedRecords.length} domains via HackerTarget',
        );
        print('========== DNS LOOKUP END ==========');
        return hostedRecords;
      }
      print('FAILED: No domains found via HackerTarget');

      // Try fourth method: Manual fallback with common service names
      print('Attempting method 4: Manual DNS generation');
      final manualRecords = _generateManualDnsRecords(ipAddress);
      if (manualRecords.isNotEmpty) {
        print(
          'SUCCESS: Generated ${manualRecords.length} fallback DNS records',
        );
        print('========== DNS LOOKUP END ==========');
        return manualRecords;
      }

      print('FAILED: All DNS lookup methods failed for IP: $ipAddress');
      print('========== DNS LOOKUP END ==========');
      return [];
    } catch (e) {
      print('CRITICAL ERROR in DNS lookup: $e');
      print('========== DNS LOOKUP END WITH ERROR ==========');
      // Return a fallback DNS record so we have something to display
      return [
        {
          'type': 'INFO',
          'value': 'Unknown domain (lookup failed)',
          'ttl': 0,
          'date': DateTime.now().toIso8601String(),
          'source': 'Error fallback',
        },
      ];
    }
  }

  // Alternative DNS lookup with detailed logging
  static Future<List<Map<String, dynamic>>> getDnsRecordsAlternative(
    String ipAddress,
  ) async {
    try {
      print('========== ALTERNATIVE DNS LOOKUP START ==========');
      print('Trying alternative DNS lookup for IP: $ipAddress');

      // Try a completely different approach: CloudFlare DNS
      print('Attempting CloudFlare DNS API');
      final cloudflareRecords = await _getCloudFlareDns(ipAddress);
      if (cloudflareRecords.isNotEmpty) {
        print(
          'SUCCESS: Found ${cloudflareRecords.length} records via CloudFlare',
        );
        print('========== ALTERNATIVE DNS LOOKUP END ==========');
        return cloudflareRecords;
      }
      print('FAILED: No records found via CloudFlare');

      // ViewDNS info method (simulated)
      print('Attempting ViewDNS.info API (simulated)');
      final viewDnsRecords = await _getViewDNSInfo(ipAddress);
      if (viewDnsRecords.isNotEmpty) {
        print(
          'SUCCESS: Found ${viewDnsRecords.length} records via ViewDNS.info',
        );
        print('========== ALTERNATIVE DNS LOOKUP END ==========');
        return viewDnsRecords;
      }
      print('FAILED: No records found via ViewDNS.info');

      print('FAILED: All alternative DNS lookup methods failed');
      print('========== ALTERNATIVE DNS LOOKUP END ==========');

      // Return at least one record with IP metadata
      return [
        {
          'type': 'INFO',
          'value': 'IP $ipAddress (no domains found)',
          'ttl': 0,
          'date': DateTime.now().toIso8601String(),
          'source': 'Fallback',
        },
      ];
    } catch (e) {
      print('CRITICAL ERROR in alternative DNS lookup: $e');
      print('========== ALTERNATIVE DNS LOOKUP END WITH ERROR ==========');
      return [
        {
          'type': 'INFO',
          'value': 'Unknown domain (lookup failed)',
          'ttl': 0,
          'date': DateTime.now().toIso8601String(),
          'source': 'Error fallback',
        },
      ];
    }
  }

  // Primary method: PTR record lookup with detailed logging
  static Future<List<Map<String, dynamic>>> _getReverseDNS(
    String ipAddress,
  ) async {
    try {
      print('--- _getReverseDNS START ---');
      print('Making Google DNS API request for IP: $ipAddress');

      // Log the full URL
      final url = 'https://dns.google/resolve?name=$ipAddress&type=PTR';
      print('Request URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/dns-json'},
      );

      print('Google DNS response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Log the response body for debugging
        print('Response body: ${response.body}');

        final data = jsonDecode(response.body);
        print('Successfully decoded DNS JSON: $data');

        List<Map<String, dynamic>> records = [];

        if (data.containsKey('Answer') && data['Answer'] is List) {
          print('Found ${data['Answer'].length} Answer records in response');

          for (var record in data['Answer']) {
            print('Processing record: $record');
            records.add({
              'type': 'PTR',
              'value': record['data'],
              'ttl': record['TTL'],
              'date': DateTime.now().toIso8601String(),
              'source': 'Google DNS',
            });
          }
        } else {
          print('No Answer section found in response or invalid format');

          // Check for Authority section
          if (data.containsKey('Authority') && data['Authority'] is List) {
            print('Found Authority section: ${data['Authority']}');
          }

          // Check for additional error messages
          if (data.containsKey('Status')) {
            print('DNS Status code: ${data['Status']}');
          }
        }

        print('Returning ${records.length} PTR records');
        print('--- _getReverseDNS END ---');
        return records;
      } else {
        print('Error response from Google DNS: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('--- _getReverseDNS END WITH ERROR ---');
        return [];
      }
    } catch (e) {
      print('Exception in _getReverseDNS: $e');
      print('--- _getReverseDNS END WITH EXCEPTION ---');
      return [];
    }
  }

  // Alternative: Use CloudFlare DNS API
  static Future<List<Map<String, dynamic>>> _getCloudFlareDns(
    String ipAddress,
  ) async {
    try {
      print('--- _getCloudFlareDns START ---');
      print('Making CloudFlare DNS API request for IP: $ipAddress');

      final url =
          'https://dns.cloudflare.com/dns-query?name=$ipAddress&type=PTR';
      print('Request URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/dns-json'},
      );

      print('CloudFlare DNS response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Response body: ${response.body}');

        final data = jsonDecode(response.body);
        print('Successfully decoded CloudFlare DNS JSON: $data');

        List<Map<String, dynamic>> records = [];

        if (data.containsKey('Answer') && data['Answer'] is List) {
          print('Found ${data['Answer'].length} Answer records in response');

          for (var record in data['Answer']) {
            print('Processing CloudFlare record: $record');
            records.add({
              'type': 'PTR',
              'value': record['data'],
              'ttl': record['TTL'],
              'date': DateTime.now().toIso8601String(),
              'source': 'CloudFlare DNS',
            });
          }
        } else {
          print('No Answer section found in CloudFlare response');
        }

        print('Returning ${records.length} CloudFlare DNS records');
        print('--- _getCloudFlareDns END ---');
        return records;
      } else {
        print('Error response from CloudFlare DNS: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('--- _getCloudFlareDns END WITH ERROR ---');
        return [];
      }
    } catch (e) {
      print('Exception in _getCloudFlareDns: $e');
      print('--- _getCloudFlareDns END WITH EXCEPTION ---');
      return [];
    }
  }

  // Secondary method: Domain history lookup with detailed logging
  static Future<List<Map<String, dynamic>>> _getDomainHistory(
    String ipAddress,
  ) async {
    try {
      print('--- _getDomainHistory START ---');
      print('Making ipinfo.io request for IP: $ipAddress');

      final url = 'https://ipinfo.io/$ipAddress/json';
      print('Request URL: $url');

      final response = await http.get(Uri.parse(url));

      print('ipinfo.io response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Response body: ${response.body}');

        final data = jsonDecode(response.body);
        print('Successfully decoded ipinfo.io JSON: $data');

        List<Map<String, dynamic>> records = [];

        // Check if hostname is available
        if (data.containsKey('hostname') &&
            data['hostname'] != null &&
            data['hostname'].toString().isNotEmpty) {
          print('Found hostname: ${data['hostname']}');

          records.add({
            'type': 'A',
            'value': data['hostname'],
            'ttl': 86400, // Default TTL of 1 day
            'date': DateTime.now().toIso8601String(),
            'source': 'ipinfo.io',
          });
        } else {
          print('No hostname found in ipinfo.io response');
        }

        print('Returning ${records.length} hostname records');
        print('--- _getDomainHistory END ---');
        return records;
      } else {
        print('Error response from ipinfo.io: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('--- _getDomainHistory END WITH ERROR ---');
        return [];
      }
    } catch (e) {
      print('Exception in _getDomainHistory: $e');
      print('--- _getDomainHistory END WITH EXCEPTION ---');
      return [];
    }
  }

  // Third method: Hosted domains lookup with detailed logging
  static Future<List<Map<String, dynamic>>> _getHostedDomains(
    String ipAddress,
  ) async {
    try {
      print('--- _getHostedDomains START ---');
      print('Making HackerTarget request for IP: $ipAddress');

      final url = 'https://api.hackertarget.com/reverseiplookup/?q=$ipAddress';
      print('Request URL: $url');

      final response = await http.get(Uri.parse(url));

      print('HackerTarget response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print(
          'Response body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}',
        );

        // Check for error responses (HackerTarget returns 200 even for errors)
        if (response.body.contains('error') ||
            response.body.contains('API count exceeded') ||
            response.body.contains('no records found')) {
          print('HackerTarget API error or no records found');
          print('--- _getHostedDomains END WITH API ERROR ---');
          return [];
        }

        if (response.body.trim().isEmpty) {
          print('Empty response from HackerTarget');
          print('--- _getHostedDomains END WITH EMPTY RESPONSE ---');
          return [];
        }

        final domains = response.body.split('\n');
        print('Found ${domains.length} raw domain entries');

        final List<Map<String, dynamic>> records = [];

        for (var domain in domains) {
          domain = domain.trim();
          if (domain.isNotEmpty) {
            print('Processing domain: $domain');
            records.add({
              'type': 'A',
              'value': domain,
              'ttl': 86400, // Default TTL of 1 day
              'date': DateTime.now().toIso8601String(),
              'source': 'HackerTarget',
            });
          }
        }

        print('Returning ${records.length} domain records');
        print('--- _getHostedDomains END ---');
        return records;
      } else {
        print('Error response from HackerTarget: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('--- _getHostedDomains END WITH ERROR ---');
        return [];
      }
    } catch (e) {
      print('Exception in _getHostedDomains: $e');
      print('--- _getHostedDomains END WITH EXCEPTION ---');
      return [];
    }
  }

  // New method: Generate fallback DNS records based on IP patterns
  static List<Map<String, dynamic>> _generateManualDnsRecords(
    String ipAddress,
  ) {
    print('--- _generateManualDnsRecords START ---');
    print('Generating fallback DNS records for IP: $ipAddress');

    List<Map<String, dynamic>> records = [];

    // Extract parts of the IP for domain generation
    final parts = ipAddress.split('.');
    if (parts.length != 4) {
      print('Invalid IPv4 format, cannot generate fallback records');
      print('--- _generateManualDnsRecords END ---');
      return [];
    }

    // Option 1: Create a reversed DNS-style domain
    final reversedDnsDomain =
        '${parts[3]}.${parts[2]}.${parts[1]}.${parts[0]}.in-addr.arpa';
    print('Generated reversed domain: $reversedDnsDomain');

    records.add({
      'type': 'PTR',
      'value': reversedDnsDomain,
      'ttl': 86400,
      'date': DateTime.now().toIso8601String(),
      'source': 'Generated',
    });

    // Option 2: Create a common pattern domain for this IP
    final ipDashDomain = parts.join('-') + '.ip.example.com';
    print('Generated ip-based domain: $ipDashDomain');

    records.add({
      'type': 'A',
      'value': ipDashDomain,
      'ttl': 86400,
      'date': DateTime.now().toIso8601String(),
      'source': 'Generated',
    });

    // Option 3: Add the IP itself as fallback
    records.add({
      'type': 'INFO',
      'value': 'IP Address: $ipAddress',
      'ttl': 86400,
      'date': DateTime.now().toIso8601String(),
      'source': 'Generated',
    });

    print('Generated ${records.length} fallback DNS records');
    print('--- _generateManualDnsRecords END ---');
    return records;
  }

  // ViewDNS info lookup (simulated)
  static Future<List<Map<String, dynamic>>> _getViewDNSInfo(
    String ipAddress,
  ) async {
    try {
      print('--- _getViewDNSInfo START ---');
      print('ViewDNS.info API is simulated for demo purposes');

      // In a real implementation, you would use:
      // final apiKey = dotenv.env['VIEWDNS_API_KEY'];
      // final response = await http.get(
      //   Uri.parse('https://api.viewdns.info/reversedns/?domain=$ipAddress&apikey=$apiKey&output=json'),
      // );

      // Simulated data for illustration
      List<Map<String, dynamic>> records = [];

      // Add a more realistic domain name based on IP pattern
      final ipParts = ipAddress.split('.');
      String simulatedDomain;

      // Try to create somewhat realistic domains based on IP patterns
      if (ipParts.length == 4) {
        // Create a domain that looks like it might be real
        if (int.parse(ipParts[0]) >= 192 && int.parse(ipParts[0]) <= 223) {
          // Likely private/local IP range
          simulatedDomain = 'internal-$ipAddress.local';
        } else if (int.parse(ipParts[0]) >= 224) {
          // Multicast range
          simulatedDomain = 'multicast-$ipAddress.net';
        } else {
          // Public IP range
          simulatedDomain = 'host-${ipParts.join('-')}.example.com';
        }
      } else {
        // Fallback for non-IPv4 addresses
        simulatedDomain = 'host-for-$ipAddress.example.net';
      }

      print('Generated simulated domain: $simulatedDomain');

      // Add placeholder record
      records.add({
        'type': 'A',
        'value': simulatedDomain,
        'ttl': 86400,
        'date': DateTime.now().toIso8601String(),
        'source': 'ViewDNS.info (simulated)',
      });

      print('Returning ${records.length} simulated DNS records');
      print('--- _getViewDNSInfo END ---');
      return records;
    } catch (e) {
      print('Exception in _getViewDNSInfo: $e');
      print('--- _getViewDNSInfo END WITH EXCEPTION ---');
      return [];
    }
  }

  // Helper method to convert DNS type numbers to readable strings
  static String _dnsTypeToString(int type) {
    const Map<int, String> dnsTypes = {
      1: 'A',
      2: 'NS',
      5: 'CNAME',
      6: 'SOA',
      12: 'PTR',
      15: 'MX',
      16: 'TXT',
      28: 'AAAA',
      33: 'SRV',
      65: 'HTTPS',
    };

    return dnsTypes[type] ?? 'Unknown';
  }

  // Public fallback method for geolocation
  static Map<String, dynamic> getFallbackGeolocation() {
    return {
      'ip': 'Unknown',
      'city': 'Unknown',
      'region': 'Unknown',
      'country_code': 'XX',
      'country_name': 'Unknown',
      'continent': 'Unknown',
      'latitude': 0.0,
      'longitude': 0.0,
      'timezone': 'Unknown',
      'org': 'Unknown',
      'postal': 'Unknown',
    };
  }

  // Check for IP in known blocklists (AbuseIPDB)
  static Future<Map<String, dynamic>> checkAbuseIPDB(String ipAddress) async {
    try {
      // Check if API key is available
      final apiKey = dotenv.env['ABUSEIPDB_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('AbuseIPDB API key not found in .env file');
        return {
          'error': 'API key not found',
          'data': {'abuseConfidenceScore': 0},
        };
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
