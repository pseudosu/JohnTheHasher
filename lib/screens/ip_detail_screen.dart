// lib/screens/ip_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class IpDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ipData;

  const IpDetailScreen({required this.ipData, super.key});

  @override
  State<IpDetailScreen> createState() => _IpDetailScreenState();
}

class _IpDetailScreenState extends State<IpDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final isMalicious = widget.ipData['detection_count'] > 0;
    final fullResults = jsonDecode(widget.ipData['full_results']);
    final attributes = fullResults['data']['attributes'];

    // Parse JSON fields
    final tagsList =
        widget.ipData['tags'] != null
            ? List<String>.from(jsonDecode(widget.ipData['tags']))
            : <String>[];

    final avLabels =
        widget.ipData['av_labels'] != null
            ? List<String>.from(jsonDecode(widget.ipData['av_labels']))
            : <String>[];

    final geoData =
        widget.ipData['geolocation'] != null
            ? Map<String, dynamic>.from(
              jsonDecode(widget.ipData['geolocation']),
            )
            : <String, dynamic>{};

    final whoisInfo =
        widget.ipData['whois_info'] != null
            ? Map<String, dynamic>.from(jsonDecode(widget.ipData['whois_info']))
            : <String, dynamic>{};

    final resolutions =
        widget.ipData['resolutions'] != null
            ? List<Map<String, dynamic>>.from(
              jsonDecode(widget.ipData['resolutions']),
            )
            : <Map<String, dynamic>>[];

    final isTorExitNode = widget.ipData['is_tor_exit_node'] == 1;
    final abuseScore = widget.ipData['abuse_score'] ?? 0;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'IP Address Details',
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'WHOIS'),
            Tab(text: 'DNS'),
            Tab(text: 'OSINT'),
          ],
        ),
        actions: [
          // Share button
          IconButton(
            onPressed: () => _shareIpReport(context),
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share IP Report',
          ),
          // Open in browser button
          IconButton(
            onPressed: () => _openInVT(context),
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            tooltip: 'Open in VirusTotal',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          _buildOverviewTab(isMalicious, widget.ipData, attributes, tagsList),

          // WHOIS Tab
          _buildWhoisTab(whoisInfo, attributes),

          // DNS Tab
          _buildDnsTab(resolutions),

          // OSINT Tab
          _buildOsintTab(geoData, isTorExitNode, abuseScore, avLabels),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    bool isMalicious,
    Map<String, dynamic> ipData,
    Map<String, dynamic> attributes,
    List<String> tagsList,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IP Information card
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
                        child: const Icon(Icons.language, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'IP Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              ipData['ip_address'] ?? 'Unknown IP',
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

                // IP details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Owner', ipData['as_owner'] ?? 'Unknown'),
                      _buildDetailRow(
                        'ASN',
                        ipData['asn']?.toString() ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'Country',
                        ipData['country'] ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'Continent',
                        ipData['continent'] ?? 'Unknown',
                      ),

                      if (attributes.containsKey('regional_internet_registry'))
                        _buildDetailRow(
                          'Registry',
                          attributes['regional_internet_registry'] ?? 'Unknown',
                        ),

                      const Divider(height: 24),

                      _buildDetailRow(
                        'Last Seen',
                        ipData['last_seen'] != null
                            ? DateTime.parse(
                              ipData['last_seen'],
                            ).toString().substring(0, 16)
                            : 'Unknown',
                      ),

                      _buildDetailRow(
                        'Scan Date',
                        ipData['timestamp'] != null
                            ? DateTime.parse(
                              ipData['timestamp'],
                            ).toString().substring(0, 16)
                            : 'Unknown',
                      ),

                      if (attributes.containsKey('reputation'))
                        _buildDetailRow(
                          'Reputation',
                          attributes['reputation']?.toString() ?? 'Unknown',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Detection results card
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isMalicious ? Icons.warning : Icons.check_circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detection Results',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              isMalicious
                                  ? 'Malicious: ${ipData['detection_ratio'] ?? '0/0'}'
                                  : 'Clean: ${ipData['detection_ratio'] ?? '0/0'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Detection stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'Malicious',
                            attributes['last_analysis_stats']['malicious'] ?? 0,
                            Colors.red,
                          ),
                          _buildStatColumn(
                            'Suspicious',
                            attributes['last_analysis_stats']['suspicious'] ??
                                0,
                            Colors.orange,
                          ),
                          _buildStatColumn(
                            'Clean',
                            attributes['last_analysis_stats']['harmless'] ?? 0,
                            Colors.green,
                          ),
                          _buildStatColumn(
                            'Undetected',
                            attributes['last_analysis_stats']['undetected'] ??
                                0,
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

          // Tags
          if (tagsList.isNotEmpty)
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
                          tagsList
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

  Widget _buildWhoisTab(
    Map<String, dynamic> whoisInfo,
    Map<String, dynamic> attributes,
  ) {
    // Extract WHOIS data directly from attributes if available
    Map<String, dynamic> extractedWhois = {};
    String rawWhois = '';

    // First try to get WHOIS data from attributes directly
    if (attributes.containsKey('whois') && attributes['whois'] != null) {
      rawWhois = attributes['whois'] as String;

      // Extract key WHOIS info using regular expressions
      final networkRegex = RegExp(r'NetRange:\s*(.*?)(?:\n|$)');
      final cidrRegex = RegExp(r'CIDR:\s*(.*?)(?:\n|$)');
      final netNameRegex = RegExp(r'NetName:\s*(.*?)(?:\n|$)');
      final orgRegex = RegExp(r'Organization:\s*(.*?)(?:\n|$)');
      final regDateRegex = RegExp(r'RegDate:\s*(.*?)(?:\n|$)');
      final updatedRegex = RegExp(r'Updated:\s*(.*?)(?:\n|$)');
      final adminOrgRegex = RegExp(r'OrgName:\s*(.*?)(?:\n|$)');
      final adminContactRegex = RegExp(r'OrgAbuseEmail:\s*(.*?)(?:\n|$)');
      final countryRegex = RegExp(r'Country:\s*(.*?)(?:\n|$)');
      final stateRegex = RegExp(r'StateProv:\s*(.*?)(?:\n|$)');
      final cityRegex = RegExp(r'City:\s*(.*?)(?:\n|$)');

      extractedWhois = {
        'Network Range': _getRegexMatch(networkRegex, rawWhois),
        'CIDR': _getRegexMatch(cidrRegex, rawWhois),
        'Network Name': _getRegexMatch(netNameRegex, rawWhois),
        'Organization':
            _getRegexMatch(orgRegex, rawWhois) ??
            _getRegexMatch(adminOrgRegex, rawWhois),
        'Registration Date': _getRegexMatch(regDateRegex, rawWhois),
        'Last Updated': _getRegexMatch(updatedRegex, rawWhois),
        'Admin Contact': _getRegexMatch(adminContactRegex, rawWhois),
        'Country': _getRegexMatch(countryRegex, rawWhois),
        'State/Province': _getRegexMatch(stateRegex, rawWhois),
        'City': _getRegexMatch(cityRegex, rawWhois),
      };

      // Remove null entries
      extractedWhois.removeWhere((key, value) => value == null);
    }

    // Also use any pre-extracted WHOIS info from the database
    if (whoisInfo.isNotEmpty) {
      extractedWhois.addAll(whoisInfo);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WHOIS Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              if (extractedWhois.isNotEmpty) ...[
                // Display all available WHOIS fields
                ...extractedWhois.entries
                    .where(
                      (entry) => entry.key != 'rawData' && entry.value != null,
                    )
                    .map(
                      (entry) => _buildDetailRow(
                        entry.key,
                        entry.value?.toString() ?? 'N/A',
                      ),
                    ),

                const Divider(height: 24),

                // Raw WHOIS data
                if (rawWhois.isNotEmpty) ...[
                  const Text(
                    'Raw WHOIS Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: SelectableText(
                      rawWhois,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Copy to clipboard button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawWhois));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('WHOIS data copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Raw Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No WHOIS information available',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Button to lookup WHOIS online
                Center(
                  child: ElevatedButton.icon(
                    onPressed:
                        () => _launchUrl(
                          'https://whois.domaintools.com/${widget.ipData['ip_address']}',
                        ),
                    icon: const Icon(Icons.search),
                    label: const Text('Lookup WHOIS Online'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _getRegexMatch(RegExp regex, String text) {
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount > 0) {
      return match.group(1)?.trim();
    }
    return null;
  }

  Widget _buildDnsTab(List<Map<String, dynamic>> resolutions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Domain Resolutions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (resolutions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(25, 55, 109, 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${resolutions.length} records',
                        style: const TextStyle(
                          color: Color.fromRGBO(25, 55, 109, 1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (resolutions.isNotEmpty) ...[
                // Create a data table for DNS records
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Value')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('TTL')),
                    ],
                    rows:
                        resolutions.map((resolution) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
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
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    resolution['type']?.toString() ?? 'A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SelectableText(
                                  resolution['value']?.toString() ?? 'Unknown',
                                ),
                              ),
                              DataCell(
                                Text(
                                  resolution.containsKey('date') &&
                                          resolution['date'] != null
                                      ? resolution['date'].toString().substring(
                                        0,
                                        10,
                                      )
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  resolution.containsKey('ttl') &&
                                          resolution['ttl'] != null
                                      ? resolution['ttl'].toString()
                                      : '-',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No domain resolution data available',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Button to lookup DNS info online
                Center(
                  child: ElevatedButton.icon(
                    onPressed:
                        () => _launchUrl(
                          'https://viewdns.info/reverseip/?host=${widget.ipData['ip_address']}&t=1',
                        ),
                    icon: const Icon(Icons.search),
                    label: const Text('Lookup DNS Records Online'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOsintTab(
    Map<String, dynamic> geoData,
    bool isTorExitNode,
    int abuseScore,
    List<String> avLabels,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Geolocation card
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
                    'Geolocation Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),

                  if (geoData.isNotEmpty) ...[
                    // Map in cards for each geo section with null checks
                    if (geoData['city'] != null &&
                        geoData['region'] != null) ...[
                      _buildInfoCard(
                        'Location',
                        Icons.location_city,
                        '${geoData['city']}, ${geoData['region']}',
                      ),
                    ],

                    if (geoData['country_name'] != null)
                      _buildInfoCard(
                        'Country',
                        Icons.flag,
                        geoData['country_name'].toString(),
                      ),

                    if (geoData['postal'] != null)
                      _buildInfoCard(
                        'Postal Code',
                        Icons.mail_outline,
                        geoData['postal'].toString(),
                      ),

                    if (geoData['org'] != null)
                      _buildInfoCard(
                        'Organization',
                        Icons.business,
                        geoData['org'].toString(),
                      ),

                    if (geoData['latitude'] != null &&
                        geoData['longitude'] != null)
                      _buildInfoCard(
                        'Coordinates',
                        Icons.my_location,
                        '${geoData['latitude']}, ${geoData['longitude']}',
                      ),

                    if (geoData['timezone'] != null)
                      _buildInfoCard(
                        'Timezone',
                        Icons.access_time,
                        geoData['timezone'].toString(),
                      ),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No geolocation data available',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Threat intel card
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
                    'Threat Intelligence',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),

                  // Tor Exit Node status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isTorExitNode
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTorExitNode ? Colors.orange : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isTorExitNode ? Icons.warning : Icons.check_circle,
                          color: isTorExitNode ? Colors.orange : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTorExitNode
                                    ? 'Tor Exit Node Detected'
                                    : 'Not a Tor Exit Node',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isTorExitNode
                                          ? Colors.orange
                                          : Colors.green,
                                ),
                              ),
                              Text(
                                isTorExitNode
                                    ? 'This IP address is a known Tor exit node, which may be used for anonymous traffic.'
                                    : 'This IP address is not listed as a Tor exit node.',
                                style: TextStyle(
                                  color:
                                      isTorExitNode
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // AbuseIPDB Score
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          abuseScore > 0
                              ? abuseScore > 50
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            abuseScore > 0
                                ? abuseScore > 50
                                    ? Colors.red
                                    : Colors.orange
                                : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          abuseScore > 0
                              ? abuseScore > 50
                                  ? Icons.dangerous
                                  : Icons.warning
                              : Icons.check_circle,
                          color:
                              abuseScore > 0
                                  ? abuseScore > 50
                                      ? Colors.red
                                      : Colors.orange
                                  : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AbuseIPDB Confidence Score: $abuseScore%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      abuseScore > 0
                                          ? abuseScore > 50
                                              ? Colors.red
                                              : Colors.orange
                                          : Colors.green,
                                ),
                              ),
                              Text(
                                abuseScore > 0
                                    ? 'This IP has been reported for abusive behavior.'
                                    : 'No abuse reports found for this IP address.',
                                style: TextStyle(
                                  color:
                                      abuseScore > 0
                                          ? abuseScore > 50
                                              ? Colors.red.shade800
                                              : Colors.orange.shade800
                                          : Colors.green.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detection engines
                  if (avLabels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Detected by:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...avLabels.map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(label)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons for further investigation
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
                    'Further Investigation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),

                  // Buttons to open external sites
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionButton(
                        'VirusTotal',
                        Icons.security,
                        () => _launchUrl(
                          'https://www.virustotal.com/gui/ip-address/${widget.ipData['ip_address']}',
                        ),
                      ),
                      _buildActionButton(
                        'AbuseIPDB',
                        Icons.block,
                        () => _launchUrl(
                          'https://www.abuseipdb.com/check/${widget.ipData['ip_address']}',
                        ),
                      ),
                      _buildActionButton(
                        'Shodan',
                        Icons.search,
                        () => _launchUrl(
                          'https://www.shodan.io/host/${widget.ipData['ip_address']}',
                        ),
                      ),
                      _buildActionButton(
                        'Talos',
                        Icons.shield,
                        () => _launchUrl(
                          'https://talosintelligence.com/reputation_center/lookup?search=${widget.ipData['ip_address']}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

  Widget _buildInfoCard(String title, IconData icon, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(25, 55, 109, 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromRGBO(25, 55, 109, 1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color.fromRGBO(25, 55, 109, 1),
                  ),
                ),
                SelectableText(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  void _shareIpReport(BuildContext context) {
    // Create a comprehensive summary report
    final StringBuffer report = StringBuffer();

    // Report header
    report.writeln('===== IP ADDRESS ANALYSIS REPORT =====');
    report.writeln('');

    // IP information
    report.writeln('IP INFORMATION:');
    report.writeln('IP Address: ${widget.ipData['ip_address']}');
    report.writeln('Owner: ${widget.ipData['as_owner'] ?? 'Unknown'}');
    report.writeln('ASN: ${widget.ipData['asn'] ?? 'Unknown'}');
    report.writeln('Country: ${widget.ipData['country'] ?? 'Unknown'}');
    report.writeln('Continent: ${widget.ipData['continent'] ?? 'Unknown'}');

    final fullResults = jsonDecode(widget.ipData['full_results']);
    final attributes = fullResults['data']['attributes'];

    if (attributes.containsKey('regional_internet_registry')) {
      report.writeln('Registry: ${attributes['regional_internet_registry']}');
    }

    // Get WHOIS data if available
    if (attributes.containsKey('whois') && attributes['whois'] != null) {
      final rawWhois = attributes['whois'] as String;
      final cidrRegex = RegExp(r'CIDR:\s*(.*?)(?:\n|$)');
      final cidrMatch = cidrRegex.firstMatch(rawWhois);
      if (cidrMatch != null && cidrMatch.groupCount > 0) {
        report.writeln('CIDR: ${cidrMatch.group(1)?.trim()}');
      }
    }

    // Detection information
    report.writeln('');
    report.writeln('SCAN RESULTS:');
    final stats = attributes['last_analysis_stats'];
    final totalEngines =
        (stats['malicious'] ?? 0) +
        (stats['undetected'] ?? 0) +
        (stats['suspicious'] ?? 0) +
        (stats['harmless'] ?? 0) +
        (stats['timeout'] ?? 0);

    report.writeln(
      'Detection Rate: ${stats['malicious'] ?? 0} of $totalEngines engines',
    );
    report.writeln(
      'Scan Status: ${(stats['malicious'] ?? 0) > 0 ? "MALICIOUS" : "CLEAN"}',
    );

    if (attributes.containsKey('reputation')) {
      report.writeln('Reputation: ${attributes['reputation']}');
    }

    // OSINT Information
    report.writeln('');
    report.writeln('ADDITIONAL INTELLIGENCE:');

    // Check if we have TOR data
    final isTorExitNode = widget.ipData['is_tor_exit_node'] == 1;
    report.writeln('Tor Exit Node: ${isTorExitNode ? "YES" : "NO"}');

    // Check if we have AbuseIPDB data
    final abuseScore = widget.ipData['abuse_score'] ?? 0;
    report.writeln('AbuseIPDB Score: $abuseScore%');

    // Timestamps
    report.writeln('');
    report.writeln('TIMELINE:');
    if (widget.ipData['last_seen'] != null) {
      report.writeln(
        'Last Analyzed: ${DateTime.parse(widget.ipData['last_seen']).toString().substring(0, 16)}',
      );
    }
    report.writeln(
      'Scan Date: ${DateTime.parse(widget.ipData['timestamp']).toString().substring(0, 16)}',
    );

    // Top detections
    final avLabels =
        widget.ipData['av_labels'] != null
            ? List<String>.from(jsonDecode(widget.ipData['av_labels']))
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
        widget.ipData['tags'] != null
            ? List<String>.from(jsonDecode(widget.ipData['tags']))
            : <String>[];

    if (tagsList.isNotEmpty) {
      report.writeln('');
      report.writeln('TAGS:');
      report.writeln(tagsList.join(', '));
    }

    // Geolocation data
    final geoData =
        widget.ipData['geolocation'] != null
            ? Map<String, dynamic>.from(
              jsonDecode(widget.ipData['geolocation']),
            )
            : <String, dynamic>{};

    if (geoData.isNotEmpty) {
      report.writeln('');
      report.writeln('GEOLOCATION:');
      if (geoData['city'] != null && geoData['region'] != null) {
        report.writeln('Location: ${geoData['city']}, ${geoData['region']}');
      }
      if (geoData['country_name'] != null) {
        report.writeln('Country: ${geoData['country_name']}');
      }
      if (geoData['org'] != null) {
        report.writeln('Organization: ${geoData['org']}');
      }
      if (geoData['latitude'] != null && geoData['longitude'] != null) {
        report.writeln(
          'Coordinates: ${geoData['latitude']}, ${geoData['longitude']}',
        );
      }
    }

    // Report footer
    report.writeln('');
    report.writeln('Report generated by John the Hasher');
    report.writeln(
      'Report date: ${DateTime.now().toString().substring(0, 16)}',
    );

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: report.toString()));

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('IP report copied to clipboard'),
        backgroundColor: Color.fromRGBO(25, 55, 109, 1),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open URL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openInVT(BuildContext context) {
    _launchUrl(
      'https://www.virustotal.com/gui/ip-address/${widget.ipData['ip_address']}',
    );
  }
}
