// lib/widgets/hash_input_form.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class HashInputForm extends StatelessWidget {
  final TextEditingController hashController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onSubmit;

  const HashInputForm({
    required this.hashController,
    required this.formKey,
    required this.isLoading,
    required this.onSubmit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromRGBO(45, 95, 155, 1),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter File Hash',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Fixed implementation - separate label above TextField
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MD5, SHA-1, or SHA-256',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: hashController,
                    decoration: InputDecoration(
                      hintText: 'e.g., 44d88612fea8a8f36de82e1278abb02f',
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
                    validator: _validateHash,
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
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
                    isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color.fromRGBO(45, 95, 155, 1),
                          ),
                        )
                        : const Text(
                          'Submit to VirusTotal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateHash(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a hash';
    }

    // Hash format validation
    final md5Regex = RegExp(r'^[a-fA-F0-9]{32}$');
    final sha1Regex = RegExp(r'^[a-fA-F0-9]{40}$');
    final sha256Regex = RegExp(r'^[a-fA-F0-9]{64}$');

    if (!md5Regex.hasMatch(value) &&
        !sha1Regex.hasMatch(value) &&
        !sha256Regex.hasMatch(value)) {
      return 'Invalid hash format';
    }
    return null;
  }
}
