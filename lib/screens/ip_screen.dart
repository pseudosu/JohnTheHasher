// lib/screens/ip_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:myapp/services/virus_total_ip_service.dart';
import 'package:myapp/services/osint_service.dart';
import 'package:myapp/helpers/database_helper.dart';
import 'package:myapp/widgets/ip_history_screen.dart';
import 'package:myapp/widgets/ip_input_form.dart';
import 'package:myapp/widgets/ip_results_view.dart';

class IpScreen extends StatefulWidget {
  const IpScreen({super.key});

  @override
  State<IpScreen> createState() => _IpScreenState();
}

class _IpScreenState extends State<IpScreen> {
  final TextEditingController _ipController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  Map<String, dynamic>? _osintData;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _submitIp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _osintData = null;
    });

    try {
      final ipAddress = _ipController.text.trim();

      // Get VirusTotal data
      final results = await VirusTotalIpService.checkIp(ipAddress);

      // Get WHOIS data
      Map<String, dynamic>? whoisData;
      try {
        whoisData = await VirusTotalIpService.getWhoisData(ipAddress);
      } catch (e) {
        // WHOIS data is optional, so continue if it fails
        print('Error getting WHOIS data: $e');
      }

      // Get OSINT data in parallel
      final osintData = await _collectOsintData(ipAddress);

      // Save to database with OSINT data
      await DatabaseHelper.instance.insertIp(
        ipAddress,
        results,
        osintData: osintData,
      );

      setState(() {
        _results = results;
        _osintData = osintData;
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

  Future<Map<String, dynamic>> _collectOsintData(String ipAddress) async {
    final Map<String, dynamic> osintData = {};

    // Get geolocation data with fallback
    try {
      print('Fetching geolocation data for IP: $ipAddress');
      var geoData = await OSINTService.getIpGeolocation(ipAddress);

      // If primary source fails, try alternative
      if (geoData.containsKey('error') || geoData.isEmpty) {
        print('Primary geolocation failed, trying alternative source');
        geoData = await OSINTService.getIpGeolocationAlternative(ipAddress);
      }

      print('Final geolocation data: $geoData');
      osintData['geolocation'] = geoData;
    } catch (e) {
      print('Error getting geolocation data: $e');
      osintData['geolocation'] = OSINTService.getFallbackGeolocation();
    }

    // Check if IP is a Tor exit node
    try {
      final isTorExitNode = await OSINTService.checkTorExitNode(ipAddress);
      osintData['isTorExitNode'] = isTorExitNode;
    } catch (e) {
      print('Error checking Tor exit node: $e');
      osintData['isTorExitNode'] = false;
    }

    // Check AbuseIPDB
    try {
      final abuseData = await OSINTService.checkAbuseIPDB(ipAddress);
      osintData['abuseipdb'] = abuseData;
    } catch (e) {
      print('Error checking AbuseIPDB: $e');
      osintData['abuseipdb'] = {
        'data': {'abuseConfidenceScore': 0},
      };
    }

    print('Collected OSINT data: $osintData');
    return osintData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(240, 245, 249, 1),
      appBar: AppBar(
        title: const Text(
          'IP Address Lookup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(25, 55, 109, 1),
        elevation: 4,
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const IpHistoryScreen()),
            );
          },
          icon: const Icon(Icons.history, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Input form card
            IpInputForm(
              ipController: _ipController,
              formKey: _formKey,
              isLoading: _isLoading,
              onSubmit: _submitIp,
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
                  child: IpResultsView(
                    results: _results!,
                    osintData: _osintData,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Content widget for use in tabs
class IpScreenContent extends StatefulWidget {
  const IpScreenContent({super.key});

  @override
  State<IpScreenContent> createState() => _IpScreenContentState();
}

class _IpScreenContentState extends State<IpScreenContent> {
  final TextEditingController _ipController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  Map<String, dynamic>? _osintData;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _submitIp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _osintData = null;
    });

    try {
      final ipAddress = _ipController.text.trim();

      // Get VirusTotal data
      final results = await VirusTotalIpService.checkIp(ipAddress);

      // Get WHOIS data
      Map<String, dynamic>? whoisData;
      try {
        whoisData = await VirusTotalIpService.getWhoisData(ipAddress);
      } catch (e) {
        // WHOIS data is optional, so continue if it fails
        print('Error getting WHOIS data: $e');
      }

      // Get OSINT data in parallel
      final osintData = await _collectOsintData(ipAddress);

      // Save to database with OSINT data
      await DatabaseHelper.instance.insertIp(
        ipAddress,
        results,
        osintData: osintData,
      );

      setState(() {
        _results = results;
        _osintData = osintData;
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

  Future<Map<String, dynamic>> _collectOsintData(String ipAddress) async {
    final Map<String, dynamic> osintData = {};

    // Get geolocation data with multiple sources
    try {
      print('Fetching geolocation data for IP: $ipAddress');
      var geoData = await OSINTService.getIpGeolocation(ipAddress);

      // Check if primary API returned useful data
      if (isEmptyGeolocationData(geoData)) {
        print(
          'Primary geolocation returned limited data, trying alternative...',
        );
        // Small delay to avoid hitting rate limits
        await Future.delayed(Duration(milliseconds: 500));

        // Try alternative source
        var alternativeGeoData = await OSINTService.getIpGeolocationAlternative(
          ipAddress,
        );

        // Use the alternative data if it's better than the primary data
        if (!isEmptyGeolocationData(alternativeGeoData)) {
          geoData = alternativeGeoData;
        }
      }

      print('Final geolocation data: $geoData');
      osintData['geolocation'] = geoData;
    } catch (e) {
      print('Error getting geolocation data: $e');
      osintData['geolocation'] = OSINTService.getFallbackGeolocation();
    }

    // Check if IP is a Tor exit node
    try {
      final isTorExitNode = await OSINTService.checkTorExitNode(ipAddress);
      osintData['isTorExitNode'] = isTorExitNode;
    } catch (e) {
      print('Error checking Tor exit node: $e');
      osintData['isTorExitNode'] = false;
    }

    // Check AbuseIPDB
    try {
      final abuseData = await OSINTService.checkAbuseIPDB(ipAddress);
      osintData['abuseipdb'] = abuseData;
    } catch (e) {
      print('Error checking AbuseIPDB: $e');
      osintData['abuseipdb'] = {
        'data': {'abuseConfidenceScore': 0},
      };
    }

    print('Collected OSINT data: $osintData');
    return osintData;
  }

  bool isEmptyGeolocationData(Map<String, dynamic> geoData) {
    // Check if the data is empty, has an error flag, or is missing critical fields
    return geoData.isEmpty ||
        geoData.containsKey('error') && geoData['error'] == true ||
        (geoData['city'] == null &&
            geoData['region'] == null &&
            geoData['country_name'] == null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Input form card
          IpInputForm(
            ipController: _ipController,
            formKey: _formKey,
            isLoading: _isLoading,
            onSubmit: _submitIp,
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
                child: IpResultsView(results: _results!, osintData: _osintData),
              ),
            ),
        ],
      ),
    );
  }
}
