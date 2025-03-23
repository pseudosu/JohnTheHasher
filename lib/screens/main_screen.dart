// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/virus_total_service.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/widgets/hash_history_screen.dart';
import 'package:myapp/widgets/hash_input_form.dart';
import 'package:myapp/widgets/hash_results_view.dart';

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

      // Save to database with expanded data
      await DatabaseHelper.instance.insertHash(hash, results);

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
              onSubmit: _submitHash,
            ),
            const SizedBox(height: 20),

            // Results card - conditionally visible
            if (_results != null)
              Card(
                color: const Color.fromRGBO(45, 95, 155, 0.9),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: HashResultsView(results: _results!),
                ),
              ),
          ],
        ),
      ),
    );
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
                  // Close dialog
                  Navigator.pop(context);
                  // Clear database
                  await DatabaseHelper.instance.clearDatabase();
                  // Show confirmation
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

      // Save to database with expanded data
      await DatabaseHelper.instance.insertHash(hash, results);

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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Input form card
          HashInputForm(
            hashController: _hashController,
            formKey: _formKey,
            isLoading: _isLoading,
            onSubmit: _submitHash,
          ),
          const SizedBox(height: 20),

          // Results card - conditionally visible
          if (_results != null)
            Card(
              color: const Color.fromRGBO(45, 95, 155, 0.9),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: HashResultsView(results: _results!),
              ),
            ),
        ],
      ),
    );
  }
}
