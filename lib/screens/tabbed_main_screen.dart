// lib/screens/tabbed_main_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/screens/main_screen.dart';
import 'package:myapp/screens/ip_screen.dart';
import 'package:myapp/screens/tabbed_history_screen.dart';

class TabbedMainScreen extends StatefulWidget {
  const TabbedMainScreen({super.key});

  @override
  State<TabbedMainScreen> createState() => _TabbedMainScreenState();
}

class _TabbedMainScreenState extends State<TabbedMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                builder:
                    (context) => TabbedHistoryScreen(
                      initialTabIndex: _tabController.index,
                    ),
              ),
            );
          },
          icon: const Icon(Icons.history, color: Colors.white),
          tooltip: 'History',
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 16,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.fingerprint, color: Colors.white),
              text: 'File Hash',
            ),
            Tab(
              icon: Icon(Icons.language, color: Colors.white),
              text: 'IP Address',
            ),
          ],
        ),
        actions: [
          // Clear Database button
          IconButton(
            onPressed: _showClearDatabaseDialog,
            icon: const Icon(Icons.delete_forever),
            color: Colors.white,
            tooltip: 'Clear Database',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Hash tab content
          MainScreenContent(),
          // IP tab content
          IpScreenContent(),
        ],
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
              'Are you sure you want to clear all search history? This action cannot be undone.',
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
