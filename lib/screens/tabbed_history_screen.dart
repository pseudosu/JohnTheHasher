// lib/screens/tabbed_history_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/widgets/hash_history_screen.dart';
import 'package:myapp/widgets/ip_history_screen.dart';

class TabbedHistoryScreen extends StatefulWidget {
  final int initialTabIndex;

  const TabbedHistoryScreen({this.initialTabIndex = 0, super.key});

  @override
  State<TabbedHistoryScreen> createState() => _TabbedHistoryScreenState();
}

class _TabbedHistoryScreenState extends State<TabbedHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
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
          'Search History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),

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
              text: 'File Hashes',
            ),
            Tab(
              icon: Icon(Icons.language, color: Colors.white),
              text: 'IP Addresses',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Hash history tab
          HashHistoryContent(),
          // IP history tab
          IpHistoryContent(),
        ],
      ),
    );
  }
}
