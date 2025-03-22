import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirusTotalService {
  static Future<Map<String, dynamic>> checkHash(String hash) async {
    try {
      final apiKey = dotenv.env['VIRUSTOTAL_API_KEY'];
      print("API Key available: ${apiKey != null}"); // Debug print

      if (apiKey == null) {
        throw Exception(
          'VirusTotal API key not found. Add it to your .env file.',
        );
      }

      final url = Uri.parse('https://www.virustotal.com/api/v3/files/$hash');
      print("Requesting URL: $url"); // Debug print

      final response = await http.get(
        url,
        headers: {'x-apikey': apiKey, 'Accept': 'application/json'},
      );

      print("Response status code: ${response.statusCode}"); // Debug print
      print("Response body: ${response.body}"); // Debug print

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception(
          'Access forbidden. Check your API key and rate limits (4 requests/min for free accounts)',
        );
      } else if (response.statusCode == 404) {
        throw Exception('Hash not found in VirusTotal database');
      } else {
        throw Exception(
          'Failed to check hash: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Exception in checkHash: $e");
      rethrow;
    }
  }
}
