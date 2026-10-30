import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'report_photo_codec.dart';

class PhotoPickResult {
  const PhotoPickResult({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    required this.fileSizeBytes,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
  final int fileSizeBytes;

  String get dataUri => encodeReportPhoto(bytes, mimeType);
}

enum PhotoSource {
  camera,
  gallery,
}

/// Service untuk menangani pengambilan foto dari kamera atau galeri,
/// validasi format (JPG, PNG, WebP), batas ukuran 1 MB, serta pembatalan user.
class CameraPhotoService {
  CameraPhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Mengambil foto dari sumber yang dipilih (kamera atau galeri).
  /// Mengembalikan `null` jika user membatalkan pengambilan foto (graceful cancel).
  Future<PhotoPickResult?> pickPhoto({
    required PhotoSource source,
    int maxBytes = maxReportPhotoBytes,
  }) async {
    try {
      final imageSource = source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery;

      final XFile? pickedFile = await _picker.pickImage(
        source: imageSource,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      // User membatalkan pengambilan gambar
      if (pickedFile == null) {
        return null;
      }

      final bytes = await pickedFile.readAsBytes();

      if (bytes.length > maxBytes) {
        throw PhotoSizeLimitException(
          'Ukuran foto (${(bytes.length / 1024).toStringAsFixed(0)} KB) melebihi batas maksimal 1 MB.',
        );
      }

      final mimeType = detectReportPhotoMimeType(bytes);
      if (mimeType == null) {
        throw const UnsupportedPhotoFormatException(
          'Format gambar tidak didukung. Harap pilih gambar JPG, PNG, atau WebP.',
        );
      }

      return PhotoPickResult(
        bytes: bytes,
        mimeType: mimeType,
        fileName: pickedFile.name,
        fileSizeBytes: bytes.length,
      );
    } on PhotoSizeLimitException {
      rethrow;
    } on UnsupportedPhotoFormatException {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw const PhotoPermissionDeniedException();
      }
      debugPrint('CameraPhotoService pickPhoto error: $e');
      throw PhotoCaptureException('Gagal mengambil foto: $e');
    } catch (e) {
      debugPrint('CameraPhotoService pickPhoto error: $e');
      throw PhotoCaptureException('Gagal mengambil foto: $e');
    }
  }
}

class PhotoPermissionDeniedException implements Exception {
  const PhotoPermissionDeniedException();
}

class PhotoSizeLimitException implements Exception {
  const PhotoSizeLimitException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UnsupportedPhotoFormatException implements Exception {
  const UnsupportedPhotoFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PhotoCaptureException implements Exception {
  const PhotoCaptureException(this.message);
  final String message;
  @override
  String toString() => message;
}
