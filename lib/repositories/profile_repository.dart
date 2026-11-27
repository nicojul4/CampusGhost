import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../services/local_campus_store.dart';
import '../services/report_photo_codec.dart';
import '../utils/logger.dart';
import '../validators/profile_validators.dart';

class InvalidProfilePhotoException implements Exception {}

class ProfilePhotoSaveException implements Exception {}

class ProfileRepository {
  ProfileRepository(this._auth, this._store, {FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseAuth _auth;
  final LocalCampusStore _store;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    if (Firebase.apps.isNotEmpty) return FirebaseFirestore.instance;
    return null;
  }

  Future<Uint8List?> readCurrentPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final localRaw = await _store.readProfilePhoto(user.uid);
    final localBytes = decodeReportPhoto(localRaw);
    if (localBytes != null) return localBytes;

    // Fallback ke Firestore jika cache lokal perangkat/browser sempat terhapus
    final db = _db;
    if (db != null) {
      try {
        final doc = await db.collection('users').doc(user.uid).get();
        final remotePhoto = doc.data()?['photoUrl'] as String?;
        final remoteBytes = decodeReportPhoto(remotePhoto);
        if (remoteBytes != null && remotePhoto != null) {
          await _store.saveProfilePhoto(user.uid, remotePhoto);
          return remoteBytes;
        }
      } catch (e) {
        logger.info('ProfileRepository', 'Fallback photo read skipped: $e');
      }
    }
    return null;
  }

  Future<String> readCurrentDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Mahasiswa';

    try {
      final localName = (await _store.readProfileName(user.uid))?.trim();
      if (localName != null && localName.isNotEmpty) {
        return localName;
      }
    } catch (_) {}

    final db = _db;
    if (db != null) {
      try {
        final doc = await db.collection('users').doc(user.uid).get();
        final remoteName = (doc.data()?['displayName'] as String?)?.trim();
        if (remoteName != null && remoteName.isNotEmpty) {
          await _store.saveProfileName(user.uid, remoteName);
          return remoteName;
        }
      } catch (e) {
        logger.info('ProfileRepository', 'Fallback name read skipped: $e');
      }
    }

    try {
      final authName = user.displayName?.trim();
      if (authName != null && authName.isNotEmpty) return authName;
    } catch (_) {}

    try {
      final emailPrefix = user.email?.split('@').first;
      if (emailPrefix != null && emailPrefix.isNotEmpty) return emailPrefix;
    } catch (_) {}

    return 'Mahasiswa';
  }

  Future<void> updateProfile({
    required String name,
    Uint8List? photoBytes,
    bool removePhoto = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'unauthenticated');

    final trimmedName = name.trim();
    if (validateProfileName(trimmedName) != null) {
      throw ArgumentError.value(name, 'name');
    }

    if (photoBytes != null) {
      final result = validateProfilePhoto(photoBytes);
      if (result != PhotoValidationResult.valid) {
        throw InvalidProfilePhotoException();
      }
    }

    if (user.displayName != trimmedName) {
      await user.updateDisplayName(trimmedName);
      try {
        await user.reload();
      } catch (_) {}
    }

    String? encodedPhoto;
    try {
      await _store.saveProfileName(user.uid, trimmedName);
      if (removePhoto) {
        await _store.deleteProfilePhoto(user.uid);
      } else if (photoBytes != null) {
        final mimeType = detectReportPhotoMimeType(photoBytes)!;
        encodedPhoto = encodeReportPhoto(photoBytes, mimeType);
        await _store.saveProfilePhoto(user.uid, encodedPhoto);
      }
    } catch (_) {
      throw ProfilePhotoSaveException();
    }

    // Sinkronkan ke dokumen Firestore users/{uid} agar tetap bertahan saat ganti perangkat/logout
    final db = _db;
    if (db != null) {
      try {
        final updates = <String, dynamic>{
          'displayName': trimmedName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (removePhoto) {
          updates['photoUrl'] = null;
        } else if (encodedPhoto != null && encodedPhoto.length <= 900000) {
          updates['photoUrl'] = encodedPhoto;
        }

        final userRef = db.collection('users').doc(user.uid);
        final snapshot = await userRef.get();
        if (snapshot.exists) {
          await userRef.update(updates);
        } else {
          await userRef.set({
            'uid': user.uid,
            'email': user.email ?? '',
            'studentId': null,
            'program': null,
            'role': 'student',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            if (!updates.containsKey('photoUrl')) 'photoUrl': user.photoURL,
            ...updates,
          });
        }
        logger.info('ProfileRepository', 'Profile synced to Firestore for ${user.uid}');
      } catch (e) {
        logger.info('ProfileRepository', 'Firestore profile sync skipped: $e');
      }
    }
  }
}
