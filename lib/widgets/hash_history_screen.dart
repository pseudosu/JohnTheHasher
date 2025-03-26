// lib/widgets/hash_history_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/screens/hash_detail_screen.dart';
import 'package:intl/intl.dart';

class HashHistoryScreen extends StatefulWidget {
  const HashHistoryScreen({super.key});

  @override
  State<HashHistoryScreen> createState() => _HashHistoryScreenState();
}

class _HashHistoryScreenState extends State<HashHistoryScreen> {
  List<Map<String, dynamic>> _allHashHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = true;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter state
  String _filterCategory = 'All';
  String _sortBy = 'date_desc';
  String _selectedFileType = 'All';
  List<String> _fileTypes = ['All'];
  DateTimeRange? _dateRange;

  // Expanded state tracking
  Set<int> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();

    // Listen for search input changes
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await DatabaseHelper.instance.getHashes();

      // Extract all unique file types for filtering
      final types = <String>{'All'};
      for (var item in history) {
        if (item['file_type'] != null &&
            item['file_type'].toString().isNotEmpty) {
          types.add(item['file_type'].toString());
        }
      }

      setState(() {
        _allHashHistory = history;
        _fileTypes = types.toList()..sort();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: ${e.toString()}')),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilters();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_allHashHistory);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result =
          result.where((item) {
            // Search in filename
            final filename = (item['filename'] ?? '').toString().toLowerCase();
            if (filename.contains(_searchQuery)) return true;

            // Search in hash
            final hash = (item['hash'] ?? '').toString().toLowerCase();
            if (hash.contains(_searchQuery)) return true;

            // Search in file type
            final fileType = (item['file_type'] ?? '').toString().toLowerCase();
            if (fileType.contains(_searchQuery)) return true;

            // Search in tags
            if (item['tags'] != null) {
              try {
                final tags = List<String>.from(jsonDecode(item['tags']));
                for (var tag in tags) {
                  if (tag.toLowerCase().contains(_searchQuery)) return true;
                }
              } catch (_) {}
            }

            // Search in AV labels
            if (item['av_labels'] != null) {
              try {
                final labels = List<String>.from(jsonDecode(item['av_labels']));
                for (var label in labels) {
                  if (label.toLowerCase().contains(_searchQuery)) return true;
                }
              } catch (_) {}
            }

            return false;
          }).toList();
    }

    // Apply detection status filter
    if (_filterCategory != 'All') {
      result =
          result.where((item) {
            final isMalicious = item['detection_count'] > 0;
            return (_filterCategory == 'Malicious' && isMalicious) ||
                (_filterCategory == 'Clean' && !isMalicious);
          }).toList();
    }

    // Apply file type filter
    if (_selectedFileType != 'All') {
      result =
          result
              .where((item) => item['file_type'] == _selectedFileType)
              .toList();
    }

    // Apply date range filter
    if (_dateRange != null) {
      result =
          result.where((item) {
            if (item['timestamp'] == null) return false;

            try {
              final date = DateTime.parse(item['timestamp']);
              return date.isAfter(_dateRange!.start) &&
                  date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
            } catch (_) {
              return false;
            }
          }).toList();
    }

    // Apply sorting
    result.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return _compareByDate(a, b);
        case 'date_desc':
          return _compareByDate(b, a);
        case 'name_asc':
          return _compareByName(a, b);
        case 'name_desc':
          return _compareByName(b, a);
        case 'detection_asc':
          return _compareByDetection(a, b);
        case 'detection_desc':
          return _compareByDetection(b, a);
        default:
          return _compareByDate(b, a); // Default to newest first
      }
    });

    setState(() {
      _filteredHistory = result;
    });
  }

  int _compareByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final dateA =
        a['timestamp'] != null
            ? DateTime.parse(a['timestamp'])
            : DateTime(1970);
    final dateB =
        b['timestamp'] != null
            ? DateTime.parse(b['timestamp'])
            : DateTime(1970);
    return dateA.compareTo(dateB);
  }

  int _compareByName(Map<String, dynamic> a, Map<String, dynamic> b) {
    final nameA = (a['filename'] ?? '').toString();
    final nameB = (b['filename'] ?? '').toString();
    return nameA.compareTo(nameB);
  }

  int _compareByDetection(Map<String, dynamic> a, Map<String, dynamic> b) {
    final countA = a['detection_count'] ?? 0;
    final countB = b['detection_count'] ?? 0;
    return countA.compareTo(countB);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status filter
                    const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All', 'All', _filterCategory, (
                          value,
                        ) {
                          setDialogState(() => _filterCategory = value);
                        }),
                        _buildFilterChip(
                          'Malicious',
                          'Malicious',
                          _filterCategory,
                          (value) {
                            setDialogState(() => _filterCategory = value);
                          },
                        ),
                        _buildFilterChip('Clean', 'Clean', _filterCategory, (
                          value,
                        ) {
                          setDialogState(() => _filterCategory = value);
                        }),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // File type filter
                    const Text(
                      'File Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: _selectedFileType,
                      isExpanded: true,
                      items:
                          _fileTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            _selectedFileType = newValue;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Date range filter
                    const Text(
                      'Date Range',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateRange != null
                                ? '${DateFormat('MMM d, y').format(_dateRange!.start)} - '
                                    '${DateFormat('MMM d, y').format(_dateRange!.end)}'
                                : 'All Dates',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final result = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              initialDateRange:
                                  _dateRange ??
                                  DateTimeRange(
                                    start: DateTime.now().subtract(
                                      const Duration(days: 30),
                                    ),
                                    end: DateTime.now(),
                                  ),
                            );

                            if (result != null) {
                              setDialogState(() {
                                _dateRange = result;
                              });
                            }
                          },
                          child: const Text('Select Dates'),
                        ),
                        if (_dateRange != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setDialogState(() {
                                _dateRange = null;
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Sort order
                    const Text(
                      'Sort By',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'date_desc',
                          child: Text('Date (Newest first)'),
                        ),
                        DropdownMenuItem(
                          value: 'date_asc',
                          child: Text('Date (Oldest first)'),
                        ),
                        DropdownMenuItem(
                          value: 'name_asc',
                          child: Text('Filename (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'name_desc',
                          child: Text('Filename (Z-A)'),
                        ),
                        DropdownMenuItem(
                          value: 'detection_desc',
                          child: Text('Most Detections'),
                        ),
                        DropdownMenuItem(
                          value: 'detection_asc',
                          child: Text('Least Detections'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            _sortBy = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _applyFilters();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected,
  ) {
    final selected = value == selectedValue;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      backgroundColor: Colors.grey.withOpacity(0.1),
      selectedColor: const Color.fromRGBO(25, 55, 109, 0.2),
      checkmarkColor: const Color.fromRGBO(25, 55, 109, 1),
      labelStyle: TextStyle(
        color: selected ? const Color.fromRGBO(25, 55, 109, 1) : Colors.black,
      ),
    );
  }

  void _toggleItemExpansion(int index) {
    setState(() {
      if (_expandedItems.contains(index)) {
        _expandedItems.remove(index);
      } else {
        _expandedItems.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'Hash History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        elevation: 4,
        actions: [
          // Filter button
          IconButton(
            onPressed: _showFilterDialog,
            icon: Badge(
              isLabelVisible:
                  _filterCategory != 'All' ||
                  _selectedFileType != 'All' ||
                  _dateRange != null,
              child: const Icon(Icons.filter_list, color: Colors.white),
            ),
            tooltip: 'Filter Options',
          ),
          // Refresh button
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search by hash, filename, or tag...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // Filter chips row for quick filtering
          if (_allHashHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildQuickFilterChip('All', 'All'),
                    _buildQuickFilterChip('Malicious', 'Malicious'),
                    _buildQuickFilterChip('Clean', 'Clean'),
                    const SizedBox(width: 8),
                    // Stats counters
                    _buildStatChip(
                      'Total',
                      _allHashHistory.length.toString(),
                      Colors.grey.shade700,
                    ),
                    _buildStatChip(
                      'Malicious',
                      _allHashHistory
                          .where((i) => i['detection_count'] > 0)
                          .length
                          .toString(),
                      Colors.red,
                    ),
                    _buildStatChip(
                      'Clean',
                      _allHashHistory
                          .where((i) => i['detection_count'] == 0)
                          .length
                          .toString(),
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),

          // Results info bar
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Results: ${_filteredHistory.length} of ${_allHashHistory.length}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Sort dropdown
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.sort),
                    items: const [
                      DropdownMenuItem(
                        value: 'date_desc',
                        child: Text('Newest'),
                      ),
                      DropdownMenuItem(
                        value: 'date_asc',
                        child: Text('Oldest'),
                      ),
                      DropdownMenuItem(value: 'name_asc', child: Text('A-Z')),
                      DropdownMenuItem(value: 'name_desc', child: Text('Z-A')),
                      DropdownMenuItem(
                        value: 'detection_desc',
                        child: Text('Most detections'),
                      ),
                      DropdownMenuItem(
                        value: 'detection_asc',
                        child: Text('Least detections'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

          // Main content
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
                            Icons.search_off,
                            color: Color.fromRGBO(25, 55, 109, 0.5),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _allHashHistory.isEmpty
                                ? 'No hash search history'
                                : 'No results found',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color.fromRGBO(25, 55, 109, 1),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _filterCategory != 'All' ||
                              _selectedFileType != 'All' ||
                              _dateRange != null)
                            TextButton.icon(
                              icon: const Icon(Icons.filter_alt_off),
                              label: const Text('Clear all filters'),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _filterCategory = 'All';
                                  _selectedFileType = 'All';
                                  _dateRange = null;
                                  _applyFilters();
                                });
                              },
                            ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, index) => _buildHistoryItem(index),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, String value) {
    final selected = value == _filterCategory;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filterCategory = value;
            _applyFilters();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color.fromRGBO(25, 55, 109, 0.2),
        checkmarkColor: const Color.fromRGBO(25, 55, 109, 1),
        labelStyle: TextStyle(
          color: selected ? const Color.fromRGBO(25, 55, 109, 1) : Colors.black,
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text('$label: $count'),
        backgroundColor: color.withOpacity(0.1),
        labelStyle: TextStyle(color: color),
      ),
    );
  }

  Widget _buildHistoryItem(int index) {
    final item = _filteredHistory[index];
    final isMalicious = item['detection_count'] > 0;
    final isExpanded = _expandedItems.contains(index);

    // Parse json fields
    final tagsList =
        item['tags'] != null
            ? List<String>.from(jsonDecode(item['tags']))
            : <String>[];

    final topLabels =
        item['av_labels'] != null
            ? List<String>.from(jsonDecode(item['av_labels']))
            : <String>[];

    // Take just the first two AV labels
    final displayLabels = topLabels.take(2).toList();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
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
          // Toggle expansion if clicked on card
          _toggleItemExpansion(index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with file info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  // Status icon
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
                        isMalicious ? Icons.warning : Icons.check_circle,
                        color: isMalicious ? Colors.red : Colors.green,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Row(
                          children: [
                            Text(
                              '${item['file_type'] ?? 'Unknown type'} • ',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              item['file_size'] != null
                                  ? _formatFileSize(item['file_size'])
                                  : 'Unknown size',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
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
                      item['threat_level'] ??
                          (isMalicious ? 'Malicious' : 'Clean'),
                      style: TextStyle(
                        color: isMalicious ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main content - always visible
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hash display with copy option
                  Row(
                    children: [
                      const Icon(
                        Icons.fingerprint,
                        size: 16,
                        color: Color.fromRGBO(25, 55, 109, 1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['hash'],
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
                          Clipboard.setData(ClipboardData(text: item['hash']));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hash copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Expand/collapse button
                      IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _toggleItemExpansion(index),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Detection ratio and date row
                  Row(
                    children: [
                      // Detection chip
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
                            color: isMalicious ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Date
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['timestamp'] != null
                            ? _formatDate(item['timestamp'])
                            : 'Unknown date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded content - only visible when expanded
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AV detection names
                    if (displayLabels.isNotEmpty) ...[
                      const Text(
                        'Detection Names:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...displayLabels.map(
                        (label) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.security,
                                color: Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (topLabels.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'And ${topLabels.length - 2} more...',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],

                    // Tags
                    if (tagsList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Tags:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            tagsList
                                .map(
                                  (tag) => Chip(
                                    label: Text(
                                      tag,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: const Color.fromRGBO(
                                      25,
                                      55,
                                      109,
                                      0.1,
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Color.fromRGBO(25, 55, 109, 1),
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                                .toList(),
                      ),
                    ],

                    // Additional file info
                    const SizedBox(height: 16),
                    const Text(
                      'File Information:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'First Seen',
                      item['first_seen'] != null
                          ? _formatDate(item['first_seen'])
                          : 'Unknown',
                    ),
                    _buildInfoRow(
                      'Last Seen',
                      item['last_seen'] != null
                          ? _formatDate(item['last_seen'])
                          : 'Unknown',
                    ),
                    _buildInfoRow(
                      'Threat Category',
                      item['threat_category'] ?? 'Unknown',
                    ),
                  ],
                ),
              ),
            ],

            // View details button
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HashDetailScreen(hashData: item),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromRGBO(25, 55, 109, 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('VIEW FULL DETAILS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
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
      final now = DateTime.now();

      // Use relative time for recent dates
      if (date.isAfter(now.subtract(const Duration(days: 1)))) {
        return 'Today, ${DateFormat('h:mm a').format(date)}';
      } else if (date.isAfter(now.subtract(const Duration(days: 2)))) {
        return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
      } else if (date.isAfter(now.subtract(const Duration(days: 7)))) {
        return DateFormat('EEEE, h:mm a').format(date); // Day of week
      }

      // Use standard format for older dates
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      // Fallback for any parsing issues
      return isoDate.substring(0, 10);
    }
  }
}

// HashHistoryContent widget for use in tabs - reuses the same functionality
class HashHistoryContent extends StatefulWidget {
  const HashHistoryContent({super.key});

  @override
  State<HashHistoryContent> createState() => _HashHistoryContentState();
}

class _HashHistoryContentState extends State<HashHistoryContent> {
  @override
  Widget build(BuildContext context) {
    // Just a wrapper to open the full screen version
    return const HashHistoryScreen();
  }
}
