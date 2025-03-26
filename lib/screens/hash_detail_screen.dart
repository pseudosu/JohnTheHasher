// lib/screens/hash_detail_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

class HashDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hashData;

  const HashDetailScreen({required this.hashData, super.key});

  @override
  State<HashDetailScreen> createState() => _HashDetailScreenState();
}

class _HashDetailScreenState extends State<HashDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;
  final List<String> _exportOptions = ['PDF', 'CSV', 'JSON'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMalicious = widget.hashData['detection_count'] > 0;
    final fullResults = jsonDecode(widget.hashData['full_results']);
    final attributes = fullResults['data']['attributes'];

    // Parse JSON fields
    final tags =
        widget.hashData['tags'] != null
            ? List<String>.from(jsonDecode(widget.hashData['tags']))
            : <String>[];

    final avLabels =
        widget.hashData['av_labels'] != null
            ? List<String>.from(jsonDecode(widget.hashData['av_labels']))
            : <String>[];

    final signatures =
        widget.hashData['signatures'] != null
            ? jsonDecode(widget.hashData['signatures']) as Map<String, dynamic>
            : <String, dynamic>{};

    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Hash Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Detections'),
            Tab(text: 'Technical'),
            Tab(text: 'Behavior'),
          ],
        ),
        actions: [
          // Export action button with dropdown menu
          PopupMenuButton<String>(
            icon:
                _isExporting
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.download, color: Colors.white),
            tooltip: 'Export Report',
            onSelected: (format) => _exportData(format),
            itemBuilder:
                (context) =>
                    _exportOptions
                        .map(
                          (option) => PopupMenuItem<String>(
                            value: option,
                            child: Row(
                              children: [
                                Icon(
                                  _getFormatIcon(option),
                                  color: const Color.fromRGBO(25, 55, 109, 1),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text('Export as $option'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
          ),

          // Share button
          IconButton(
            onPressed: () => _shareHashReport(),
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Hash Report',
          ),

          // Open in VirusTotal button
          IconButton(
            onPressed: () => _openInVT(),
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            tooltip: 'Open in VirusTotal',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          _buildOverviewTab(isMalicious, attributes, tags),

          // Detections Tab
          _buildDetectionsTab(attributes, avLabels),

          // Technical Tab
          _buildTechnicalTab(attributes, signatures),

          // Behavior Tab
          _buildBehaviorTab(attributes),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    bool isMalicious,
    Map<String, dynamic> attributes,
    List<String> tags,
  ) {
    final stats = attributes['last_analysis_stats'];
    final totalEngines =
        stats['malicious'] +
        stats['undetected'] +
        stats['harmless'] +
        stats['suspicious'] +
        stats['timeout'];
    final detectionPercentage =
        totalEngines > 0
            ? (stats['malicious'] / totalEngines * 100).toStringAsFixed(1)
            : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isMalicious ? Icons.warning : Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMalicious ? 'Malicious File' : 'Clean File',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            if (widget.hashData['threat_category'] != null &&
                                widget.hashData['threat_category'] != 'Unknown')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  widget.hashData['threat_category'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Detection chart
                Container(
                  padding: const EdgeInsets.all(16),
                  height: 200,
                  child: Row(
                    children: [
                      // Circular percentage indicator
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: double.parse(detectionPercentage) / 100,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isMalicious ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  detectionPercentage,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isMalicious ? Colors.red : Colors.green,
                                  ),
                                ),
                                const Text('%', style: TextStyle(fontSize: 14)),
                                Text(
                                  'Detection Rate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Stats bar chart
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _getMaxCount(stats),
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    String text = '';
                                    switch (value.toInt()) {
                                      case 0:
                                        text = 'Mal';
                                        break;
                                      case 1:
                                        text = 'Sus';
                                        break;
                                      case 2:
                                        text = 'Clean';
                                        break;
                                      case 3:
                                        text = 'Und';
                                        break;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        text,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              _createBarGroup(
                                0,
                                stats['malicious'],
                                Colors.red,
                              ),
                              _createBarGroup(
                                1,
                                stats['suspicious'],
                                Colors.orange,
                              ),
                              _createBarGroup(
                                2,
                                stats['harmless'],
                                Colors.green,
                              ),
                              _createBarGroup(
                                3,
                                stats['undetected'],
                                Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats['malicious'] > 0
                            ? 'Detected by ${stats['malicious']} of $totalEngines engines'
                            : 'No detections from $totalEngines engines',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isMalicious ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatBox(
                            'Malicious',
                            stats['malicious'],
                            Colors.red,
                          ),
                          _buildStatBox(
                            'Suspicious',
                            stats['suspicious'],
                            Colors.orange,
                          ),
                          _buildStatBox(
                            'Clean',
                            stats['harmless'],
                            Colors.green,
                          ),
                          _buildStatBox(
                            'Undetected',
                            stats['undetected'],
                            Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // File Information Card
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
                              widget.hashData['filename'] ?? 'Unknown file',
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
                        widget.hashData['file_type'] ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'File Size',
                        widget.hashData['file_size'] != null
                            ? _formatFileSize(widget.hashData['file_size'])
                            : 'Unknown',
                      ),
                      _buildDetailRow(
                        'File Hash (SHA-256)',
                        widget.hashData['hash'],
                      ),

                      if (attributes.containsKey('md5'))
                        _buildDetailRow('MD5', attributes['md5']),

                      if (attributes.containsKey('sha1'))
                        _buildDetailRow('SHA-1', attributes['sha1']),

                      const Divider(height: 24),

                      _buildDetailRow(
                        'First Seen',
                        widget.hashData['first_seen'] != null
                            ? _formatDate(widget.hashData['first_seen'])
                            : 'Unknown',
                      ),

                      _buildDetailRow(
                        'Last Seen',
                        widget.hashData['last_seen'] != null
                            ? _formatDate(widget.hashData['last_seen'])
                            : 'Unknown',
                      ),

                      _buildDetailRow(
                        'Scan Date',
                        widget.hashData['timestamp'] != null
                            ? _formatDate(widget.hashData['timestamp'])
                            : 'Unknown',
                      ),

                      if (widget.hashData['popularity'] != null)
                        _buildDetailRow(
                          'Submission Count',
                          widget.hashData['popularity'].toString(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tags Card
          if (tags.isNotEmpty)
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
                          tags
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
        ],
      ),
    );
  }

  Widget _buildDetectionsTab(
    Map<String, dynamic> attributes,
    List<String> avLabels,
  ) {
    final Map<String, dynamic> results =
        attributes['last_analysis_results'] ?? {};
    final List<Map<String, dynamic>> detections = [];

    // Build detections list
    results.forEach((engine, result) {
      detections.add({
        'engine': engine,
        'category': result['category'],
        'result': result['result'],
        'method': result['method'] ?? 'Unknown',
      });
    });

    // Sort by category (malicious first)
    detections.sort((a, b) {
      final priorityA = _getCategoryPriority(a['category']);
      final priorityB = _getCategoryPriority(b['category']);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      return a['engine'].compareTo(b['engine']);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Malicious findings card
          if (avLabels.isNotEmpty)
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
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'Malware Detections',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${avLabels.length}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...avLabels.map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.security,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
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
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // All engines card
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
                  Row(
                    children: [
                      const Icon(Icons.security),
                      const SizedBox(width: 8),
                      const Text(
                        'Security Engines',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${detections.length}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category filter chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('All', null),
                      _buildFilterChip('Malicious', 'malicious'),
                      _buildFilterChip('Suspicious', 'suspicious'),
                      _buildFilterChip('Clean', 'harmless'),
                      _buildFilterChip('Undetected', 'undetected'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Detections list
                  ...detections.map((detection) {
                    final category = detection['category'];
                    final isPositive =
                        category == 'malicious' || category == 'suspicious';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getCategoryColor(category).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  color: _getCategoryColor(category),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    detection['engine'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(
                                      category,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getCategoryName(category),
                                    style: TextStyle(
                                      color: _getCategoryColor(category),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isPositive && detection['result'] != null) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 26),
                                child: Text(
                                  'Detection: ${detection['result']}',
                                  style: TextStyle(
                                    color: _getCategoryColor(
                                      category,
                                    ).withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                            if (detection['method'] != 'Unknown') ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 26),
                                child: Text(
                                  'Method: ${detection['method']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalTab(
    Map<String, dynamic> attributes,
    Map<String, dynamic> signatures,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Technical details card
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
                    'Technical Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // File type information
                  if (attributes['type_description'] != null ||
                      attributes['type_tag'] != null) ...[
                    const Text(
                      'File Type Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(25, 55, 109, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (attributes['type_description'] != null)
                      _buildDetailRow(
                        'Type Description',
                        attributes['type_description'],
                      ),
                    if (attributes['type_tag'] != null)
                      _buildDetailRow('Type Tag', attributes['type_tag']),
                    if (attributes['exiftool'] != null &&
                        attributes['exiftool'].containsKey('FileType'))
                      _buildDetailRow(
                        'ExifTool Type',
                        attributes['exiftool']['FileType'],
                      ),
                    if (attributes['magic'] != null)
                      _buildDetailRow('Magic', attributes['magic']),

                    const Divider(height: 24),
                  ],

                  // File hashes
                  const Text(
                    'File Hashes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(25, 55, 109, 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCopyableHashRow('MD5', attributes['md5'] ?? 'N/A'),
                  _buildCopyableHashRow('SHA-1', attributes['sha1'] ?? 'N/A'),
                  _buildCopyableHashRow(
                    'SHA-256',
                    attributes['sha256'] ?? 'N/A',
                  ),
                  if (attributes.containsKey('sha512'))
                    _buildCopyableHashRow('SHA-512', attributes['sha512']),
                  if (attributes.containsKey('ssdeep'))
                    _buildCopyableHashRow('SSDEEP', attributes['ssdeep']),
                  if (attributes.containsKey('authentihash'))
                    _buildCopyableHashRow(
                      'Authentihash',
                      attributes['authentihash'],
                    ),
                  if (attributes.containsKey('imphash'))
                    _buildCopyableHashRow('ImpHash', attributes['imphash']),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Signature Information Card
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

          const SizedBox(height: 16),

          // PE Details Card for executables
          if (attributes.containsKey('pe_info') &&
              attributes['pe_info'] is Map) ...[
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
                      'PE Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Entry point
                    if (attributes['pe_info'].containsKey('entry_point'))
                      _buildDetailRow(
                        'Entry Point',
                        '0x${attributes['pe_info']['entry_point'].toRadixString(16).toUpperCase()}',
                      ),

                    // Timestamp
                    if (attributes['pe_info'].containsKey('timestamp'))
                      _buildDetailRow(
                        'Compilation Timestamp',
                        DateTime.fromMillisecondsSinceEpoch(
                          attributes['pe_info']['timestamp'] * 1000,
                        ).toString(),
                      ),

                    // Sections information
                    if (attributes['pe_info'].containsKey('sections') &&
                        attributes['pe_info']['sections'] is List) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Sections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(25, 55, 109, 1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(45, 95, 155, 0.1),
                            ),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Name',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Size',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Entropy',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'MD5',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          ...List<TableRow>.generate(
                            attributes['pe_info']['sections'].length,
                            (index) {
                              final section =
                                  attributes['pe_info']['sections'][index];
                              return TableRow(
                                decoration: BoxDecoration(
                                  color:
                                      index % 2 == 0
                                          ? Colors.white
                                          : Colors.grey.withOpacity(0.05),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(section['name'] ?? 'Unknown'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      _formatFileSize(section['size'] ?? 0),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      section.containsKey('entropy')
                                          ? section['entropy'].toStringAsFixed(
                                            2,
                                          )
                                          : 'N/A',
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      section['md5'] ?? 'N/A',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBehaviorTab(Map<String, dynamic> attributes) {
    // Check if behavior data is available
    final hasBehavior =
        attributes.containsKey('sandbox_verdicts') &&
        attributes['sandbox_verdicts'] is Map &&
        attributes['sandbox_verdicts'].isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child:
          !hasBehavior
              ? Center(
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Behavior analysis not available',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No behavioral data is available for this file.',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Check on VirusTotal'),
                          onPressed: () => _openInVT(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(
                              25,
                              55,
                              109,
                              1,
                            ),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sandbox verdicts card
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
                            'Sandbox Analysis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          ...attributes['sandbox_verdicts'].entries.map((
                            entry,
                          ) {
                            final sandboxName = entry.key;
                            final verdict = entry.value;
                            final malicious =
                                verdict['category'] == 'malicious';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    malicious
                                        ? Colors.red.withOpacity(0.05)
                                        : Colors.green.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      malicious
                                          ? Colors.red.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        malicious
                                            ? Icons.warning
                                            : Icons.check_circle,
                                        color:
                                            malicious
                                                ? Colors.red
                                                : Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          sandboxName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              malicious
                                                  ? Colors.red.withOpacity(0.1)
                                                  : Colors.green.withOpacity(
                                                    0.1,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          verdict['category'] ?? 'unknown',
                                          style: TextStyle(
                                            color:
                                                malicious
                                                    ? Colors.red
                                                    : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (verdict.containsKey('confidence')) ...[
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: verdict['confidence'] / 100,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        malicious ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Confidence: ${verdict['confidence']}%',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  if (verdict.containsKey(
                                    'malware_classification',
                                  )) ...[
                                    const SizedBox(height: 8),
                                    ...verdict['malware_classification'].entries
                                        .map((classEntry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              left: 32,
                                              bottom: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${classEntry.key}: ${classEntry.value}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // More behavior cards would go here - showing placeholder
                  const SizedBox(height: 16),

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
                          Row(
                            children: [
                              const Icon(Icons.info_outline),
                              const SizedBox(width: 8),
                              const Text(
                                'Additional Behavior',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.open_in_browser,
                                  size: 16,
                                ),
                                label: const Text('See Full Report'),
                                onPressed: () => _openInVT(),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color.fromRGBO(
                                    25,
                                    55,
                                    109,
                                    1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'For detailed behavior analysis including process, file, registry, and network activities, please view the full report on VirusTotal.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  // Helper methods
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

  Widget _buildCopyableHashRow(String type, String hash) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$type:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(25, 55, 109, 1),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              hash,
              style: const TextStyle(
                color: Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (hash != 'N/A')
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$type copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? category) {
    return FilterChip(
      label: Text(label),
      onSelected: (selected) {
        // Filter functionality would be implemented here
      },
      backgroundColor: Colors.grey.withOpacity(0.1),
      selectedColor: const Color.fromRGBO(25, 55, 109, 0.2),
      checkmarkColor: const Color.fromRGBO(25, 55, 109, 1),
      labelStyle: const TextStyle(color: Color.fromRGBO(25, 55, 109, 1)),
    );
  }

  BarChartGroupData _createBarGroup(int x, int y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y.toDouble(),
          color: color,
          width: 15,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  // Export functionality
  Future<void> _exportData(String format) async {
    setState(() {
      _isExporting = true;
    });

    try {
      switch (format) {
        case 'PDF':
          await _exportAsPdf();
          break;
        case 'CSV':
          await _exportAsCsv();
          break;
        case 'JSON':
          await _exportAsJson();
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _exportAsPdf() async {
    // PDF implementation would go here
    // Using a library like pdf or flutter_pdfview

    // Simulate PDF generation delay
    await Future.delayed(const Duration(seconds: 1));

    // Show success message
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export is not implemented in this version'),
        backgroundColor: Color.fromRGBO(25, 55, 109, 1),
      ),
    );
  }

  Future<void> _exportAsCsv() async {
    try {
      final csvData = [
        ['Field', 'Value'], // Header row
        ['File Name', widget.hashData['filename'] ?? 'Unknown'],
        ['File Type', widget.hashData['file_type'] ?? 'Unknown'],
        [
          'File Size',
          widget.hashData['file_size'] != null
              ? _formatFileSize(widget.hashData['file_size'])
              : 'Unknown',
        ],
        ['SHA-256', widget.hashData['hash']],
        [
          'MD5',
          jsonDecode(
                widget.hashData['full_results'],
              )['data']['attributes']['md5'] ??
              'Unknown',
        ],
        [
          'SHA-1',
          jsonDecode(
                widget.hashData['full_results'],
              )['data']['attributes']['sha1'] ??
              'Unknown',
        ],
        [
          'First Seen',
          widget.hashData['first_seen'] != null
              ? _formatDate(widget.hashData['first_seen'])
              : 'Unknown',
        ],
        [
          'Last Seen',
          widget.hashData['last_seen'] != null
              ? _formatDate(widget.hashData['last_seen'])
              : 'Unknown',
        ],
        [
          'Scan Date',
          widget.hashData['timestamp'] != null
              ? _formatDate(widget.hashData['timestamp'])
              : 'Unknown',
        ],
        ['Detection Count', '${widget.hashData['detection_count']}'],
        ['Detection Ratio', widget.hashData['detection_ratio'] ?? '0/0'],
        ['Threat Category', widget.hashData['threat_category'] ?? 'Unknown'],
      ];

      // Add AV detection results
      if (widget.hashData['av_labels'] != null) {
        final avLabels = List<String>.from(
          jsonDecode(widget.hashData['av_labels']),
        );
        csvData.add(['', '']); // Empty row for separation
        csvData.add(['Detection Results', '']);

        for (var label in avLabels) {
          final parts = label.split(': ');
          if (parts.length == 2) {
            csvData.add([parts[0], parts[1]]);
          } else {
            csvData.add(['AV Result', label]);
          }
        }
      }

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'hash_report_${widget.hashData['hash'].substring(0, 8)}.csv';
      final file = File('${tempDir.path}/$fileName');

      // Write to file
      await file.writeAsString(csvString);

      // Share the file
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Hash Analysis Report');

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV file exported successfully'),
          backgroundColor: Color.fromRGBO(25, 55, 109, 1),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsJson() async {
    try {
      // Create a clean JSON object with the important data
      final exportData = {
        'file_info': {
          'filename': widget.hashData['filename'],
          'file_type': widget.hashData['file_type'],
          'file_size': widget.hashData['file_size'],
        },
        'hashes': {
          'sha256': widget.hashData['hash'],
          'md5':
              jsonDecode(
                widget.hashData['full_results'],
              )['data']['attributes']['md5'],
          'sha1':
              jsonDecode(
                widget.hashData['full_results'],
              )['data']['attributes']['sha1'],
        },
        'analysis': {
          'detection_count': widget.hashData['detection_count'],
          'detection_ratio': widget.hashData['detection_ratio'],
          'threat_category': widget.hashData['threat_category'],
          'first_seen': widget.hashData['first_seen'],
          'last_seen': widget.hashData['last_seen'],
          'scan_date': widget.hashData['timestamp'],
        },
        'detections':
            widget.hashData['av_labels'] != null
                ? jsonDecode(widget.hashData['av_labels'])
                : [],
        'tags':
            widget.hashData['tags'] != null
                ? jsonDecode(widget.hashData['tags'])
                : [],
      };

      // Convert to JSON string with pretty printing
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'hash_report_${widget.hashData['hash'].substring(0, 8)}.json';
      final file = File('${tempDir.path}/$fileName');

      // Write to file
      await file.writeAsString(jsonString);

      // Share the file
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Hash Analysis Report');

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON file exported successfully'),
          backgroundColor: Color.fromRGBO(25, 55, 109, 1),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export JSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareHashReport() {
    // Create a comprehensive summary report
    final StringBuffer report = StringBuffer();

    // Report header
    report.writeln('===== HASH ANALYSIS REPORT =====');
    report.writeln('');

    // File information
    report.writeln('FILE INFORMATION:');
    report.writeln('Filename: ${widget.hashData['filename'] ?? 'Unknown'}');
    report.writeln('File Type: ${widget.hashData['file_type'] ?? 'Unknown'}');

    if (widget.hashData['file_size'] != null) {
      report.writeln('Size: ${_formatFileSize(widget.hashData['file_size'])}');
    }

    // Hash values
    report.writeln('');
    report.writeln('HASH VALUES:');
    report.writeln('SHA-256: ${widget.hashData['hash']}');

    final fullResults = jsonDecode(widget.hashData['full_results']);
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

    if (widget.hashData['threat_level'] != null) {
      report.writeln('Threat Level: ${widget.hashData['threat_level']}');
    }

    if (widget.hashData['threat_category'] != null &&
        widget.hashData['threat_category'] != '') {
      report.writeln('Threat Category: ${widget.hashData['threat_category']}');
    }

    // Timestamps
    report.writeln('');
    report.writeln('TIMELINE:');
    if (widget.hashData['first_seen'] != null) {
      report.writeln(
        'First Seen: ${_formatDate(widget.hashData['first_seen'])}',
      );
    }
    if (widget.hashData['last_seen'] != null) {
      report.writeln(
        'Last Analyzed: ${_formatDate(widget.hashData['last_seen'])}',
      );
    }
    report.writeln('Scan Date: ${_formatDate(widget.hashData['timestamp'])}');

    // Top detections
    final avLabels =
        widget.hashData['av_labels'] != null
            ? List<String>.from(jsonDecode(widget.hashData['av_labels']))
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
        widget.hashData['tags'] != null
            ? List<String>.from(jsonDecode(widget.hashData['tags']))
            : <String>[];

    if (tagsList.isNotEmpty) {
      report.writeln('');
      report.writeln('TAGS:');
      report.writeln(tagsList.join(', '));
    }

    // Report footer
    report.writeln('');
    report.writeln('Report generated by Argus');
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

  Future<void> _openInVT() async {
    final uri = Uri.parse(
      'https://www.virustotal.com/gui/file/${widget.hashData['hash']}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Utility functions
  double _getMaxCount(Map<String, dynamic> stats) {
    final values = [
      stats['malicious'] ?? 0,
      stats['suspicious'] ?? 0,
      stats['harmless'] ?? 0,
      stats['undetected'] ?? 0,
    ];
    return values.reduce((curr, next) => curr > next ? curr : next).toDouble() *
        1.2;
  }

  IconData _getFormatIcon(String format) {
    switch (format) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'CSV':
        return Icons.table_chart;
      case 'JSON':
        return Icons.code;
      default:
        return Icons.file_download;
    }
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
      default:
        return Icons.remove_circle_outline;
    }
  }

  String _getCategoryName(String category) {
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

  int _getCategoryPriority(String category) {
    switch (category) {
      case 'malicious':
        return 0;
      case 'suspicious':
        return 1;
      case 'harmless':
        return 2;
      case 'undetected':
      default:
        return 3;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMM d, yyyy · h:mm a').format(date);
    } catch (e) {
      return isoDate.substring(0, 16);
    }
  }
}
