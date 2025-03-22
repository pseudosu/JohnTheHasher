import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:myapp/helpers/database_helper.dart';

class HashHistoryScreen extends StatefulWidget {
  const HashHistoryScreen({super.key});

  @override
  State<HashHistoryScreen> createState() => _HashHistoryScreenState();
}

class _HashHistoryScreenState extends State<HashHistoryScreen> {
  List<Map<String, dynamic>> _hashHistory = [];
  bool _isLoading = true;

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
      final history = await DatabaseHelper.instance.getHashes();
      setState(() {
        _hashHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Security-focused background color - light blue-gray
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'Hash History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // Navy blue AppBar
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  // Match the loading indicator to the app theme
                  color: Color.fromRGBO(25, 55, 109, 1),
                ),
              )
              : _hashHistory.isEmpty
              ? const Center(
                child: Text(
                  'No hash search history',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromRGBO(25, 55, 109, 1),
                  ),
                ),
              )
              : ListView.builder(
                itemCount: _hashHistory.length,
                itemBuilder: (context, index) {
                  final item = _hashHistory[index];
                  final results = jsonDecode(item['results']);
                  final stats =
                      results['data']['attributes']['last_analysis_stats'];
                  final isMalicious = stats['malicious'] > 0;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    // Card color based on malicious status
                    color:
                        isMalicious
                            ? const Color.fromRGBO(
                              255,
                              235,
                              235,
                              1,
                            ) // Light red for malicious
                            : const Color.fromRGBO(
                              235,
                              255,
                              235,
                              1,
                            ), // Light green for clean
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        item['filename'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              isMalicious
                                  ? const Color.fromRGBO(
                                    180,
                                    0,
                                    0,
                                    1,
                                  ) // Darker red for malicious text
                                  : const Color.fromRGBO(
                                    0,
                                    120,
                                    0,
                                    1,
                                  ), // Darker green for clean text
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Hash: ${item['hash']}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isMalicious
                                    ? Icons.warning
                                    : Icons.check_circle,
                                size: 16,
                                color: isMalicious ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Disposition: ${stats['malicious']} / '
                                '${stats['malicious'] + stats['undetected'] + stats['harmless']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isMalicious ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(25, 55, 109, 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateTime.parse(
                            item['timestamp'],
                          ).toString().substring(0, 16),
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color.fromRGBO(25, 55, 109, 1),
                          ),
                        ),
                      ),
                      onTap: () {
                        // We'll implement this later
                      },
                    ),
                  );
                },
              ),
    );
  }
}
