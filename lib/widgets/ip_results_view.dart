// lib/widgets/ip_results_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IpResultsView extends StatefulWidget {
  final Map<String, dynamic> results;
  final Map<String, dynamic>? osintData;

  const IpResultsView({required this.results, this.osintData, super.key});

  @override
  State<IpResultsView> createState() => _IpResultsViewState();
}

class _IpResultsViewState extends State<IpResultsView> {
  int _currentTabIndex = 0;
  final List<String> _tabs = ['Overview', 'WHOIS', 'Resolutions', 'OSINT'];

  @override
  Widget build(BuildContext context) {
    final attributes = widget.results['data']['attributes'];
    final stats = attributes['last_analysis_stats'] ?? {};
    final totalEngines =
        (stats['malicious'] ?? 0) +
        (stats['undetected'] ?? 0) +
        (stats['suspicious'] ?? 0) +
        (stats['harmless'] ?? 0) +
        (stats['timeout'] ?? 0);

    // Calculate detection percentage
    final detectionPercentage =
        totalEngines > 0
            ? ((stats['malicious'] ?? 0) / totalEngines * 100).toStringAsFixed(
              1,
            )
            : '0.0';

    // Get OSINT data
    final Map<String, dynamic> geoData =
        widget.osintData != null && widget.osintData!['geolocation'] != null
            ? Map<String, dynamic>.from(widget.osintData!['geolocation'])
            : <String, dynamic>{};
    final isTorExitNode = widget.osintData?['isTorExitNode'] ?? false;
    final abuseScore =
        widget.osintData?['abuseipdb']?['data']?['abuseConfidenceScore'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IP Information Section
        Row(
          children: [
            const Icon(Icons.language, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                'IP: ${attributes['network'] ?? widget.results['data']['id']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          'Owner: ${attributes['as_owner'] ?? 'Unknown'}',
          style: const TextStyle(color: Colors.white70),
        ),
        SelectableText(
          'Location: ${attributes['country'] ?? 'Unknown'}, ${attributes['continent'] ?? 'Unknown'}',
          style: const TextStyle(color: Colors.white70),
        ),

        const Divider(color: Colors.white30, height: 24),

        // Tab selector
        Container(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _currentTabIndex == index
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      color:
                          _currentTabIndex == index
                              ? Colors.white
                              : Colors.white70,
                      fontWeight:
                          _currentTabIndex == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Tab content
        IndexedStack(
          index: _currentTabIndex,
          children: [
            // Overview Tab
            _buildOverviewTab(stats, detectionPercentage, attributes),

            // WHOIS Tab
            _buildWhoisTab(attributes),

            // Resolutions Tab
            _buildResolutionsTab(attributes),

            // OSINT Tab
            _buildOsintTab(geoData, isTorExitNode, abuseScore),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewTab(
    Map<String, dynamic> stats,
    String detectionPercentage,
    Map<String, dynamic> attributes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detection Summary Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                (stats['malicious'] ?? 0) > 0
                    ? Colors.red.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (stats['malicious'] ?? 0) > 0 ? Colors.red : Colors.green,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    (stats['malicious'] ?? 0) > 0
                        ? Icons.warning
                        : Icons.check_circle,
                    color:
                        (stats['malicious'] ?? 0) > 0
                            ? Colors.red
                            : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'Detection Rate: $detectionPercentage% (${stats['malicious'] ?? 0} engines)',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            (stats['malicious'] ?? 0) > 0
                                ? Colors.red
                                : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              if (attributes.containsKey('reputation')) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'Reputation: ${attributes['reputation']}',
                  style: TextStyle(
                    color:
                        (stats['malicious'] ?? 0) > 0
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Detection Stats
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatIndicator(
                'Malicious',
                stats['malicious'] ?? 0,
                Colors.red,
              ),
              _buildStatIndicator(
                'Suspicious',
                stats['suspicious'] ?? 0,
                Colors.orange,
              ),
              _buildStatIndicator(
                'Clean',
                stats['harmless'] ?? 0,
                Colors.green,
              ),
              _buildStatIndicator(
                'Undetected',
                stats['undetected'] ?? 0,
                Colors.grey,
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white30, height: 24),

        // Network Information
        if (attributes.containsKey('asn')) ...[
          Row(
            children: [
              const Icon(Icons.router, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  'ASN: ${attributes['asn']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        if (attributes.containsKey('regional_internet_registry')) ...[
          Row(
            children: [
              const Icon(Icons.public, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  'Registry: ${attributes['regional_internet_registry']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],

        if (attributes.containsKey('last_analysis_date')) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.update, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  'Last analyzed: ${DateTime.fromMillisecondsSinceEpoch(attributes['last_analysis_date'] * 1000).toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],

        // Top detections (AV results)
        if (attributes.containsKey('last_analysis_results')) ...[
          const SizedBox(height: 16),
          const Text(
            'Top Detections:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // Get malicious detections
          ...(() {
            final results = attributes['last_analysis_results'];
            final maliciousDetections = <Widget>[];

            int count = 0;
            results.forEach((engine, result) {
              if (result['category'] == 'malicious' &&
                  result['result'] != null &&
                  count < 5) {
                maliciousDetections.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.security, color: Colors.red, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            '$engine: ${result['result']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                count++;
              }
            });

            return maliciousDetections;
          })(),
        ],

        // Tags
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
                  label: SelectableText(
                    tag,
                    style: const TextStyle(color: Colors.black),
                  ),
                  backgroundColor: Colors.white24,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWhoisTab(Map<String, dynamic> attributes) {
    // Parse WHOIS data
    String rawWhois = '';
    Map<String, dynamic> parsedWhois = {};

    if (attributes.containsKey('whois')) {
      rawWhois = attributes['whois'] as String;
      // Basic parsing of common WHOIS fields
      final registrarMatch = RegExp(
        r'Registrar:\s*(.*?)(?:\n|$)',
      ).firstMatch(rawWhois);
      final orgMatch = RegExp(
        r'Registrant Organization:\s*(.*?)(?:\n|$)',
      ).firstMatch(rawWhois);
      final creationDateMatch = RegExp(
        r'Creation Date:\s*(.*?)(?:\n|$)',
      ).firstMatch(rawWhois);
      final updatedDateMatch = RegExp(
        r'Updated Date:\s*(.*?)(?:\n|$)',
      ).firstMatch(rawWhois);
      final expiryDateMatch = RegExp(
        r'Registry Expiry Date:\s*(.*?)(?:\n|$)',
      ).firstMatch(rawWhois);
      final nameServerMatch = RegExp(
        r'Name Server:\s*(.*?)(?:\n|$)',
      ).firstMatch(rawWhois);

      parsedWhois = {
        'Registrar': registrarMatch?.group(1)?.trim(),
        'Organization': orgMatch?.group(1)?.trim(),
        'Creation Date': creationDateMatch?.group(1)?.trim(),
        'Updated Date': updatedDateMatch?.group(1)?.trim(),
        'Expiry Date': expiryDateMatch?.group(1)?.trim(),
        'Name Server': nameServerMatch?.group(1)?.trim(),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WHOIS Information',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),

        if (parsedWhois.isNotEmpty) ...[
          // Display parsed WHOIS data
          ...parsedWhois.entries
              .where((entry) => entry.value != null)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          '${entry.key}:',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value ?? 'N/A',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          const SizedBox(height: 16),

          // Option to view raw WHOIS data
          ExpansionTile(
            title: const Text(
              'View Raw WHOIS Data',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            collapsedIconColor: Colors.white,
            iconColor: Colors.white,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  rawWhois,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const Text(
            'No WHOIS data available',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ],
    );
  }

  Widget _buildResolutionsTab(Map<String, dynamic> attributes) {
    // Parse domain resolutions
    List<Map<String, dynamic>> resolutions = [];

    if (attributes.containsKey('last_dns_records')) {
      for (var record in attributes['last_dns_records']) {
        resolutions.add({
          'type': record['type'],
          'value': record['value'],
          'ttl': record['ttl'],
        });
      }
    }

    if (attributes.containsKey('last_dns_records_date')) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        attributes['last_dns_records_date'] * 1000,
      );
      resolutions = resolutions.map((r) => {...r, 'date': date}).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Domain Resolutions',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (resolutions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${resolutions.length} records',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (resolutions.isNotEmpty) ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: resolutions.length.clamp(0, 10), // Limit to 10 items
            itemBuilder: (context, index) {
              final resolution = resolutions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type and Value
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resolution['type'] ?? 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            resolution['value'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Date and TTL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (resolution.containsKey('ttl'))
                          Text(
                            'TTL: ${resolution['ttl']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        if (resolution.containsKey('date'))
                          Text(
                            'Observed: ${resolution['date'].toString().substring(0, 10)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Show "View More" button if there are more than 10 records
          if (resolutions.length > 10)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // Show dialog with all resolutions
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('All Domain Resolutions'),
                          content: Container(
                            width: double.maxFinite,
                            height: 400,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: resolutions.length,
                              itemBuilder: (context, index) {
                                final resolution = resolutions[index];
                                return ListTile(
                                  title: Text(resolution['value'] ?? 'Unknown'),
                                  subtitle: Text(
                                    'Type: ${resolution['type']} - TTL: ${resolution['ttl']}',
                                  ),
                                  trailing:
                                      resolution.containsKey('date')
                                          ? Text(
                                            resolution['date']
                                                .toString()
                                                .substring(0, 10),
                                          )
                                          : null,
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                },
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                label: const Text(
                  'View All Resolutions',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ] else ...[
          const Text(
            'No domain resolution data available',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ],
    );
  }

  Widget _buildOsintTab(
    Map<String, dynamic> geoData,
    bool isTorExitNode,
    int abuseScore,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Geolocation Information
        const Text(
          'Geolocation Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),

        if (geoData.isNotEmpty) ...[
          // City and Region
          if (geoData.containsKey('city') && geoData.containsKey('region')) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_city,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    '${geoData['city']}, ${geoData['region']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Country
          if (geoData.containsKey('country_name')) ...[
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'Country: ${geoData['country_name']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Postal
          if (geoData.containsKey('postal')) ...[
            Row(
              children: [
                const Icon(Icons.mail_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'Postal Code: ${geoData['postal']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // ISP
          if (geoData.containsKey('org')) ...[
            Row(
              children: [
                const Icon(Icons.business, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'Organization: ${geoData['org']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Coordinates
          if (geoData.containsKey('latitude') &&
              geoData.containsKey('longitude')) ...[
            Row(
              children: [
                const Icon(Icons.my_location, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'Coordinates: ${geoData['latitude']}, ${geoData['longitude']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Time Zone
          if (geoData.containsKey('timezone')) ...[
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'Timezone: ${geoData['timezone']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ] else ...[
          const Text(
            'No detailed geolocation data available',
            style: TextStyle(color: Colors.white70),
          ),
        ],

        const Divider(color: Colors.white30, height: 24),

        // Additional Risk Indicators Section
        const Text(
          'Risk Indicators',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),

        // Tor Exit Node
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isTorExitNode
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isTorExitNode ? Icons.warning : Icons.check_circle,
                color: isTorExitNode ? Colors.orange : Colors.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  isTorExitNode
                      ? 'This IP is a Tor exit node'
                      : 'This IP is not a Tor exit node',
                  style: TextStyle(
                    color: isTorExitNode ? Colors.orange : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // AbuseIPDB Score
        if (abuseScore > 0) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  abuseScore > 50
                      ? Colors.red.withOpacity(0.2)
                      : abuseScore > 25
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.yellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  abuseScore > 50
                      ? Icons.dangerous
                      : abuseScore > 25
                      ? Icons.warning
                      : Icons.info_outline,
                  color:
                      abuseScore > 50
                          ? Colors.red
                          : abuseScore > 25
                          ? Colors.orange
                          : Colors.yellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'AbuseIPDB Confidence Score: $abuseScore%',
                    style: TextStyle(
                      color:
                          abuseScore > 50
                              ? Colors.red
                              : abuseScore > 25
                              ? Colors.orange
                              : Colors.yellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'No abuse reports found',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
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
          child: SelectableText(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white)),
      ],
    );
  }
}
