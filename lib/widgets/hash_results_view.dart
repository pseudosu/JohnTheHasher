// lib/widgets/hash_results_view.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HashResultsView extends StatelessWidget {
  final Map<String, dynamic> results;

  const HashResultsView({required this.results, super.key});

  @override
  Widget build(BuildContext context) {
    final attributes = results['data']['attributes'];
    final stats = attributes['last_analysis_stats'] ?? {};
    final totalEngines =
        (stats['malicious'] ?? 0) +
        (stats['undetected'] ?? 0) +
        (stats['suspicious'] ?? 0) +
        (stats['harmless'] ?? 0) +
        (stats['timeout'] ?? 0);

    // Calculate detection percentage
    final detectionPercentage =
        totalEngines > 0
            ? ((stats['malicious'] ?? 0) / totalEngines * 100).toStringAsFixed(
              1,
            )
            : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File Information Section
        Row(
          children: [
            const Icon(Icons.description, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                'File: ${attributes['meaningful_name'] ?? 'Unknown'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          'Type: ${attributes['type_description'] ?? attributes['type_tag'] ?? 'Unknown'} (${(attributes['size'] != null ? (attributes['size'] / 1024).toStringAsFixed(2) : "Unknown")} KB)',
          style: const TextStyle(color: Colors.white70),
        ),

        const Divider(color: Colors.white30, height: 24),

        // Detection Summary Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                (stats['malicious'] ?? 0) > 0
                    ? Colors.red.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (stats['malicious'] ?? 0) > 0 ? Colors.red : Colors.green,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    (stats['malicious'] ?? 0) > 0
                        ? Icons.warning
                        : Icons.check_circle,
                    color:
                        (stats['malicious'] ?? 0) > 0
                            ? Colors.red
                            : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'Detection Rate: $detectionPercentage% (${stats['malicious'] ?? 0} engines)',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            (stats['malicious'] ?? 0) > 0
                                ? Colors.red
                                : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              if (attributes.containsKey('popular_threat_classification') &&
                  attributes['popular_threat_classification'] != null &&
                  attributes['popular_threat_classification'].containsKey(
                    'suggested_threat_label',
                  )) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'Threat: ${attributes['popular_threat_classification']['suggested_threat_label']}',
                  style: TextStyle(
                    color:
                        (stats['malicious'] ?? 0) > 0
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Detection Stats
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatIndicator(
                'Malicious',
                stats['malicious'] ?? 0,
                Colors.red,
              ),
              _buildStatIndicator(
                'Suspicious',
                stats['suspicious'] ?? 0,
                Colors.orange,
              ),
              _buildStatIndicator(
                'Clean',
                stats['harmless'] ?? 0,
                Colors.green,
              ),
              _buildStatIndicator(
                'Undetected',
                stats['undetected'] ?? 0,
                Colors.grey,
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white30, height: 24),

        // Dates section
        if (attributes.containsKey('first_submission_date')) ...[
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  'First seen: ${DateTime.fromMillisecondsSinceEpoch(attributes['first_submission_date'] * 1000).toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        if (attributes.containsKey('last_analysis_date')) ...[
          Row(
            children: [
              const Icon(Icons.update, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  'Last analyzed: ${DateTime.fromMillisecondsSinceEpoch(attributes['last_analysis_date'] * 1000).toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],

        // Top detections (AV results)
        if (attributes.containsKey('last_analysis_results')) ...[
          const SizedBox(height: 16),
          const Text(
            'Top Detections:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // Get malicious detections
          ...(() {
            final results = attributes['last_analysis_results'];
            final maliciousDetections = <Widget>[];

            int count = 0;
            results.forEach((engine, result) {
              if (result['category'] == 'malicious' &&
                  result['result'] != null &&
                  count < 5) {
                maliciousDetections.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.security, color: Colors.red, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            '$engine: ${result['result']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                count++;
              }
            });

            return maliciousDetections;
          })(),
        ],

        // Tags
        if (attributes.containsKey('tags') &&
            attributes['tags'].isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Tags:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var tag in attributes['tags'])
                Chip(
                  label: SelectableText(
                    tag,
                    style: const TextStyle(color: Colors.black),
                  ),
                  backgroundColor: Colors.white24,
                ),
            ],
          ),
        ],

        // Additional hashes
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text(
            'Hash Values',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          collapsedIconColor: Colors.white,
          iconColor: Colors.white,
          children: [
            if (attributes.containsKey('md5'))
              _buildHashRow(context, 'MD5', attributes['md5']),
            if (attributes.containsKey('sha1'))
              _buildHashRow(context, 'SHA-1', attributes['sha1']),
            if (attributes.containsKey('sha256'))
              _buildHashRow(context, 'SHA-256', attributes['sha256']),
          ],
        ),
      ],
    );
  }

  Widget _buildHashRow(BuildContext context, String type, String hash) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$type: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              hash,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white60, size: 16),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hash copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: SelectableText(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
