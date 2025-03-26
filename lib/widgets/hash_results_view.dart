// lib/widgets/hash_results_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class HashResultsView extends StatefulWidget {
  final Map<String, dynamic> results;
  final Map<String, dynamic>? behaviorData;

  const HashResultsView({required this.results, this.behaviorData, super.key});

  @override
  State<HashResultsView> createState() => _HashResultsViewState();
}

class _HashResultsViewState extends State<HashResultsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasExpandedBehavior = false;

  @override
  void initState() {
    super.initState();
    // Add fourth tab only if behavior data is available
    _tabController = TabController(
      length: widget.behaviorData != null ? 4 : 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attributes = widget.results['data']['attributes'];
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
        // File header information
        _buildFileHeader(attributes, detectionPercentage, stats),

        const SizedBox(height: 16),

        // Tabs
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Detections'),
            const Tab(text: 'Technical'),
            if (widget.behaviorData != null) const Tab(text: 'Behavior'),
          ],
        ),

        const SizedBox(height: 16),

        // Tab content
        SizedBox(
          height: 380, // Fixed height for tab content
          child: TabBarView(
            controller: _tabController,
            children: [
              // Overview Tab
              _buildOverviewTab(attributes, stats, detectionPercentage),

              // Detections Tab
              _buildDetectionsTab(attributes, stats),

              // Technical Tab
              _buildTechnicalTab(attributes),

              // Behavior Tab (conditional)
              if (widget.behaviorData != null)
                _buildBehaviorTab(widget.behaviorData!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileHeader(
    Map<String, dynamic> attributes,
    String detectionPercentage,
    Map<String, dynamic> stats,
  ) {
    final isMalicious = (stats['malicious'] ?? 0) > 0;
    // Calculate totalEngines inside this method to fix the reference
    final totalEngines =
        (stats['malicious'] ?? 0) +
        (stats['undetected'] ?? 0) +
        (stats['suspicious'] ?? 0) +
        (stats['harmless'] ?? 0) +
        (stats['timeout'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File info row
        Row(
          children: [
            // File icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileTypeIcon(attributes['type_description'] ?? ''),
                color: Colors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // File name and type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    attributes['meaningful_name'] ?? 'Unknown File',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${attributes['type_description'] ?? 'Unknown'} • ${(attributes['size'] != null ? _formatFileSize(attributes['size']) : "Unknown")}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Detection summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isMalicious
                    ? Colors.red.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMalicious ? Colors.red : Colors.green,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Circular progress indicator for detection rate
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: double.parse(detectionPercentage) / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMalicious ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            detectionPercentage,
                            style: TextStyle(
                              color: isMalicious ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            '%',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Detection text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isMalicious ? Icons.warning : Icons.check_circle,
                          color: isMalicious ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMalicious ? 'Malicious' : 'Clean',
                          style: TextStyle(
                            color: isMalicious ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats['malicious'] ?? 0} of $totalEngines engines',
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (attributes.containsKey(
                          'popular_threat_classification',
                        ) &&
                        attributes['popular_threat_classification'] != null &&
                        attributes['popular_threat_classification'].containsKey(
                          'suggested_threat_label',
                        ))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Threat: ${attributes['popular_threat_classification']['suggested_threat_label']}',
                          style: TextStyle(
                            color:
                                isMalicious ? Colors.red[200] : Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(
    Map<String, dynamic> attributes,
    Map<String, dynamic> stats,
    String detectionPercentage,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detection stats chart
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildDetectionChart(stats),
          ),

          const SizedBox(height: 16),

          // Dates section
          const Text(
            'Timeline',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // First seen
          if (attributes.containsKey('first_submission_date'))
            _buildInfoRow(
              'First Seen',
              DateTime.fromMillisecondsSinceEpoch(
                attributes['first_submission_date'] * 1000,
              ).toString().substring(0, 16),
              Icons.calendar_today,
            ),

          // Last analyzed
          if (attributes.containsKey('last_analysis_date'))
            _buildInfoRow(
              'Last Analyzed',
              DateTime.fromMillisecondsSinceEpoch(
                attributes['last_analysis_date'] * 1000,
              ).toString().substring(0, 16),
              Icons.update,
            ),

          const SizedBox(height: 16),

          // Tags
          if (attributes.containsKey('tags') && attributes['tags'].isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tags',
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
                        label: Text(tag),
                        backgroundColor: Colors.white24,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetectionsTab(
    Map<String, dynamic> attributes,
    Map<String, dynamic> stats,
  ) {
    // Get malicious detections
    final List<Map<String, dynamic>> detections = [];

    if (attributes.containsKey('last_analysis_results')) {
      final results = attributes['last_analysis_results'];
      results.forEach((engine, result) {
        detections.add({
          'engine': engine,
          'category': result['category'],
          'result': result['result'],
          'method': result['method'] ?? 'unknown',
        });
      });

      // Sort detections by category and then engine name
      detections.sort((a, b) {
        // Malicious first, then suspicious, then the rest
        final aVal =
            a['category'] == 'malicious'
                ? 0
                : a['category'] == 'suspicious'
                ? 1
                : 2;
        final bVal =
            b['category'] == 'malicious'
                ? 0
                : b['category'] == 'suspicious'
                ? 1
                : 2;

        if (aVal != bVal) return aVal.compareTo(bVal);
        return a['engine'].compareTo(b['engine']);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detection summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                'Malicious',
                stats['malicious'] ?? 0,
                Colors.red,
              ),
              _buildStatColumn(
                'Suspicious',
                stats['suspicious'] ?? 0,
                Colors.orange,
              ),
              _buildStatColumn('Clean', stats['harmless'] ?? 0, Colors.green),
              _buildStatColumn(
                'Undetected',
                stats['undetected'] ?? 0,
                Colors.grey,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Detections list header
        Row(
          children: [
            const Text(
              'Engine Detections',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${detections.length} engines',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Scrollable detections list
        Expanded(
          child:
              detections.isEmpty
                  ? const Center(
                    child: Text(
                      'No detection data available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                  : ListView.builder(
                    itemCount: detections.length,
                    itemBuilder: (context, index) {
                      final detection = detections[index];
                      final isPositive =
                          detection['category'] == 'malicious' ||
                          detection['category'] == 'suspicious';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getCategoryColor(
                              detection['category'],
                            ).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                detection['category'],
                              ).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCategoryIcon(detection['category']),
                              color: _getCategoryColor(detection['category']),
                              size: 16,
                            ),
                          ),
                          title: Text(
                            detection['engine'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle:
                              isPositive && detection['result'] != null
                                  ? Text(
                                    detection['result'],
                                    style: TextStyle(
                                      color: _getCategoryColor(
                                        detection['category'],
                                      ).withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  )
                                  : null,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                detection['category'],
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getCategoryLabel(detection['category']),
                              style: TextStyle(
                                color: _getCategoryColor(detection['category']),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTechnicalTab(Map<String, dynamic> attributes) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File details section
          const Text(
            'File Details',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          if (attributes.containsKey('meaningful_name'))
            _buildDetailRow('File Name', attributes['meaningful_name']),

          if (attributes.containsKey('type_description'))
            _buildDetailRow('File Type', attributes['type_description']),

          if (attributes.containsKey('size'))
            _buildDetailRow('File Size', _formatFileSize(attributes['size'])),

          const Divider(color: Colors.white30, height: 24),

          // Hash values section
          const Text(
            'Hash Values',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          if (attributes.containsKey('md5'))
            _buildHashRow('MD5', attributes['md5']),

          if (attributes.containsKey('sha1'))
            _buildHashRow('SHA-1', attributes['sha1']),

          if (attributes.containsKey('sha256'))
            _buildHashRow('SHA-256', attributes['sha256']),

          const Divider(color: Colors.white30, height: 24),

          // Signature information if available
          if (attributes.containsKey('signature_info') &&
              attributes['signature_info'] is Map &&
              attributes['signature_info'].isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signature Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...attributes['signature_info'].entries.map(
                  (entry) => _buildDetailRow(
                    _formatSignatureKey(entry.key),
                    entry.value.toString(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBehaviorTab(Map<String, dynamic> behaviorData) {
    // Extract behavior summary
    List<Map<String, dynamic>> behaviors = [];
    List<String> processes = [];
    List<String> files = [];
    List<String> registry = [];
    List<String> network = [];

    if (behaviorData.containsKey('data') && behaviorData['data'] is List) {
      try {
        final dataList = behaviorData['data'] as List;
        if (dataList.isNotEmpty && dataList[0].containsKey('attributes')) {
          final attributes = dataList[0]['attributes'];

          // Extract processes
          if (attributes.containsKey('processes') &&
              attributes['processes'] is List) {
            for (var process in attributes['processes']) {
              if (process.containsKey('name')) {
                processes.add(process['name']);
              }
            }
          }

          // Extract file operations
          if (attributes.containsKey('summary') &&
              attributes['summary'].containsKey('files')) {
            files = List<String>.from(attributes['summary']['files'] as List);
          }

          // Extract registry operations
          if (attributes.containsKey('summary') &&
              attributes['summary'].containsKey('keys')) {
            registry = List<String>.from(attributes['summary']['keys'] as List);
          }

          // Extract network connections
          if (attributes.containsKey('network_connections') &&
              attributes['network_connections'] is List) {
            for (var conn in attributes['network_connections']) {
              if (conn.containsKey('dst_ip') && conn.containsKey('dst_port')) {
                network.add('${conn['dst_ip']}:${conn['dst_port']}');
              }
            }
          }

          // Extract behavior summary
          if (attributes.containsKey('tactics') &&
              attributes['tactics'] is List) {
            for (var tactic in attributes['tactics']) {
              behaviors.add({
                'tactic': tactic['tactic'],
                'techniques': tactic['techniques'],
              });
            }
          }
        }
      } catch (e) {
        print('Error parsing behavior data: $e');
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Behavior summary
          if (behaviors.isNotEmpty) ...[
            const Text(
              'Tactics & Techniques',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...behaviors.map(
              (behavior) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      behavior['tactic'] ?? 'Unknown Tactic',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (behavior['techniques'] is List)
                      ...List<String>.from(behavior['techniques']).map(
                        (technique) => Padding(
                          padding: const EdgeInsets.only(top: 4, left: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(color: Colors.red),
                              ),
                              Expanded(
                                child: Text(
                                  technique,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No behavior tactics identified',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Activity sections with ExpansionTiles
          if (processes.isNotEmpty)
            _buildExpandableList(
              'Processes Created',
              processes,
              Icons.memory,
              Colors.blue,
            ),

          if (files.isNotEmpty)
            _buildExpandableList(
              'File Operations',
              files,
              Icons.insert_drive_file,
              Colors.orange,
            ),

          if (registry.isNotEmpty)
            _buildExpandableList(
              'Registry Operations',
              registry,
              Icons.settings,
              Colors.green,
            ),

          if (network.isNotEmpty)
            _buildExpandableList(
              'Network Connections',
              network,
              Icons.wifi,
              Colors.purple,
            ),

          if (processes.isEmpty &&
              files.isEmpty &&
              registry.isEmpty &&
              network.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No detailed behavior data available',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods
  Widget _buildDetectionChart(Map<String, dynamic> stats) {
    final pieChartSections = <PieChartSectionData>[];

    // Add sections for each category with count > 0
    if ((stats['malicious'] ?? 0) > 0) {
      pieChartSections.add(
        PieChartSectionData(
          color: Colors.red,
          value: (stats['malicious'] ?? 0).toDouble(),
          title: 'Malicious',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          radius: 90,
        ),
      );
    }

    if ((stats['suspicious'] ?? 0) > 0) {
      pieChartSections.add(
        PieChartSectionData(
          color: Colors.orange,
          value: (stats['suspicious'] ?? 0).toDouble(),
          title: 'Suspicious',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          radius: 85,
        ),
      );
    }

    if ((stats['harmless'] ?? 0) > 0) {
      pieChartSections.add(
        PieChartSectionData(
          color: Colors.green,
          value: (stats['harmless'] ?? 0).toDouble(),
          title: 'Clean',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          radius: 80,
        ),
      );
    }

    if ((stats['undetected'] ?? 0) > 0) {
      pieChartSections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: (stats['undetected'] ?? 0).toDouble(),
          title: 'Undetected',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          radius: 75,
        ),
      );
    }

    return pieChartSections.isEmpty
        ? const Center(
          child: Text(
            'No detection data available',
            style: TextStyle(color: Colors.white70),
          ),
        )
        : PieChart(
          PieChartData(
            sections: pieChartSections,
            centerSpaceRadius: 0,
            sectionsSpace: 2,
            startDegreeOffset: -90,
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
        Text(label, style: TextStyle(color: color.withOpacity(0.9))),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
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
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String type, String hash) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              type,
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

  Widget _buildExpandableList(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              items.length.toString(),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      collapsedIconColor: Colors.white70,
      iconColor: Colors.white,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.min(20, items.length), // Limit to 20 items
          itemBuilder: (context, index) {
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(icon, color: color.withOpacity(0.7), size: 16),
              title: Text(
                items[index],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              minLeadingWidth: 20,
            );
          },
        ),
        if (items.length > 20)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'And ${items.length - 20} more...',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Utility methods
  IconData _getFileTypeIcon(String fileType) {
    fileType = fileType.toLowerCase();

    if (fileType.contains('executable')) return Icons.apps;
    if (fileType.contains('document')) return Icons.description;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('zip') || fileType.contains('archive'))
      return Icons.folder_zip;
    if (fileType.contains('image')) return Icons.image;
    if (fileType.contains('script')) return Icons.code;
    if (fileType.contains('text')) return Icons.text_snippet;

    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'malicious':
        return Colors.red;
      case 'suspicious':
        return Colors.orange;
      case 'harmless':
        return Colors.green;
      case 'undetected':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'malicious':
        return Icons.warning;
      case 'suspicious':
        return Icons.help_outline;
      case 'harmless':
        return Icons.check_circle;
      case 'undetected':
        return Icons.remove_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'malicious':
        return 'Malicious';
      case 'suspicious':
        return 'Suspicious';
      case 'harmless':
        return 'Clean';
      case 'undetected':
        return 'Undetected';
      default:
        return 'Unknown';
    }
  }

  String _formatSignatureKey(String key) {
    return key
        .split('_')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
  }
}
