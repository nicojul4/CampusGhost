import 'dart:typed_data';

import '../services/report_photo_codec.dart';

/// Batas maksimum panjang nama tampilan profil.
const maxProfileNameLength = 80;

/// Validasi nama tampilan profil.
/// Mengembalikan pesan error (String) jika tidak valid, null jika valid.
String? validateProfileName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Nama tidak boleh kosong.';
  }
  if (value.trim().length > maxProfileNameLength) {
    return 'Nama maksimal $maxProfileNameLength karakter.';
  }
  return null;
}

/// Hasil validasi foto profil.
enum PhotoValidationResult {
  valid,
  tooLarge,
  invalidFormat,
}

/// Validasi foto profil berdasarkan ukuran dan format.
PhotoValidationResult validateProfilePhoto(Uint8List bytes) {
  if (bytes.length > maxReportPhotoBytes) {
    return PhotoValidationResult.tooLarge;
  }
  if (detectReportPhotoMimeType(bytes) == null) {
    return PhotoValidationResult.invalidFormat;
  }
  return PhotoValidationResult.valid;
}

/// Pesan error untuk hasil validasi foto yang gagal.
String photoValidationMessage(PhotoValidationResult result) => switch (result) {
      PhotoValidationResult.tooLarge =>
        'Ukuran foto maksimal 1 MB.',
      PhotoValidationResult.invalidFormat =>
        'Pilih foto JPG, PNG, atau WebP yang valid, maksimal 1 MB.',
      PhotoValidationResult.valid => '',
    };
