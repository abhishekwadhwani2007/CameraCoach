import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// Sends corrected overlay masks to the backend so we can use them for
/// model fine-tuning over time.
///
/// The upload is fire-and-forget — a failure is logged but never shown to
/// the user, and it never blocks the save flow.
///
/// The endpoint URL is injected at build time via --dart-define so no IP/URL
/// ever lives in source code. Example:
///   flutter run --dart-define=BACKEND_URL=http://192.168.1.10:8000
class MaskUploadService {
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  /// How long we wait for the upload before giving up. Long enough for a slow
  /// connection but short enough that it never hangs the process.
  static const Duration _timeout = Duration(seconds: 30);

  /// Upload the original image, the raw AI mask, and the user-corrected mask
  /// as a single multipart POST.
  ///
  /// [deviceId] and [confidenceScore] are stored as metadata so the training
  /// pipeline can weight samples by model confidence.
  static Future<void> uploadCorrection({
    required File originalImage,
    required File aiMask,
    required File correctedMask,
    required String deviceId,
    double confidenceScore = 0.0,
  }) async {
    if (_baseUrl.trim().isEmpty) {
      AppLogger.debug('MaskUploadService: BACKEND_URL not set — skipping upload.');
      return;
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/mask-corrections');
      final request = http.MultipartRequest('POST', uri)
        ..fields['device_id'] = deviceId
        ..fields['confidence'] = confidenceScore.toStringAsFixed(4)
        ..fields['timestamp'] = DateTime.now().toUtc().toIso8601String()
        ..fields['user_edited'] = 'true'
        ..files.add(
          await http.MultipartFile.fromPath(
            'original_image',
            originalImage.path,
            filename: 'original_image.jpg',
          ),
        )
        ..files.add(
          await http.MultipartFile.fromPath(
            'ai_mask',
            aiMask.path,
            filename: 'ai_mask.png',
          ),
        )
        ..files.add(
          await http.MultipartFile.fromPath(
            'corrected_mask',
            correctedMask.path,
            filename: 'corrected_mask.png',
          ),
        );

      final streamed = await request.send().timeout(_timeout);

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        AppLogger.debug('MaskUploadService: correction uploaded successfully.');
      } else {
        AppLogger.error(
          'MaskUploadService: unexpected status ${streamed.statusCode}',
        );
      }
    } catch (e) {
      // Non-fatal — the user flow must never depend on this succeeding.
      AppLogger.error('MaskUploadService: upload failed: $e');
      if (kDebugMode) rethrow; // surface in debug so we catch issues early
    }
  }
}
