import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_file_rules.dart';
import 'supabase_storage_config.dart';

class OrderFileUploadException implements Exception {
  final String message;

  const OrderFileUploadException(this.message);

  @override
  String toString() => message;
}

class UploadedOrderFile {
  final String fileName;
  final String downloadUrl;
  final String storagePath;

  const UploadedOrderFile({
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
  });
}

class OrderFileUploadService {
  OrderFileUploadService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<UploadedOrderFile?> uploadOrderFile({
    required String orderId,
    required int itemIndex,
    required String? filePath,
    required String? fileName,
  }) async {
    if (filePath == null || filePath.trim().isEmpty) return null;

    final validationError = await OrderFileRules.validateLocalFile(
      filePath: filePath,
      fileName: fileName,
    );
    if (validationError != null) {
      throw OrderFileUploadException(validationError);
    }

    if (!SupabaseStorageConfig.isConfigured) return null;

    final file = File(filePath);
    final resolvedFileName =
        _sanitizeFileName(fileName ?? _fileNameFromPath(filePath));
    final safeOrderId = _sanitizePathSegment(orderId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'orders/$safeOrderId/item_$itemIndex/${timestamp}_$resolvedFileName';
    final bucket = _client?.storage.from(SupabaseStorageConfig.bucket) ??
        Supabase.instance.client.storage.from(SupabaseStorageConfig.bucket);

    try {
      await bucket.upload(
        storagePath,
        file,
        fileOptions: FileOptions(
          contentType: _contentTypeFor(resolvedFileName),
          metadata: {
            'orderId': orderId,
            'originalFileName': fileName ?? resolvedFileName,
          },
        ),
      );

      return UploadedOrderFile(
        fileName: resolvedFileName,
        downloadUrl: bucket.getPublicUrl(storagePath),
        storagePath: storagePath,
      );
    } on StorageException catch (error) {
      debugPrint('Supabase Storage upload failed: $error');
      throw OrderFileUploadException(
        'Upload file $resolvedFileName ke Supabase gagal: ${error.message}',
      );
    } catch (error) {
      debugPrint('Order file upload skipped: $error');
      throw OrderFileUploadException(
        'Upload file $resolvedFileName ke Supabase gagal.',
      );
    }
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? 'file_upload' : segments.last;
  }

  String _sanitizeFileName(String value) {
    final fallback = value.trim().isEmpty ? 'file_upload' : value.trim();
    return fallback.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _sanitizePathSegment(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  }

  String _contentTypeFor(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.doc')) return 'application/msword';
    if (name.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (name.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    return 'application/octet-stream';
  }
}
