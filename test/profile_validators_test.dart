import 'dart:typed_data';

import 'package:campus_ghost/validators/profile_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateProfileName', () {
    test('mengembalikan error jika null', () {
      expect(validateProfileName(null), isNotNull);
    });

    test('mengembalikan error jika kosong', () {
      expect(validateProfileName(''), isNotNull);
      expect(validateProfileName('   '), isNotNull);
    });

    test('mengembalikan null jika nama valid', () {
      expect(validateProfileName('Nicolas'), isNull);
    });

    test('mengembalikan error jika melebihi 80 karakter', () {
      final longName = 'A' * 81;
      expect(validateProfileName(longName), isNotNull);
    });

    test('nama 80 karakter tepat diterima', () {
      final exactName = 'A' * 80;
      expect(validateProfileName(exactName), isNull);
    });
  });

  group('validateProfilePhoto', () {
    test('JPEG valid diterima', () {
      // JPEG magic bytes: FF D8 FF
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(10, 0)]);
      expect(validateProfilePhoto(jpeg), PhotoValidationResult.valid);
    });

    test('PNG valid diterima', () {
      // PNG magic bytes: 89 50 4E 47 ...
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(10, 0)
      ]);
      expect(validateProfilePhoto(png), PhotoValidationResult.valid);
    });

    test('format tidak dikenal ditolak', () {
      final invalid = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(validateProfilePhoto(invalid), PhotoValidationResult.invalidFormat);
    });

    test('foto terlalu besar ditolak', () {
      // > 1MB JPEG
      final large = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, ...List.filled(1024 * 1024 + 1, 0)
      ]);
      expect(validateProfilePhoto(large), PhotoValidationResult.tooLarge);
    });

    test('foto tepat 1MB diterima', () {
      final bytes = Uint8List(1024 * 1024);
      // Set JPEG header
      bytes[0] = 0xFF;
      bytes[1] = 0xD8;
      bytes[2] = 0xFF;
      expect(validateProfilePhoto(bytes), PhotoValidationResult.valid);
    });
  });

  group('photoValidationMessage', () {
    test('tooLarge mengembalikan pesan ukuran', () {
      expect(
        photoValidationMessage(PhotoValidationResult.tooLarge),
        contains('1 MB'),
      );
    });

    test('invalidFormat mengembalikan pesan format', () {
      expect(
        photoValidationMessage(PhotoValidationResult.invalidFormat),
        contains('JPG'),
      );
    });

    test('valid mengembalikan string kosong', () {
      expect(
        photoValidationMessage(PhotoValidationResult.valid),
        isEmpty,
      );
    });
  });
}
