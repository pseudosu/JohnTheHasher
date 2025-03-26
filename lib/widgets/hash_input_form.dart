// lib/widgets/hash_input_form.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class HashInputForm extends StatefulWidget {
  final TextEditingController hashController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final Function(List<Map<String, dynamic>>) onSubmit;

  const HashInputForm({
    required this.hashController,
    required this.formKey,
    required this.isLoading,
    required this.onSubmit,
    super.key,
  });

  @override
  State<HashInputForm> createState() => _HashInputFormState();
}

class _HashInputFormState extends State<HashInputForm> {
  bool _batchMode = false;
  bool _fileMode = false;
  List<PlatformFile>? _selectedFiles;
  List<Map<String, dynamic>> _fileHashes = [];
  String _hashType = 'SHA-256';
  bool _processingFiles = false;
  double _processingProgress = 0.0;

  final List<String> _hashTypes = ['MD5', 'SHA-1', 'SHA-256'];

  Future<void> _pickFiles() async {
    setState(() {
      _processingFiles = true;
      _processingProgress = 0.0;
      _fileHashes = [];
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });

        // Process files to generate hashes
        await _processFiles();

        // Update text field with generated hashes
        _updateHashTextField();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    } finally {
      setState(() {
        _processingFiles = false;
      });
    }
  }

  Future<void> _processFiles() async {
    if (_selectedFiles == null || _selectedFiles!.isEmpty) return;

    _fileHashes = [];
    int totalProcessed = 0;

    for (var file in _selectedFiles!) {
      if (file.path == null) continue;

      final filePath = file.path!;
      final fileObj = File(filePath);

      if (await fileObj.exists()) {
        String hashValue;

        try {
          // Compute hash based on selected type
          hashValue = await _computeFileHash(fileObj, _hashType);

          _fileHashes.add({
            'filename': file.name,
            'path': filePath,
            'size': file.size,
            'hash': hashValue,
            'hashType': _hashType,
          });
        } catch (e) {
          // Skip files that can't be hashed
          continue;
        }
      }

      totalProcessed++;
      setState(() {
        _processingProgress = totalProcessed / _selectedFiles!.length;
      });
    }
  }

  Future<String> _computeFileHash(File file, String hashType) async {
    try {
      final fileStream = file.openRead();
      var digest;

      if (hashType == 'MD5') {
        digest = await md5.bind(fileStream).first;
      } else if (hashType == 'SHA-1') {
        digest = await sha1.bind(fileStream).first;
      } else {
        // Default to SHA-256
        digest = await sha256.bind(fileStream).first;
      }

      return digest.toString();
    } catch (e) {
      rethrow;
    }
  }

  void _updateHashTextField() {
    if (_fileHashes.isEmpty) return;

    final hashList = _fileHashes.map((item) => item['hash']).toList();
    widget.hashController.text = hashList.join('\n');
  }

  void _submitHashes() {
    if (_fileMode && _fileHashes.isNotEmpty) {
      widget.onSubmit(_fileHashes);
    } else {
      // Process text input
      final hashText = widget.hashController.text.trim();
      if (hashText.isEmpty) return;

      if (_batchMode) {
        final hashes =
            hashText
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .map(
                  (hash) => ({
                    'hash': hash.trim(),
                    'hashType': _detectHashType(hash.trim()),
                    'filename': 'Unknown',
                  }),
                )
                .toList();

        widget.onSubmit(hashes);
      } else {
        // Single hash
        final hash = hashText;
        widget.onSubmit([
          {
            'hash': hash,
            'hashType': _detectHashType(hash),
            'filename': 'Unknown',
          },
        ]);
      }
    }
  }

  String _detectHashType(String hash) {
    if (RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(hash)) {
      return 'MD5';
    } else if (RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) {
      return 'SHA-1';
    } else if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
      return 'SHA-256';
    }
    return 'Unknown';
  }

  String? _validateHashes(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter at least one hash';
    }

    if (_batchMode) {
      final hashes =
          value.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (hashes.isEmpty) {
        return 'Please enter at least one hash';
      }

      for (var hash in hashes) {
        final trimmedHash = hash.trim();
        if (!_isValidHash(trimmedHash)) {
          return 'Invalid hash format: $trimmedHash';
        }
      }
      return null;
    } else {
      // Single hash mode
      return _isValidHash(value.trim()) ? null : 'Invalid hash format';
    }
  }

  bool _isValidHash(String hash) {
    final md5Regex = RegExp(r'^[a-fA-F0-9]{32}$');
    final sha1Regex = RegExp(r'^[a-fA-F0-9]{40}$');
    final sha256Regex = RegExp(r'^[a-fA-F0-9]{64}$');

    return md5Regex.hasMatch(hash) ||
        sha1Regex.hasMatch(hash) ||
        sha256Regex.hasMatch(hash);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromRGBO(45, 95, 155, 1),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: widget.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'File Hash Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Mode toggles
              Row(
                children: [
                  // Batch mode toggle
                  Expanded(
                    child: SwitchListTile(
                      title: const Text(
                        'Batch Mode',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      value: _batchMode,
                      onChanged: (value) {
                        setState(() {
                          _batchMode = value;
                          if (!value) {
                            _fileMode = false;
                          }
                        });
                      },
                      activeColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  // File mode toggle (only available in batch mode)
                  if (_batchMode)
                    Expanded(
                      child: SwitchListTile(
                        title: const Text(
                          'File Upload',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        value: _fileMode,
                        onChanged: (value) {
                          setState(() {
                            _fileMode = value;
                          });
                        },
                        activeColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),

              // File upload (only visible in file mode)
              if (_fileMode && _batchMode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _hashType,
                            items:
                                _hashTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _hashType = value;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: 'Hash Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed:
                              (_processingFiles || widget.isLoading)
                                  ? null
                                  : _pickFiles,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Select Files'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: const Color.fromRGBO(
                              45,
                              95,
                              155,
                              1,
                            ),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Show selected files
                    if (_selectedFiles != null && _selectedFiles!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedFiles!.length} files selected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_processingFiles)
                              Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: _processingProgress,
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Processing files...',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              )
                            else
                              Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListView.builder(
                                  itemCount:
                                      _selectedFiles!.length > 5
                                          ? 5
                                          : _selectedFiles!.length,
                                  itemBuilder: (context, index) {
                                    final file = _selectedFiles![index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        file.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${(file.size / 1024).toStringAsFixed(2)} KB',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      leading: Icon(
                                        _getFileIcon(file.extension),
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (_selectedFiles!.length > 5 && !_processingFiles)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'and ${_selectedFiles!.length - 5} more...',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),

              // Hash input field (hidden in file mode)
              if (!_fileMode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Enter Hash Values',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: widget.hashController,
                      maxLines: _batchMode ? 6 : 1,
                      decoration: InputDecoration(
                        hintText:
                            _batchMode
                                ? 'e.g.,\n44d88612fea8a8f36de82e1278abb02f\nda39a3ee5e6b4b0d3255bfef95601890afd80709'
                                : 'e.g., 44d88612fea8a8f36de82e1278abb02f',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 16.0,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(
                          Icons.fingerprint,
                          color: Color.fromRGBO(25, 55, 109, 1),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black87),
                      validator: _validateHashes,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supported hash types: MD5, SHA-1, SHA-256',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20.0),

              // Submit button
              ElevatedButton(
                onPressed:
                    widget.isLoading || _processingFiles
                        ? null
                        : () => _submitHashes(),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color.fromRGBO(45, 95, 155, 1),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledForegroundColor: Colors.white54,
                  disabledBackgroundColor: Colors.black12,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    widget.isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color.fromRGBO(45, 95, 155, 1),
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search),
                            const SizedBox(width: 8),
                            Text(
                              _batchMode
                                  ? 'Analyze ${_fileMode ? _fileHashes.length : ''} Hashes'
                                  : 'Submit to VirusTotal',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.audio_file;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'exe':
      case 'msi':
        return Icons.apps;
      default:
        return Icons.insert_drive_file;
    }
  }
}
