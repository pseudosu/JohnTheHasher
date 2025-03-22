import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:myapp/services/virus_total_service.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/widgets/hash_history_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _hashController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Map<String, dynamic>? _results;

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _submitHash() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final hash = _hashController.text.trim();
      final results = await VirusTotalService.checkHash(hash);

      // Save to database
      await DatabaseHelper.instance.insertHash(
        hash,
        results['data']['attributes']['meaningful_name'] ?? 'Unknown',
        jsonEncode(results),
      );

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(
        240,
        245,
        249,
        1,
      ), // Light blue-gray background
      appBar: AppBar(
        title: const Text(
          'John the Hasher',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(
          25,
          55,
          109,
          1,
        ), // Navy blue AppBar
        elevation: 4,
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HashHistoryScreen(),
              ),
            );
          },
          icon: const Icon(Icons.history, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Clear Database'),
                      content: const Text(
                        'Are you sure you want to clear all hash search history? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            // Close dialog
                            Navigator.pop(context);
                            // Clear database
                            await DatabaseHelper.instance.clearDatabase();
                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Database cleared successfully'),
                                backgroundColor: Color.fromRGBO(25, 55, 109, 1),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
              );
            },
            icon: const Icon(Icons.delete_forever),
            color: Colors.white,
            tooltip: 'Clear Database',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Input form card - ALWAYS visible
            Card(
              color: const Color.fromRGBO(45, 95, 155, 1), // Medium blue card
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter File Hash',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Fixed implementation - separate label above TextField
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MD5, SHA-1, or SHA-256',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _hashController,
                            decoration: InputDecoration(
                              // No labelText to avoid positioning issues
                              hintText:
                                  'e.g., 44d88612fea8a8f36de82e1278abb02f',
                              hintStyle: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                                horizontal: 16.0,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              prefixIcon: const Icon(
                                Icons.fingerprint,
                                color: Color.fromRGBO(25, 55, 109, 1),
                              ),
                            ),
                            style: const TextStyle(color: Colors.black87),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a hash';
                              }

                              // Hash format validation
                              final md5Regex = RegExp(r'^[a-fA-F0-9]{32}$');
                              final sha1Regex = RegExp(r'^[a-fA-F0-9]{40}$');
                              final sha256Regex = RegExp(r'^[a-fA-F0-9]{64}$');

                              if (!md5Regex.hasMatch(value) &&
                                  !sha1Regex.hasMatch(value) &&
                                  !sha256Regex.hasMatch(value)) {
                                return 'Invalid hash format';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitHash,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: const Color.fromRGBO(45, 95, 155, 1),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledForegroundColor: Colors.white54,
                          disabledBackgroundColor: Colors.black12,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Color.fromRGBO(45, 95, 155, 1),
                                  ),
                                )
                                : const Text(
                                  'Submit to VirusTotal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Results card - conditionally visible
            if (_results != null)
              Card(
                color: const Color.fromRGBO(
                  45,
                  95,
                  155,
                  0.9,
                ), // Slightly transparent medium blue
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildResultsView(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_results == null) return const SizedBox.shrink();

    final attributes = _results!['data']['attributes'];
    final stats = attributes['last_analysis_stats'];
    final totalEngines =
        stats['malicious'] +
        stats['undetected'] +
        stats['suspicious'] +
        stats['harmless'] +
        stats['timeout'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
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
        const Divider(color: Colors.white30, height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                stats['malicious'] > 0
                    ? Colors.red.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: stats['malicious'] > 0 ? Colors.red : Colors.green,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                stats['malicious'] > 0 ? Icons.warning : Icons.check_circle,
                color: stats['malicious'] > 0 ? Colors.red : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Disposition: ${stats['malicious']} of $totalEngines engines',
                style: TextStyle(
                  fontSize: 16,
                  color: stats['malicious'] > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatIndicator('Malicious', stats['malicious'], Colors.red),
              _buildStatIndicator(
                'Suspicious',
                stats['suspicious'],
                Colors.orange,
              ),
              _buildStatIndicator('Clean', stats['harmless'], Colors.green),
            ],
          ),
        ),
        const Divider(color: Colors.white30, height: 24),

        if (attributes.containsKey('creation_date')) ...[
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Created: ${DateTime.fromMillisecondsSinceEpoch(attributes['creation_date'] * 1000).toString().substring(0, 16)}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        if (attributes.containsKey('first_submission_date')) ...[
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'First seen: ${DateTime.fromMillisecondsSinceEpoch(attributes['first_submission_date'] * 1000).toString().substring(0, 16)}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],

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
                  label: Text(tag),
                  backgroundColor: Colors.white24,
                  labelStyle: const TextStyle(color: Colors.black),
                ),
            ],
          ),
        ],
      ],
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
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
