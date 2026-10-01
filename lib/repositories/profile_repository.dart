import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/local_campus_store.dart';
import '../services/report_photo_codec.dart';

class InvalidProfilePhotoException implements Exception {}

class ProfilePhotoSaveException implements Exception {}

class ProfileRepository {
  ProfileRepository(this._auth, this._store);

  final FirebaseAuth _auth;
  final LocalCampusStore _store;

  Future<Uint8List?> readCurrentPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return decodeReportPhoto(await _store.readProfilePhoto(user.uid));
  }

  Future<void> updateProfile({
    required String name,
    Uint8List? photoBytes,
    bool removePhoto = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'unauthenticated');
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      throw ArgumentError.value(name, 'name');
    }
    if (photoBytes != null &&
        (photoBytes.length > maxReportPhotoBytes ||
            detectReportPhotoMimeType(photoBytes) == null)) {
      throw InvalidProfilePhotoException();
    }

    if (user.displayName != trimmedName) {
      await user.updateDisplayName(trimmedName);
    }
    try {
      if (removePhoto) {
        await _store.deleteProfilePhoto(user.uid);
      } else if (photoBytes != null) {
        final mimeType = detectReportPhotoMimeType(photoBytes)!;
        await _store.saveProfilePhoto(
          user.uid,
          encodeReportPhoto(photoBytes, mimeType),
        );
      }
    } catch (_) {
      throw ProfilePhotoSaveException();
    }
  }
}
