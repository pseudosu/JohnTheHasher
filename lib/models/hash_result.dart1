// lib/models/hash_result.dart
import 'package:myapp/services/virus_total_service.dart';

class HashResult {
  final String fileName;
  final String fileType;
  final int fileSize;
  final String md5;
  final String sha1;
  final String sha256;
  final Map<String, dynamic> detectionStats;
  final String detectionPercentage;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int popularityRank;
  final List<String> tags;
  final List<Map<String, String>> topDetections;
  final Map<String, dynamic> signatureInfo;
  final String threatCategory;

  HashResult({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.md5,
    required this.sha1,
    required this.sha256,
    required this.detectionStats,
    required this.detectionPercentage,
    this.firstSeen,
    this.lastSeen,
    required this.popularityRank,
    required this.tags,
    required this.topDetections,
    required this.signatureInfo,
    required this.threatCategory,
  });

  factory HashResult.fromVTResponse(Map<String, dynamic> vtResponse) {
    // Get the details map from VirusTotalService
    final details = VirusTotalService.extractFileDetails(vtResponse);

    // Convert the map to a HashResult object
    return HashResult(
      fileName: details['fileName'] ?? 'Unknown',
      fileType: details['fileType'] ?? 'Unknown',
      fileSize: details['fileSize'] ?? 0,
      md5: details['md5'] ?? '',
      sha1: details['sha1'] ?? '',
      sha256: details['sha256'] ?? '',
      detectionStats: details['detectionStats'] ?? {},
      detectionPercentage: details['detectionPercentage'] ?? '0.0',
      firstSeen: details['firstSeen'],
      lastSeen: details['lastSeen'],
      popularityRank: details['popularityRank'] ?? 0,
      tags: List<String>.from(details['tags'] ?? []),
      topDetections: List<Map<String, String>>.from(
        details['topDetections'] ?? [],
      ),
      signatureInfo: details['signatureInfo'] ?? {},
      threatCategory: details['threatCategory'] ?? 'Unknown',
    );
  }
}
