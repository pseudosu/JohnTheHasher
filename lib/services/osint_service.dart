// lib/services/osint_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OSINTService {
  // Get Geolocation data with improved error handling and debugging
  static Future<Map<String, dynamic>> getIpGeolocation(String ipAddress) async {
    try {
      // Use ip-api.com as primary source (has higher rate limits)
      print('Making API request to ip-api.com for IP: $ipAddress');
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/$ipAddress'),
      );

      print('ip-api.com response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully decoded geolocation JSON from ip-api.com: $data');

        // Enhance the data with our country/continent information
        String countryCode = data['countryCode'];

        // Map the response to match our expected format with enhanced data
        return {
          'ip': ipAddress,
          'city': data['city'],
          'region': data['regionName'],
          'country_code': countryCode,
          'country_name': getCountryNameFromCode(
            countryCode,
          ), // Use our method for full country name
          'continent': getContinentFromCountryCode(
            countryCode,
          ), // Use our method for continent
          'latitude': data['lat'],
          'longitude': data['lon'],
          'timezone': data['timezone'],
          'org': data['isp'],
          'postal': data['zip'],
        };
      } else {
        print(
          'Failed to get geolocation data from ip-api.com: ${response.statusCode}',
        );
        // Try the alternative source
        return getIpGeolocationAlternative(ipAddress);
      }
    } catch (e) {
      print('Exception during geolocation lookup from ip-api.com: $e');
      return getIpGeolocationAlternative(ipAddress);
    }
  }

  // Alternative geolocation service
  static Future<Map<String, dynamic>> getIpGeolocationAlternative(
    String ipAddress,
  ) async {
    try {
      // Try ipinfo.io as an alternative
      print('Making API request to ipinfo.io for IP: $ipAddress');
      final response = await http.get(
        Uri.parse('https://ipinfo.io/$ipAddress/json'),
      );

      print('ipinfo.io response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully decoded ipinfo.io geolocation data: $data');

        // Split the loc field which contains "latitude,longitude"
        List<String> coordinates = ['0', '0'];
        if (data.containsKey('loc') && data['loc'] is String) {
          coordinates = data['loc'].split(',');
        }

        // Extract country code for enhanced data
        String countryCode = data['country'] ?? 'XX';

        // Map the response to match our expected format with enhanced data
        return {
          'ip': data['ip'],
          'city': data['city'] ?? 'Unknown',
          'region': data['region'] ?? 'Unknown',
          'country_code': countryCode,
          'country_name': getCountryNameFromCode(
            countryCode,
          ), // Use our method for full country name
          'continent': getContinentFromCountryCode(
            countryCode,
          ), // Use our method for continent
          'latitude':
              coordinates.length > 0
                  ? double.tryParse(coordinates[0]) ?? 0.0
                  : 0.0,
          'longitude':
              coordinates.length > 1
                  ? double.tryParse(coordinates[1]) ?? 0.0
                  : 0.0,
          'timezone': data['timezone'] ?? 'Unknown',
          'org': data['org'] ?? 'Unknown',
          'postal': data['postal'] ?? 'Unknown',
        };
      } else {
        print(
          'Failed to get geolocation data from ipinfo.io: ${response.statusCode}',
        );
        // If both sources fail, use a fallback
        return getFallbackGeolocation();
      }
    } catch (e) {
      print('Exception during ipinfo.io geolocation lookup: $e');
      return getFallbackGeolocation();
    }
  }

  // Fetch DNS records
  static Future<List<Map<String, dynamic>>> getDnsRecords(
    String ipAddress,
  ) async {
    try {
      print('Fetching DNS records for IP: $ipAddress');
      // Use Google's DNS API
      final response = await http.get(
        Uri.parse('https://dns.google/resolve?name=$ipAddress&type=A'),
      );

      print('DNS API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> records = [];

        if (data.containsKey('Answer') && data['Answer'] is List) {
          for (var record in data['Answer']) {
            records.add({
              'type': _dnsTypeToString(record['type']),
              'value': record['data'],
              'ttl': record['TTL'],
              'date': DateTime.now(),
            });
          }
        }

        print('Found ${records.length} DNS records');
        return records;
      } else {
        print('Failed to get DNS records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception during DNS record lookup: $e');
      return [];
    }
  }

  // Alternative DNS lookup
  static Future<List<Map<String, dynamic>>> getDnsRecordsAlternative(
    String ipAddress,
  ) async {
    try {
      print('Fetching DNS records from alternative source for IP: $ipAddress');

      // Use reverse DNS lookup to get hostnames associated with this IP
      final response = await http.get(
        Uri.parse(
          'https://dns.cloudflare.com/dns-query?name=$ipAddress&type=PTR',
        ),
        headers: {'Accept': 'application/dns-json'},
      );

      print('Alternative DNS API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> records = [];

        if (data.containsKey('Answer') && data['Answer'] is List) {
          for (var record in data['Answer']) {
            records.add({
              'type': 'PTR',
              'value': record['data'],
              'ttl': record['TTL'],
              'date': DateTime.now(),
            });
          }
        }

        print('Found ${records.length} DNS records from alternative source');
        return records;
      } else {
        print('Failed to get alternative DNS records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception during alternative DNS record lookup: $e');
      return [];
    }
  }

  // Helper method to convert DNS type numbers to readable strings
  static String _dnsTypeToString(int type) {
    const Map<int, String> dnsTypes = {
      1: 'A',
      2: 'NS',
      5: 'CNAME',
      6: 'SOA',
      12: 'PTR',
      15: 'MX',
      16: 'TXT',
      28: 'AAAA',
      33: 'SRV',
      65: 'HTTPS',
    };

    return dnsTypes[type] ?? 'Unknown';
  }

  // Public fallback method for geolocation
  static Map<String, dynamic> getFallbackGeolocation() {
    return {
      'ip': 'Unknown',
      'city': 'Unknown',
      'region': 'Unknown',
      'country_code': 'XX',
      'country_name': 'Unknown',
      'continent': 'Unknown',
      'latitude': 0.0,
      'longitude': 0.0,
      'timezone': 'Unknown',
      'org': 'Unknown',
      'postal': 'Unknown',
    };
  }

  // Check for IP in known blocklists (AbuseIPDB)
  static Future<Map<String, dynamic>> checkAbuseIPDB(String ipAddress) async {
    try {
      // Check if API key is available
      final apiKey = dotenv.env['ABUSEIPDB_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('AbuseIPDB API key not found in .env file');
        return {
          'error': 'API key not found',
          'data': {'abuseConfidenceScore': 0},
        };
      }

      final response = await http.get(
        Uri.parse(
          'https://api.abuseipdb.com/api/v2/check?ipAddress=$ipAddress',
        ),
        headers: {'Key': apiKey, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('AbuseIPDB response successful');
        return jsonDecode(response.body);
      } else {
        print('Failed to check AbuseIPDB: ${response.statusCode}');
        return {
          'error': response.statusCode.toString(),
          'data': {'abuseConfidenceScore': 0},
        };
      }
    } catch (e) {
      print('Exception during AbuseIPDB check: $e');
      return {
        'error': e.toString(),
        'data': {'abuseConfidenceScore': 0},
      };
    }
  }

  // Check if IP is in Tor exit node list
  static Future<bool> checkTorExitNode(String ipAddress) async {
    try {
      final response = await http.get(
        Uri.parse('https://check.torproject.org/exit-addresses'),
      );

      if (response.statusCode == 200) {
        final exitNodes = response.body.split('\n');
        for (var line in exitNodes) {
          if (line.contains('ExitAddress') && line.contains(ipAddress)) {
            print('IP identified as Tor exit node');
            return true;
          }
        }
        return false;
      } else {
        print('Failed to check Tor exit nodes: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception during Tor exit node check: $e');
      return false;
    }
  }

  // Parse and extract WHOIS information
  static Map<String, String> parseWhoisData(String rawWhois) {
    final Map<String, String> result = {};

    // Common WHOIS fields to extract
    final fieldsToExtract = {
      'Registrar': RegExp(r'Registrar:\s*(.*?)(?:\n|$)'),
      'Organization': RegExp(r'Registrant Organization:\s*(.*?)(?:\n|$)'),
      'Country': RegExp(r'Registrant Country:\s*(.*?)(?:\n|$)'),
      'Creation Date': RegExp(r'Creation Date:\s*(.*?)(?:\n|$)'),
      'Updated Date': RegExp(r'Updated Date:\s*(.*?)(?:\n|$)'),
      'Expiration Date': RegExp(r'Registry Expiry Date:\s*(.*?)(?:\n|$)'),
      'Name Servers': RegExp(r'Name Server:\s*(.*?)(?:\n|$)'),
      'CIDR': RegExp(r'CIDR:\s*(.*?)(?:\n|$)'),
      'NetRange': RegExp(r'NetRange:\s*(.*?)(?:\n|$)'),
      'NetName': RegExp(r'NetName:\s*(.*?)(?:\n|$)'),
    };

    for (var field in fieldsToExtract.entries) {
      final match = field.value.firstMatch(rawWhois);
      if (match != null && match.groupCount > 0) {
        result[field.key] = match.group(1)!.trim();
      }
    }

    // Extract all name servers
    final nameServerMatches = RegExp(
      r'Name Server:\s*(.*?)(?:\n|$)',
    ).allMatches(rawWhois);
    if (nameServerMatches.isNotEmpty) {
      final nameServers =
          nameServerMatches
              .map((match) => match.group(1)?.trim() ?? '')
              .where((server) => server.isNotEmpty)
              .toList();
      result['Name Servers'] = nameServers.join(', ');
    }

    return result;
  }

  /// Gets the continent name from a country code
  static String getContinentFromCountryCode(String countryCode) {
    // Map of country codes to continent codes
    final Map<String, String> countryToContinentCode = {
      // North America
      'US': 'NA',
      'CA': 'NA',
      'MX': 'NA',
      'GT': 'NA',
      'BZ': 'NA',
      'SV': 'NA',
      'HN': 'NA',
      'NI': 'NA',
      'CR': 'NA',
      'PA': 'NA',
      'BS': 'NA',
      'CU': 'NA',
      'JM': 'NA',
      'HT': 'NA',
      'DO': 'NA',
      'PR': 'NA',
      'BM': 'NA',
      'BB': 'NA',
      'DM': 'NA',
      'GP': 'NA',
      'LC': 'NA',
      'MQ': 'NA', 'PM': 'NA', 'TT': 'NA', 'GL': 'NA',

      // South America
      'BR': 'SA',
      'AR': 'SA',
      'CL': 'SA',
      'CO': 'SA',
      'PE': 'SA',
      'VE': 'SA',
      'EC': 'SA',
      'BO': 'SA',
      'PY': 'SA',
      'UY': 'SA',
      'GY': 'SA',
      'SR': 'SA',
      'GF': 'SA',
      'FK': 'SA',

      // Europe
      'GB': 'EU',
      'DE': 'EU',
      'FR': 'EU',
      'IT': 'EU',
      'ES': 'EU',
      'UA': 'EU',
      'PL': 'EU',
      'RO': 'EU',
      'NL': 'EU',
      'BE': 'EU',
      'GR': 'EU',
      'CZ': 'EU',
      'PT': 'EU',
      'SE': 'EU',
      'HU': 'EU',
      'BY': 'EU',
      'AT': 'EU',
      'CH': 'EU',
      'BG': 'EU',
      'DK': 'EU',
      'FI': 'EU',
      'SK': 'EU',
      'NO': 'EU',
      'IE': 'EU',
      'HR': 'EU',
      'MD': 'EU',
      'BA': 'EU',
      'AL': 'EU',
      'LT': 'EU',
      'MK': 'EU',
      'SI': 'EU',
      'LV': 'EU',
      'EE': 'EU',
      'CY': 'EU',
      'LU': 'EU',
      'MT': 'EU',
      'IS': 'EU',
      'AD': 'EU',
      'MC': 'EU',
      'LI': 'EU',
      'SM': 'EU',
      'VA': 'EU',
      'RS': 'EU', 'ME': 'EU', 'XK': 'EU',

      // Asia
      'CN': 'AS',
      'IN': 'AS',
      'ID': 'AS',
      'PK': 'AS',
      'BD': 'AS',
      'JP': 'AS',
      'PH': 'AS',
      'VN': 'AS',
      'TR': 'AS',
      'IR': 'AS',
      'TH': 'AS',
      'KR': 'AS',
      'IQ': 'AS',
      'AF': 'AS',
      'SA': 'AS',
      'MY': 'AS',
      'UZ': 'AS',
      'NP': 'AS',
      'YE': 'AS',
      'KP': 'AS',
      'SY': 'AS',
      'MM': 'AS',
      'KZ': 'AS',
      'AZ': 'AS',
      'AE': 'AS',
      'LK': 'AS',
      'TJ': 'AS',
      'HK': 'AS',
      'IL': 'AS',
      'JO': 'AS',
      'LB': 'AS',
      'SG': 'AS',
      'OM': 'AS',
      'KW': 'AS',
      'GE': 'AS',
      'MN': 'AS',
      'AM': 'AS',
      'QA': 'AS',
      'BH': 'AS',
      'TL': 'AS',
      'BN': 'AS',
      'MO': 'AS',
      'BT': 'AS', 'MV': 'AS', 'KG': 'AS', 'TM': 'AS', 'PS': 'AS',

      // Africa
      'NG': 'AF',
      'ET': 'AF',
      'EG': 'AF',
      'CD': 'AF',
      'ZA': 'AF',
      'TZ': 'AF',
      'KE': 'AF',
      'SD': 'AF',
      'DZ': 'AF',
      'MA': 'AF',
      'UG': 'AF',
      'GH': 'AF',
      'MZ': 'AF',
      'ZM': 'AF',
      'MG': 'AF',
      'AO': 'AF',
      'CI': 'AF',
      'CM': 'AF',
      'NE': 'AF',
      'ML': 'AF',
      'MW': 'AF',
      'SN': 'AF',
      'TN': 'AF',
      'SO': 'AF',
      'ZW': 'AF',
      'SS': 'AF',
      'RW': 'AF',
      'GN': 'AF',
      'BJ': 'AF',
      'BI': 'AF',
      'TD': 'AF',
      'LY': 'AF',
      'SL': 'AF',
      'TG': 'AF',
      'MR': 'AF',
      'ER': 'AF',
      'LR': 'AF',
      'CF': 'AF',
      'CG': 'AF',
      'GA': 'AF',
      'GM': 'AF',
      'SZ': 'AF',
      'DJ': 'AF',
      'GW': 'AF',
      'LS': 'AF',
      'NA': 'AF',
      'BW': 'AF',
      'EH': 'AF',
      'CV': 'AF',
      'ST': 'AF', 'SC': 'AF', 'KM': 'AF', 'MU': 'AF', 'RE': 'AF', 'YT': 'AF',

      // Oceania
      'AU': 'OC',
      'PG': 'OC',
      'NZ': 'OC',
      'FJ': 'OC',
      'SB': 'OC',
      'FM': 'OC',
      'VU': 'OC',
      'WS': 'OC',
      'KI': 'OC',
      'TO': 'OC',
      'TV': 'OC',
      'NR': 'OC',
      'MH': 'OC',
      'PW': 'OC',
      'CK': 'OC',
      'NU': 'OC',
      'TK': 'OC',
      'GU': 'OC',
      'MP': 'OC',
      'AS': 'OC',
      'NC': 'OC',
      'PF': 'OC', 'WF': 'OC',

      // Antarctica
      'AQ': 'AN',
    };

    // Map of continent codes to full names
    final Map<String, String> continentNames = {
      'AF': 'Africa',
      'AN': 'Antarctica',
      'AS': 'Asia',
      'EU': 'Europe',
      'NA': 'North America',
      'OC': 'Oceania',
      'SA': 'South America',
    };

    // Normalize country code
    final String normalizedCode = countryCode.trim().toUpperCase();

    // Get continent code
    final String continentCode =
        countryToContinentCode[normalizedCode] ?? 'Unknown';

    // Return continent name
    return continentNames[continentCode] ?? 'Unknown';
  }

  /// Gets country name from country code
  static String getCountryNameFromCode(String countryCode) {
    // Map of country codes to country names
    final Map<String, String> countryNames = {
      // North America
      'US': 'United States',
      'CA': 'Canada',
      'MX': 'Mexico',
      'GT': 'Guatemala',
      'BZ': 'Belize',
      'SV': 'El Salvador',
      'HN': 'Honduras',
      'NI': 'Nicaragua',
      'CR': 'Costa Rica',
      'PA': 'Panama',
      'BS': 'Bahamas',
      'CU': 'Cuba',
      'JM': 'Jamaica',
      'HT': 'Haiti',
      'DO': 'Dominican Republic',
      'PR': 'Puerto Rico',
      'BM': 'Bermuda',
      'BB': 'Barbados',
      'DM': 'Dominica',
      'GP': 'Guadeloupe',
      'LC': 'Saint Lucia',
      'MQ': 'Martinique',
      'PM': 'Saint Pierre and Miquelon',
      'TT': 'Trinidad and Tobago',
      'GL': 'Greenland',

      // South America
      'BR': 'Brazil',
      'AR': 'Argentina',
      'CL': 'Chile',
      'CO': 'Colombia',
      'PE': 'Peru',
      'VE': 'Venezuela',
      'EC': 'Ecuador',
      'BO': 'Bolivia',
      'PY': 'Paraguay',
      'UY': 'Uruguay',
      'GY': 'Guyana',
      'SR': 'Suriname',
      'GF': 'French Guiana',
      'FK': 'Falkland Islands',

      // Europe
      'GB': 'United Kingdom',
      'DE': 'Germany',
      'FR': 'France',
      'IT': 'Italy',
      'ES': 'Spain',
      'UA': 'Ukraine',
      'PL': 'Poland',
      'RO': 'Romania',
      'NL': 'Netherlands',
      'BE': 'Belgium',
      'GR': 'Greece',
      'CZ': 'Czech Republic',
      'PT': 'Portugal',
      'SE': 'Sweden',
      'HU': 'Hungary',
      'BY': 'Belarus',
      'AT': 'Austria',
      'CH': 'Switzerland',
      'BG': 'Bulgaria',
      'DK': 'Denmark',
      'FI': 'Finland',
      'SK': 'Slovakia',
      'NO': 'Norway',
      'IE': 'Ireland',
      'HR': 'Croatia',
      'MD': 'Moldova',
      'BA': 'Bosnia and Herzegovina',
      'AL': 'Albania',
      'LT': 'Lithuania',
      'MK': 'North Macedonia',
      'SI': 'Slovenia',
      'LV': 'Latvia',
      'EE': 'Estonia',
      'CY': 'Cyprus',
      'LU': 'Luxembourg',
      'MT': 'Malta',
      'IS': 'Iceland',
      'AD': 'Andorra',
      'MC': 'Monaco',
      'LI': 'Liechtenstein',
      'SM': 'San Marino',
      'VA': 'Vatican City',
      'RS': 'Serbia',
      'ME': 'Montenegro',
      'XK': 'Kosovo',

      // Asia
      'CN': 'China',
      'IN': 'India',
      'ID': 'Indonesia',
      'PK': 'Pakistan',
      'BD': 'Bangladesh',
      'JP': 'Japan',
      'PH': 'Philippines',
      'VN': 'Vietnam',
      'TR': 'Turkey',
      'IR': 'Iran',
      'TH': 'Thailand',
      'KR': 'South Korea',
      'IQ': 'Iraq',
      'AF': 'Afghanistan',
      'SA': 'Saudi Arabia',
      'MY': 'Malaysia',
      'UZ': 'Uzbekistan',
      'NP': 'Nepal',
      'YE': 'Yemen',
      'KP': 'North Korea',
      'SY': 'Syria',
      'MM': 'Myanmar',
      'KZ': 'Kazakhstan',
      'AZ': 'Azerbaijan',
      'AE': 'United Arab Emirates',
      'LK': 'Sri Lanka',
      'TJ': 'Tajikistan',
      'HK': 'Hong Kong',
      'IL': 'Israel',
      'JO': 'Jordan',
      'LB': 'Lebanon',
      'SG': 'Singapore',
      'OM': 'Oman',
      'KW': 'Kuwait',
      'GE': 'Georgia',
      'MN': 'Mongolia',
      'AM': 'Armenia',
      'QA': 'Qatar',
      'BH': 'Bahrain',
      'TL': 'Timor-Leste',
      'BN': 'Brunei',
      'MO': 'Macao',
      'BT': 'Bhutan',
      'MV': 'Maldives',
      'KG': 'Kyrgyzstan',
      'TM': 'Turkmenistan',
      'PS': 'Palestine',

      // Africa
      'NG': 'Nigeria',
      'ET': 'Ethiopia',
      'EG': 'Egypt',
      'CD': 'Democratic Republic of the Congo',
      'ZA': 'South Africa',
      'TZ': 'Tanzania',
      'KE': 'Kenya',
      'SD': 'Sudan',
      'DZ': 'Algeria',
      'MA': 'Morocco',
      'UG': 'Uganda',
      'GH': 'Ghana',
      'MZ': 'Mozambique',
      'ZM': 'Zambia',
      'MG': 'Madagascar',
      'AO': 'Angola',
      'CI': 'Ivory Coast',
      'CM': 'Cameroon',
      'NE': 'Niger',
      'ML': 'Mali',
      'MW': 'Malawi',
      'SN': 'Senegal',
      'TN': 'Tunisia',
      'SO': 'Somalia',
      'ZW': 'Zimbabwe',
      'SS': 'South Sudan',
      'RW': 'Rwanda',
      'GN': 'Guinea',
      'BJ': 'Benin',
      'BI': 'Burundi',
      'TD': 'Chad',
      'LY': 'Libya',
      'SL': 'Sierra Leone',
      'TG': 'Togo',
      'MR': 'Mauritania',
      'ER': 'Eritrea',
      'LR': 'Liberia',
      'CF': 'Central African Republic',
      'CG': 'Republic of the Congo',
      'GA': 'Gabon',
      'GM': 'Gambia',
      'SZ': 'Eswatini',
      'DJ': 'Djibouti',
      'GW': 'Guinea-Bissau',
      'LS': 'Lesotho',
      'NA': 'Namibia',
      'BW': 'Botswana',
      'EH': 'Western Sahara',
      'CV': 'Cape Verde',
      'ST': 'São Tomé and Príncipe',
      'SC': 'Seychelles',
      'KM': 'Comoros',
      'MU': 'Mauritius',
      'RE': 'Réunion',
      'YT': 'Mayotte',

      // Oceania
      'AU': 'Australia',
      'PG': 'Papua New Guinea',
      'NZ': 'New Zealand',
      'FJ': 'Fiji',
      'SB': 'Solomon Islands',
      'FM': 'Micronesia',
      'VU': 'Vanuatu',
      'WS': 'Samoa',
      'KI': 'Kiribati',
      'TO': 'Tonga',
      'TV': 'Tuvalu',
      'NR': 'Nauru',
      'MH': 'Marshall Islands',
      'PW': 'Palau',
      'CK': 'Cook Islands',
      'NU': 'Niue',
      'TK': 'Tokelau',
      'GU': 'Guam',
      'MP': 'Northern Mariana Islands',
      'AS': 'American Samoa',
      'NC': 'New Caledonia',
      'PF': 'French Polynesia',
      'WF': 'Wallis and Futuna',

      // Antarctica
      'AQ': 'Antarctica',
    };

    // Normalize country code
    final String normalizedCode = countryCode.trim().toUpperCase();

    // Return country name or the code itself if not found
    return countryNames[normalizedCode] ?? countryCode;
  }
}
