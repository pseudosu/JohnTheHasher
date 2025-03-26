// lib/services/dns_lookup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class DnsLookupService {
  // Primary method that combines multiple sources
  static Future<List<Map<String, dynamic>>> getDomainsForIP(
    String ipAddress,
  ) async {
    List<Map<String, dynamic>> results = [];

    try {
      // First try reverse DNS lookup using a more reliable service
      final reverseDnsResults = await _getReverseDNS(ipAddress);
      if (reverseDnsResults.isNotEmpty) {
        results.addAll(reverseDnsResults);
      }

      // If reverse DNS didn't yield results, try domain history approach
      if (results.isEmpty) {
        final historyResults = await _getDomainHistory(ipAddress);
        if (historyResults.isNotEmpty) {
          results.addAll(historyResults);
        }
      }

      // Finally, try to get currently hosted domains
      final hostedResults = await _getHostedDomains(ipAddress);
      if (hostedResults.isNotEmpty) {
        results.addAll(hostedResults);
      }

      return results;
    } catch (e) {
      print('Error in DNS lookup: $e');
      return [];
    }
  }

  // Method 1: Reliable reverse DNS lookup
  static Future<List<Map<String, dynamic>>> _getReverseDNS(
    String ipAddress,
  ) async {
    try {
      // Using a more reliable service for reverse DNS
      final response = await http.get(
        Uri.parse('https://dns.google/resolve?name=$ipAddress&type=PTR'),
        headers: {'Accept': 'application/dns-json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> records = [];

        if (data.containsKey('Answer') && data['Answer'] is List) {
          for (var record in data['Answer']) {
            records.add({
              'type': 'PTR',
              'value': record['data'],
              'ttl': record['TTL'],
              'date': DateTime.now().toIso8601String(),
              'source': 'Reverse DNS',
            });
          }
        }
        return records;
      }
      return [];
    } catch (e) {
      print('Error in reverse DNS lookup: $e');
      return [];
    }
  }

  // Method 2: Domain history for the IP
  static Future<List<Map<String, dynamic>>> _getDomainHistory(
    String ipAddress,
  ) async {
    try {
      // This is a mock implementation. In reality, you would use a service like SecurityTrails,
      // PassiveTotal, or other threat intelligence APIs to get historical data
      // For demonstration, we'll use a free API that provides some basic info
      final response = await http.get(
        Uri.parse('https://ipinfo.io/$ipAddress/json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> records = [];

        // If hostname is available, add it
        if (data.containsKey('hostname') &&
            data['hostname'] != null &&
            data['hostname'].toString().isNotEmpty) {
          records.add({
            'type': 'A',
            'value': data['hostname'],
            'ttl': 86400, // Default TTL of 1 day
            'date': DateTime.now().toIso8601String(),
            'source': 'ipinfo.io',
          });
        }
        return records;
      }
      return [];
    } catch (e) {
      print('Error in domain history lookup: $e');
      return [];
    }
  }

  // Method 3: Currently hosted domains on the IP
  static Future<List<Map<String, dynamic>>> _getHostedDomains(
    String ipAddress,
  ) async {
    try {
      // For this implementation, we could use HackerTarget's API
      // which offers some free lookups
      final response = await http.get(
        Uri.parse('https://api.hackertarget.com/reverseiplookup/?q=$ipAddress'),
      );

      if (response.statusCode == 200 &&
          !response.body.contains('error') &&
          response.body.trim().isNotEmpty) {
        final domains = response.body.split('\n');
        final List<Map<String, dynamic>> records = [];

        for (var domain in domains) {
          domain = domain.trim();
          if (domain.isNotEmpty) {
            records.add({
              'type': 'A',
              'value': domain,
              'ttl': 86400, // Default TTL of 1 day
              'date': DateTime.now().toIso8601String(),
              'source': 'HackerTarget',
            });
          }
        }
        return records;
      }
      return [];
    } catch (e) {
      print('Error in hosted domains lookup: $e');
      return [];
    }
  }

  // Alternative API fallback if needed
  static Future<List<Map<String, dynamic>>> getDnsRecordsFallback(
    String ipAddress,
  ) async {
    try {
      // Using viewdns.info API (requires API key for production use)
      // This is a placeholder URL - you would need to sign up for their API
      final response = await http.get(
        Uri.parse(
          'https://api.viewdns.info/reversedns/?domain=$ipAddress&apikey=yourapikey&output=json',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> records = [];

        // Parse the response based on viewdns.info's specific format
        // This is a simplified example as the actual structure will depend on their API
        if (data.containsKey('response') &&
            data['response'].containsKey('rdns')) {
          var rdnsData = data['response']['rdns'];
          if (rdnsData is Map && rdnsData.containsKey('name')) {
            records.add({
              'type': 'PTR',
              'value': rdnsData['name'],
              'ttl': 86400, // Default TTL
              'date': DateTime.now().toIso8601String(),
              'source': 'ViewDNS.info',
            });
          }
        }
        return records;
      }
      return [];
    } catch (e) {
      print('Error in DNS records fallback: $e');
      return [];
    }
  }
}
