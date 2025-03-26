// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/virus_total_service.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/widgets/hash_history_screen.dart';
import 'package:myapp/widgets/hash_input_form.dart';
import 'package:myapp/widgets/hash_results_view.dart';
import 'package:myapp/screens/hash_detail_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _hashController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Batch processing state
  List<Map<String, dynamic>> _batchResults = [];
  int _processedCount = 0;
  int _totalToProcess = 0;
  bool _isBatchProcessing = false;

  // Single result view
  Map<String, dynamic>? _singleResult;

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _submitBatch(List<Map<String, dynamic>> hashData) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isBatchProcessing = hashData.length > 1;
      _totalToProcess = hashData.length;
      _processedCount = 0;
      _batchResults = [];
      _singleResult = null;
    });

    try {
      if (_isBatchProcessing) {
        // Process batches of 4 concurrently to respect API rate limits
        const batchSize = 4;
        for (var i = 0; i < hashData.length; i += batchSize) {
          final end =
              (i + batchSize < hashData.length)
                  ? i + batchSize
                  : hashData.length;

          final batch = hashData.sublist(i, end);
          await Future.wait(batch.map((item) => _processHashItem(item)));

          setState(() {
            _processedCount = i + batch.length;
          });

          // Small delay to avoid API throttling
          if (end < hashData.length) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        // Process a single hash
        final result = await _processHashItem(hashData.first);
        setState(() {
          _singleResult = result;
          _isLoading = false;
        });
      }
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

  Future<Map<String, dynamic>> _processHashItem(
    Map<String, dynamic> item,
  ) async {
    try {
      final hash = item['hash'];
      final results = await VirusTotalService.checkHash(hash);

      // For files, try to get behavioral data if available
      Map<String, dynamic>? behaviorData;
      if (results['data']['attributes']['last_analysis_stats']['malicious'] >
          0) {
        try {
          behaviorData = await VirusTotalService.getBehaviorData(hash);
        } catch (e) {
          // Behavior data is optional, continue if it fails
        }
      }

      // Extract file details
      final fileDetails = VirusTotalService.extractFileDetails(results);

      // Save to database
      await DatabaseHelper.instance.insertHash(hash, results);

      // Add to batch results if in batch mode
      if (_isBatchProcessing) {
        setState(() {
          _batchResults.add({
            ...item,
            ...fileDetails,
            'full_results': results,
            'behavior_data': behaviorData,
          });
        });
      }

      return {
        ...item,
        ...fileDetails,
        'full_results': results,
        'behavior_data': behaviorData,
      };
    } catch (e) {
      // Add to batch results with error status
      if (_isBatchProcessing) {
        setState(() {
          _batchResults.add({...item, 'error': e.toString()});
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'Argus',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
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
            onPressed: _showClearDatabaseDialog,
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
            // Input form card
            HashInputForm(
              hashController: _hashController,
              formKey: _formKey,
              isLoading: _isLoading,
              onSubmit: _submitBatch,
            ),
            const SizedBox(height: 20),

            // Batch processing progress indicator
            if (_isBatchProcessing && _isLoading)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processing Batch: $_processedCount of $_totalToProcess',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value:
                            _totalToProcess > 0
                                ? _processedCount / _totalToProcess
                                : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(25, 55, 109, 1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completed: $_processedCount',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),

            // Batch results list
            if (_batchResults.isNotEmpty) ..._buildBatchResultsList(),

            // Single result card - conditionally visible
            if (_singleResult != null && !_isBatchProcessing)
              Card(
                color: const Color.fromRGBO(45, 95, 155, 0.9),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: HashResultsView(
                    results: _singleResult!['full_results'],
                    // Don't pass behaviorData if the parameter doesn't exist
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBatchResultsList() {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(
          'Batch Results (${_batchResults.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      ...List.generate(_batchResults.length, (index) {
        final item = _batchResults[index];
        final hasError = item.containsKey('error');
        final isMalicious =
            !hasError &&
            (item['detectionPercentage'] != null &&
                double.parse(item['detectionPercentage']) > 0);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color:
                  hasError
                      ? Colors.grey.withOpacity(0.5)
                      : isMalicious
                      ? Colors.red.withOpacity(0.5)
                      : Colors.green.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap:
                hasError
                    ? null
                    : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HashDetailScreen(hashData: item),
                      ),
                    ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          hasError
                              ? Colors.grey.withOpacity(0.2)
                              : isMalicious
                              ? Colors.red.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasError
                          ? Icons.error_outline
                          : isMalicious
                          ? Icons.warning
                          : Icons.check_circle,
                      color:
                          hasError
                              ? Colors.grey
                              : isMalicious
                              ? Colors.red
                              : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // File name or hash
                        Text(
                          item['filename'] ?? 'Unknown file',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Hash value
                        Text(
                          item['hash'],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Status row
                        hasError
                            ? Text(
                              'Error: ${item['error']}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                            : Row(
                              children: [
                                // Detection ratio
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
                                    'Detection: ${isMalicious ? item['detectionPercentage'] + '%' : '0%'}',
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
                                // File type
                                Text(
                                  item['fileType'] ?? 'Unknown type',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                  // View details button
                  if (!hasError)
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => HashDetailScreen(hashData: item),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

  void _showClearDatabaseDialog() {
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
                  Navigator.pop(context);
                  await DatabaseHelper.instance.clearDatabase();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Database cleared successfully'),
                      backgroundColor: Color.fromRGBO(25, 55, 109, 1),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );
  }
}

// Content widget for use in tabs
class MainScreenContent extends StatefulWidget {
  const MainScreenContent({super.key});

  @override
  State<MainScreenContent> createState() => _MainScreenContentState();
}

class _MainScreenContentState extends State<MainScreenContent> {
  final TextEditingController _hashController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Batch processing state
  List<Map<String, dynamic>> _batchResults = [];
  int _processedCount = 0;
  int _totalToProcess = 0;
  bool _isBatchProcessing = false;

  // Single result view
  Map<String, dynamic>? _singleResult;

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _submitBatch(List<Map<String, dynamic>> hashData) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isBatchProcessing = hashData.length > 1;
      _totalToProcess = hashData.length;
      _processedCount = 0;
      _batchResults = [];
      _singleResult = null;
    });

    try {
      if (_isBatchProcessing) {
        // Process batches of 4 concurrently to respect API rate limits
        const batchSize = 4;
        for (var i = 0; i < hashData.length; i += batchSize) {
          final end =
              (i + batchSize < hashData.length)
                  ? i + batchSize
                  : hashData.length;

          final batch = hashData.sublist(i, end);
          await Future.wait(batch.map((item) => _processHashItem(item)));

          setState(() {
            _processedCount = i + batch.length;
          });

          // Small delay to avoid API throttling
          if (end < hashData.length) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        // Process a single hash
        final result = await _processHashItem(hashData.first);
        setState(() {
          _singleResult = result;
          _isLoading = false;
        });
      }
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

  Future<Map<String, dynamic>> _processHashItem(
    Map<String, dynamic> item,
  ) async {
    try {
      final hash = item['hash'];
      final results = await VirusTotalService.checkHash(hash);

      // For files, try to get behavioral data if available
      Map<String, dynamic>? behaviorData;
      if (results['data']['attributes']['last_analysis_stats']['malicious'] >
          0) {
        try {
          behaviorData = await VirusTotalService.getBehaviorData(hash);
        } catch (e) {
          // Behavior data is optional, continue if it fails
        }
      }

      // Extract file details
      final fileDetails = VirusTotalService.extractFileDetails(results);

      // Save to database
      await DatabaseHelper.instance.insertHash(hash, results);

      // Add to batch results if in batch mode
      if (_isBatchProcessing) {
        setState(() {
          _batchResults.add({
            ...item,
            ...fileDetails,
            'full_results': results,
            'behavior_data': behaviorData,
          });
        });
      }

      return {
        ...item,
        ...fileDetails,
        'full_results': results,
        'behavior_data': behaviorData,
      };
    } catch (e) {
      // Add to batch results with error status
      if (_isBatchProcessing) {
        setState(() {
          _batchResults.add({...item, 'error': e.toString()});
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Input form card
          HashInputForm(
            hashController: _hashController,
            formKey: _formKey,
            isLoading: _isLoading,
            onSubmit: _submitBatch,
          ),
          const SizedBox(height: 20),

          // Batch processing progress indicator
          if (_isBatchProcessing && _isLoading)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processing Batch: $_processedCount of $_totalToProcess',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          _totalToProcess > 0
                              ? _processedCount / _totalToProcess
                              : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color.fromRGBO(25, 55, 109, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completed: $_processedCount',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

          // Batch results list
          if (_batchResults.isNotEmpty) ..._buildBatchResultsList(),

          // Single result card - conditionally visible
          if (_singleResult != null && !_isBatchProcessing)
            Card(
              color: const Color.fromRGBO(45, 95, 155, 0.9),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: HashResultsView(
                  results: _singleResult!['full_results'],
                  // Don't pass behaviorData if the parameter doesn't exist
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildBatchResultsList() {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(
          'Batch Results (${_batchResults.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      ...List.generate(_batchResults.length, (index) {
        final item = _batchResults[index];
        final hasError = item.containsKey('error');
        final isMalicious =
            !hasError &&
            (item['detectionPercentage'] != null &&
                double.parse(item['detectionPercentage']) > 0);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color:
                  hasError
                      ? Colors.grey.withOpacity(0.5)
                      : isMalicious
                      ? Colors.red.withOpacity(0.5)
                      : Colors.green.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap:
                hasError
                    ? null
                    : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HashDetailScreen(hashData: item),
                      ),
                    ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          hasError
                              ? Colors.grey.withOpacity(0.2)
                              : isMalicious
                              ? Colors.red.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasError
                          ? Icons.error_outline
                          : isMalicious
                          ? Icons.warning
                          : Icons.check_circle,
                      color:
                          hasError
                              ? Colors.grey
                              : isMalicious
                              ? Colors.red
                              : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // File name or hash
                        Text(
                          item['filename'] ?? 'Unknown file',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Hash value
                        Text(
                          item['hash'],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Status row
                        hasError
                            ? Text(
                              'Error: ${item['error']}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                            : Row(
                              children: [
                                // Detection ratio
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
                                    'Detection: ${isMalicious ? item['detectionPercentage'] + '%' : '0%'}',
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
                                // File type
                                Text(
                                  item['fileType'] ?? 'Unknown type',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                  // View details button
                  if (!hasError)
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => HashDetailScreen(hashData: item),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }
}
