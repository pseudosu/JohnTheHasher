import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HashDetailScreen extends StatelessWidget {
  final Map<String, dynamic> hashData;

  const HashDetailScreen({required this.hashData, super.key});

  @override
  Widget build(BuildContext context) {
    final isMalicious = hashData['detection_count'] > 0;
    final fullResults = jsonDecode(hashData['full_results']);
    final attributes = fullResults['data']['attributes'];

    // Parse JSON fields
    final tagsList =
        hashData['tags'] != null
            ? List<String>.from(jsonDecode(hashData['tags']))
            : <String>[];

    final avLabels =
        hashData['av_labels'] != null
            ? List<String>.from(jsonDecode(hashData['av_labels']))
            : <String>[];

    final signatures =
        hashData['signatures'] != null
            ? jsonDecode(hashData['signatures']) as Map<String, dynamic>
            : <String, dynamic>{};

    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'Hash Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        elevation: 4,
        actions: [
          // Share button
          IconButton(
            onPressed: () => _shareHashReport(context),
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Hash Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Information card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(45, 95, 155, 1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'File Information',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                hashData['filename'] ?? 'Unknown file',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // File details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'File Type',
                          hashData['file_type'] ?? 'Unknown',
                        ),
                        _buildDetailRow(
                          'File Size',
                          hashData['file_size'] != null
                              ? '${(hashData['file_size'] / 1024).toStringAsFixed(2)} KB'
                              : 'Unknown',
                        ),
                        _buildDetailRow(
                          'File Hash (SHA-256)',
                          hashData['hash'],
                        ),

                        if (attributes.containsKey('md5'))
                          _buildDetailRow('MD5', attributes['md5']),

                        if (attributes.containsKey('sha1'))
                          _buildDetailRow('SHA-1', attributes['sha1']),

                        const Divider(height: 24),

                        _buildDetailRow(
                          'First Seen',
                          hashData['first_seen'] != null
                              ? DateTime.parse(
                                hashData['first_seen'],
                              ).toString().substring(0, 16)
                              : 'Unknown',
                        ),

                        _buildDetailRow(
                          'Last Seen',
                          hashData['last_seen'] != null
                              ? DateTime.parse(
                                hashData['last_seen'],
                              ).toString().substring(0, 16)
                              : 'Unknown',
                        ),

                        _buildDetailRow(
                          'Scan Date',
                          hashData['timestamp'] != null
                              ? DateTime.parse(
                                hashData['timestamp'],
                              ).toString().substring(0, 16)
                              : 'Unknown',
                        ),

                        if (hashData['popularity'] != null)
                          _buildDetailRow(
                            'Submission Count',
                            hashData['popularity'].toString(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Detection results card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMalicious ? Colors.red : Colors.green,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isMalicious ? Icons.warning : Icons.check_circle,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detection Results',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                isMalicious
                                    ? 'Malicious: ${hashData['detection_ratio'] ?? '0/0'}'
                                    : 'Clean: ${hashData['detection_ratio'] ?? '0/0'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detection stats
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              'Malicious',
                              attributes['last_analysis_stats']['malicious'],
                              Colors.red,
                            ),
                            _buildStatColumn(
                              'Suspicious',
                              attributes['last_analysis_stats']['suspicious'],
                              Colors.orange,
                            ),
                            _buildStatColumn(
                              'Clean',
                              attributes['last_analysis_stats']['harmless'],
                              Colors.green,
                            ),
                            _buildStatColumn(
                              'Undetected',
                              attributes['last_analysis_stats']['undetected'],
                              Colors.grey,
                            ),
                          ],
                        ),

                        if (hashData['threat_category'] != null &&
                            hashData['threat_category'] != '') ...[
                          const Divider(height: 32),
                          _buildDetailRow(
                            'Threat Category',
                            hashData['threat_category'],
                          ),
                        ],

                        const Divider(height: 32),

                        if (avLabels.isNotEmpty) ...[
                          const Text(
                            'Detection Names:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...avLabels.map(
                            (label) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.security,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tags
            if (tagsList.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tags',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            tagsList
                                .map(
                                  (tag) => Chip(
                                    label: Text(tag),
                                    backgroundColor: const Color.fromRGBO(
                                      25,
                                      55,
                                      109,
                                      0.1,
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Color.fromRGBO(25, 55, 109, 1),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Signature Information
            if (signatures.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signature Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...signatures.entries.map(
                        (entry) => _buildDetailRow(
                          entry.key
                              .split('_')
                              .map(
                                (word) =>
                                    word.substring(0, 1).toUpperCase() +
                                    word.substring(1),
                              )
                              .join(' '),
                          entry.value.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(25, 55, 109, 1),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  // In lib/screens/hash_detail_screen.dart

  // Add this method to the HashDetailScreen class
  void _shareHashReport(BuildContext context) {
    // Create a comprehensive summary report
    final StringBuffer report = StringBuffer();

    // Report header
    report.writeln('===== HASH ANALYSIS REPORT =====');
    report.writeln('');

    // File information
    report.writeln('FILE INFORMATION:');
    report.writeln('Filename: ${hashData['filename'] ?? 'Unknown'}');
    report.writeln('File Type: ${hashData['file_type'] ?? 'Unknown'}');
    if (hashData['file_size'] != null) {
      report.writeln(
        'Size: ${(hashData['file_size'] / 1024).toStringAsFixed(2)} KB',
      );
    }

    // Hash values
    report.writeln('');
    report.writeln('HASH VALUES:');
    report.writeln('SHA-256: ${hashData['hash']}');

    final fullResults = jsonDecode(hashData['full_results']);
    final attributes = fullResults['data']['attributes'];

    if (attributes.containsKey('md5')) {
      report.writeln('MD5: ${attributes['md5']}');
    }
    if (attributes.containsKey('sha1')) {
      report.writeln('SHA-1: ${attributes['sha1']}');
    }

    // Detection information
    report.writeln('');
    report.writeln('SCAN RESULTS:');
    final stats = attributes['last_analysis_stats'];
    final totalEngines =
        stats['malicious'] +
        stats['undetected'] +
        stats['suspicious'] +
        stats['harmless'] +
        stats['timeout'];

    report.writeln(
      'Detection Rate: ${stats['malicious']} of $totalEngines engines',
    );
    report.writeln(
      'Scan Status: ${stats['malicious'] > 0 ? "MALICIOUS" : "CLEAN"}',
    );

    if (hashData['threat_level'] != null) {
      report.writeln('Threat Level: ${hashData['threat_level']}');
    }

    if (hashData['threat_category'] != null &&
        hashData['threat_category'] != '') {
      report.writeln('Threat Category: ${hashData['threat_category']}');
    }

    // Timestamps
    report.writeln('');
    report.writeln('TIMELINE:');
    if (hashData['first_seen'] != null) {
      report.writeln(
        'First Seen: ${DateTime.parse(hashData['first_seen']).toString().substring(0, 16)}',
      );
    }
    if (hashData['last_seen'] != null) {
      report.writeln(
        'Last Analyzed: ${DateTime.parse(hashData['last_seen']).toString().substring(0, 16)}',
      );
    }
    report.writeln(
      'Scan Date: ${DateTime.parse(hashData['timestamp']).toString().substring(0, 16)}',
    );

    // Top detections
    final avLabels =
        hashData['av_labels'] != null
            ? List<String>.from(jsonDecode(hashData['av_labels']))
            : <String>[];

    if (avLabels.isNotEmpty) {
      report.writeln('');
      report.writeln('TOP DETECTION NAMES:');
      for (var label in avLabels.take(5)) {
        report.writeln('- $label');
      }
    }

    // Tags
    final tagsList =
        hashData['tags'] != null
            ? List<String>.from(jsonDecode(hashData['tags']))
            : <String>[];

    if (tagsList.isNotEmpty) {
      report.writeln('');
      report.writeln('TAGS:');
      report.writeln(tagsList.join(', '));
    }

    // Report footer
    report.writeln('');
    report.writeln('Report generated by John the Hasher');
    report.writeln(
      'Report date: ${DateTime.now().toString().substring(0, 16)}',
    );

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: report.toString()));

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hash report copied to clipboard'),
        backgroundColor: Color.fromRGBO(25, 55, 109, 1),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
