import 'dart:io';

class OrderFileRules {
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'png',
    'jpeg',
    'pptx',
  ];

  static const int maxFileSizeBytes = 50 * 1024 * 1024;
  static const String maxFileSizeLabel = '50 MB';

  static String get allowedExtensionsLabel =>
      allowedExtensions.map((extension) => extension.toUpperCase()).join(', ');

  static Future<String?> validateLocalFile({
    required String filePath,
    required String? fileName,
    int? fileSizeBytes,
  }) async {
    final resolvedFileName = _fileNameForValidation(filePath, fileName);
    final extensionError = validateFileName(resolvedFileName);
    if (extensionError != null) return extensionError;

    final file = File(filePath);
    if (!await file.exists()) {
      return 'File $resolvedFileName tidak ditemukan. Pilih ulang file.';
    }

    final size = fileSizeBytes ?? await file.length();
    return validateFileSize(size, resolvedFileName);
  }

  static String? validateFileName(String? fileName) {
    final extension = _extensionOf(fileName);
    if (extension == null || !allowedExtensions.contains(extension)) {
      return 'File hanya boleh berformat $allowedExtensionsLabel.';
    }
    return null;
  }

  static String? validateFileSize(int sizeBytes, String fileName) {
    if (sizeBytes > maxFileSizeBytes) {
      return 'Ukuran file $fileName melebihi batas $maxFileSizeLabel.';
    }
    return null;
  }

  static String _fileNameForValidation(String filePath, String? fileName) {
    final trimmedName = fileName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;

    final segments = filePath.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? 'file_upload' : segments.last;
  }

  static String? _extensionOf(String? fileName) {
    final name = fileName?.trim().toLowerCase();
    if (name == null || name.isEmpty || !name.contains('.')) return null;

    final extension = name.split('.').last;
    return extension.isEmpty ? null : extension;
  }
}
