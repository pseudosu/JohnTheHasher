// lib/utils/api_key_checker.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeyChecker {
  static bool hasVirusTotalKey() {
    return dotenv.env['VIRUSTOTAL_API_KEY'] != null &&
        dotenv.env['VIRUSTOTAL_API_KEY']!.isNotEmpty;
  }

  static bool hasAbuseIPDBKey() {
    return dotenv.env['ABUSEIPDB_API_KEY'] != null &&
        dotenv.env['ABUSEIPDB_API_KEY']!.isNotEmpty;
  }

  static void checkApiKeysAndNotify(BuildContext context) {
    final missingKeys = <String>[];

    if (!hasVirusTotalKey()) {
      missingKeys.add('VirusTotal');
    }

    if (!hasAbuseIPDBKey()) {
      missingKeys.add('AbuseIPDB');
    }

    if (missingKeys.isEmpty) {
      return; // All keys are present, no need for notification
    }

    // Show notification dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Missing API Keys'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The following API keys are missing:'),
                SizedBox(height: 8),
                ...missingKeys.map(
                  (key) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text(
                          key,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Some features will have limited functionality until these keys are provided in your .env file.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Dismiss'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showApiKeySetupInstructions(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
                  foregroundColor: Colors.white,
                ),
                child: Text('How to Get API Keys'),
              ),
            ],
          );
        },
      );
    });
  }

  static void _showApiKeySetupInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('API Key Setup Guide'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKeyInstructionSection('VirusTotal API Key', [
                  '1. Go to virustotal.com and create an account',
                  '2. Navigate to your profile settings',
                  '3. Select API Key section',
                  '4. Copy your API key',
                  '5. Add it to your .env file as VIRUSTOTAL_API_KEY=your_key_here',
                ]),
                Divider(height: 24),
                _buildKeyInstructionSection('AbuseIPDB API Key', [
                  '1. Go to abuseipdb.com and create an account',
                  '2. Navigate to the API section',
                  '3. Create a new API key',
                  '4. Copy your API key',
                  '5. Add it to your .env file as ABUSEIPDB_API_KEY=your_key_here',
                ]),
                Divider(height: 24),
                Text(
                  'Note: After adding the keys, restart the app for changes to take effect.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildKeyInstructionSection(String title, List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        ...steps.map(
          (step) => Padding(
            padding: EdgeInsets.only(bottom: 4, left: 8),
            child: Text(step),
          ),
        ),
      ],
    );
  }
}
