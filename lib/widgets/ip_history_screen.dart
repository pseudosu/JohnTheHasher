// lib/widgets/ip_history_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/screens/ip_detail_screen.dart';

class IpHistoryScreen extends StatefulWidget {
  const IpHistoryScreen({super.key});

  @override
  State<IpHistoryScreen> createState() => _IpHistoryScreenState();
}

class _IpHistoryScreenState extends State<IpHistoryScreen> {
  List<Map<String, dynamic>> _ipHistory = [];
  bool _isLoading = true;
  String _filterBy = 'All'; // Can be 'All', 'Malicious', 'Clean'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await DatabaseHelper.instance.getIpAddresses();
      setState(() {
        _ipHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading IP history: ${e.toString()}')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_filterBy == 'All') return _ipHistory;

    return _ipHistory.where((item) {
      final isMalicious = item['detection_count'] > 0;
      return (_filterBy == 'Malicious' && isMalicious) ||
          (_filterBy == 'Clean' && !isMalicious);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'IP History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        elevation: 4,
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _filterBy = value;
              });
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'All', child: Text('Show All')),
                  const PopupMenuItem(
                    value: 'Malicious',
                    child: Text('Malicious Only'),
                  ),
                  const PopupMenuItem(
                    value: 'Clean',
                    child: Text('Clean Only'),
                  ),
                ],
          ),
          // Refresh button
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Color.fromRGBO(25, 55, 109, 1),
                ),
              )
              : _filteredHistory.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.history_toggle_off,
                      color: Color.fromRGBO(25, 55, 109, 0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _ipHistory.isEmpty
                          ? 'No IP search history'
                          : 'No $_filterBy IP entries found',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color.fromRGBO(25, 55, 109, 1),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredHistory.length,
                itemBuilder: (context, index) {
                  final item = _filteredHistory[index];
                  final isMalicious = item['detection_count'] > 0;

                  // Parse json fields
                  final tagsList =
                      item['tags'] != null
                          ? List<String>.from(jsonDecode(item['tags']))
                          : <String>[];

                  final avLabels =
                      item['av_labels'] != null
                          ? List<String>.from(jsonDecode(item['av_labels']))
                          : <String>[];

                  // Take just the first two AV labels
                  final displayLabels = avLabels.take(2).toList();

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            isMalicious
                                ? Colors.red.withOpacity(0.5)
                                : Colors.green.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IpDetailScreen(ipData: item),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with IP info
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMalicious
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        isMalicious
                                            ? Colors.red.withOpacity(0.2)
                                            : Colors.green.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isMalicious
                                          ? Icons.warning
                                          : Icons.check_circle,
                                      color:
                                          isMalicious
                                              ? Colors.red
                                              : Colors.green,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // lib/widgets/ip_history_screen.dart (continued)
                                      Text(
                                        item['ip_address'] ?? 'Unknown IP',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${item['as_owner'] ?? 'Unknown owner'} • ',
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(
                                                0.6,
                                              ),
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            item['country'] ??
                                                'Unknown location',
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(
                                                0.6,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMalicious
                                            ? Colors.red.withOpacity(0.2)
                                            : Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isMalicious ? 'Malicious' : 'Clean',
                                    style: TextStyle(
                                      color:
                                          isMalicious
                                              ? Colors.red
                                              : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // IP and detection details
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // IP address with copy option
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.language,
                                      size: 16,
                                      color: Color.fromRGBO(25, 55, 109, 1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item['ip_address'],
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        // Copy IP to clipboard
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: item['ip_address'],
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'IP copied to clipboard',
                                            ),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Detection ratio
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isMalicious
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Detection: ${item['detection_ratio'] ?? '0/0'}',
                                        style: TextStyle(
                                          color:
                                              isMalicious
                                                  ? Colors.red
                                                  : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['timestamp'] != null
                                          ? DateTime.parse(
                                            item['timestamp'],
                                          ).toString().substring(0, 10)
                                          : 'Unknown date',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                // AV detection names
                                if (displayLabels.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Detection Names:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...displayLabels.map(
                                    (label) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        '• $label',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (avLabels.length > 2)
                                    Text(
                                      'And ${avLabels.length - 2} more...',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                                // Tags
                                if (tagsList.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children:
                                        tagsList
                                            .take(3) // Show max 3 tags
                                            .map(
                                              (tag) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color.fromRGBO(
                                                    25,
                                                    55,
                                                    109,
                                                    0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color.fromRGBO(
                                                      25,
                                                      55,
                                                      109,
                                                      1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // View details button
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.black12,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            IpDetailScreen(ipData: item),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color.fromRGBO(
                                  25,
                                  55,
                                  109,
                                  1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('VIEW FULL DETAILS'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

// Content widget for use in tabs
class IpHistoryContent extends StatefulWidget {
  const IpHistoryContent({super.key});

  @override
  State<IpHistoryContent> createState() => _IpHistoryContentState();
}

class _IpHistoryContentState extends State<IpHistoryContent> {
  List<Map<String, dynamic>> _ipHistory = [];
  bool _isLoading = true;
  String _filterBy = 'All'; // Can be 'All', 'Malicious', 'Clean'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await DatabaseHelper.instance.getIpAddresses();
      setState(() {
        _ipHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading IP history: ${e.toString()}')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_filterBy == 'All') return _ipHistory;

    return _ipHistory.where((item) {
      final isMalicious = item['detection_count'] > 0;
      return (_filterBy == 'Malicious' && isMalicious) ||
          (_filterBy == 'Clean' && !isMalicious);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        toolbarHeight:
            0, // Hide the default AppBar since we're using the parent's tabs
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color.fromRGBO(240, 245, 249, 1),
            child: Row(
              children: [
                // Filter dropdown
                DropdownButton<String>(
                  value: _filterBy,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _filterBy = value;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('Show All')),
                    DropdownMenuItem(
                      value: 'Malicious',
                      child: Text('Malicious Only'),
                    ),
                    DropdownMenuItem(value: 'Clean', child: Text('Clean Only')),
                  ],
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list),
                ),
                const Spacer(),
                // Refresh button
                IconButton(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh History',
                ),
              ],
            ),
          ),

          // History list
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color.fromRGBO(25, 55, 109, 1),
                      ),
                    )
                    : _filteredHistory.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history_toggle_off,
                            color: Color.fromRGBO(25, 55, 109, 0.5),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _ipHistory.isEmpty
                                ? 'No IP search history'
                                : 'No $_filterBy IP entries found',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color.fromRGBO(25, 55, 109, 1),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, index) {
                        final item = _filteredHistory[index];
                        final isMalicious = item['detection_count'] > 0;

                        // Parse json fields
                        final tagsList =
                            item['tags'] != null
                                ? List<String>.from(jsonDecode(item['tags']))
                                : <String>[];

                        final avLabels =
                            item['av_labels'] != null
                                ? List<String>.from(
                                  jsonDecode(item['av_labels']),
                                )
                                : <String>[];

                        // Take just the first two AV labels
                        final displayLabels = avLabels.take(2).toList();

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  isMalicious
                                      ? Colors.red.withOpacity(0.5)
                                      : Colors.green.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => IpDetailScreen(ipData: item),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with IP info
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMalicious
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color:
                                              isMalicious
                                                  ? Colors.red.withOpacity(0.2)
                                                  : Colors.green.withOpacity(
                                                    0.2,
                                                  ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isMalicious
                                                ? Icons.warning
                                                : Icons.check_circle,
                                            color:
                                                isMalicious
                                                    ? Colors.red
                                                    : Colors.green,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['ip_address'] ??
                                                  'Unknown IP',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '${item['as_owner'] ?? 'Unknown owner'} • ',
                                                  style: TextStyle(
                                                    color: Colors.black
                                                        .withOpacity(0.6),
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  item['country'] ??
                                                      'Unknown location',
                                                  style: TextStyle(
                                                    color: Colors.black
                                                        .withOpacity(0.6),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isMalicious
                                                  ? Colors.red.withOpacity(0.2)
                                                  : Colors.green.withOpacity(
                                                    0.2,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          isMalicious ? 'Malicious' : 'Clean',
                                          style: TextStyle(
                                            color:
                                                isMalicious
                                                    ? Colors.red
                                                    : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // IP and detection details
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // IP address with copy option
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.language,
                                            size: 16,
                                            color: Color.fromRGBO(
                                              25,
                                              55,
                                              109,
                                              1,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item['ip_address'],
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.copy,
                                              size: 16,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              // Copy IP to clipboard
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: item['ip_address'],
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'IP copied to clipboard',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Detection ratio
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isMalicious
                                                      ? Colors.red.withOpacity(
                                                        0.1,
                                                      )
                                                      : Colors.green
                                                          .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Detection: ${item['detection_ratio'] ?? '0/0'}',
                                              style: TextStyle(
                                                color:
                                                    isMalicious
                                                        ? Colors.red
                                                        : Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item['timestamp'] != null
                                                ? DateTime.parse(
                                                  item['timestamp'],
                                                ).toString().substring(0, 10)
                                                : 'Unknown date',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // AV detection names
                                      if (displayLabels.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Detection Names:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ...displayLabels.map(
                                          (label) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            child: Text(
                                              '• $label',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        if (avLabels.length > 2)
                                          Text(
                                            'And ${avLabels.length - 2} more...',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                      // Tags
                                      if (tagsList.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children:
                                              tagsList
                                                  .take(3) // Show max 3 tags
                                                  .map(
                                                    (tag) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            const Color.fromRGBO(
                                                              25,
                                                              55,
                                                              109,
                                                              0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        tag,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Color.fromRGBO(
                                                            25,
                                                            55,
                                                            109,
                                                            1,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // View details button
                                Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.black12,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  IpDetailScreen(ipData: item),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color.fromRGBO(
                                        25,
                                        55,
                                        109,
                                        1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('VIEW FULL DETAILS'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
