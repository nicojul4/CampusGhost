import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

/// AuthRepository handles Firebase Auth operations and the initial Firestore
/// profile write for new users.
///
/// SECURITY CONTRACT:
///   - New profiles are always written with role='student' and isActive=true.
///   - Privileged fields (roleVersion, provisioningStatus, deactivatedAt,
///     deactivatedBy, claimsOutOfSync) are intentionally omitted from client
///     writes.  The onUserProfileCreate Cloud Function (Admin SDK) adds them.
///   - Security Rules enforce these constraints server-side as a second layer.
///
/// PROVISIONING FAILURE HANDLING:
///   If the Firestore write fails the Auth user still exists.  The caller
///   (AuthService) is responsible for surfacing the error.  The user will have
///   an Auth account but no profile and no Custom Claims.  On next sign-in
///   the app can retry the profile write; the onUserProfileCreate trigger will
///   also retry Claims assignment if the document is eventually created.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = result.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        if (_isDemoEmail(cleanEmail)) {
          try {
            final reg = await _auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
            final user = reg.user;
            if (user != null) {
              final displayName = cleanEmail.toLowerCase().startsWith('admin')
                  ? 'Administrator Kampus'
                  : (cleanEmail.toLowerCase().startsWith('teknisi')
                      ? 'Pak Budi GA'
                      : 'Nicolas Julian');
              await user.updateDisplayName(displayName);
              return user;
            }
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  static bool _isDemoEmail(String email) {
    final clean = email.toLowerCase().trim();
    return clean == 'admin@pradita.ac.id' ||
        clean == 'admin@campusghost.ac.id' ||
        clean.startsWith('admin@') ||
        clean == 'teknisi.ga@pradita.ac.id' ||
        clean == 'teknisi@pradita.ac.id' ||
        clean == 'teknisi@campusghost.ac.id' ||
        clean.startsWith('teknisi') ||
        clean == 'mahasiswa@student.pradita.ac.id' ||
        clean == 'nicolas.julian@student.pradita.ac.id';
  }

  /// Registers a new user and creates their Firestore profile.
  ///
  /// The profile is written with role='student'. Security Rules enforce this
  /// constraint so a compromised client cannot escalate privileges at creation.
  ///
  /// Throws [FirebaseAuthException] on Auth failure.
  /// Throws [FirebaseException] on Firestore write failure.  In that case the
  /// Auth account exists but the profile does not; the caller should inform
  /// the user and offer a retry.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) throw FirebaseAuthException(code: 'internal-error');
    await user.updateDisplayName(name.trim());

    // Write the initial profile.  Privileged fields are excluded — the
    // Security Rules rule enforces that role must be 'student' and isActive
    // must be true for a client create, and that roleVersion /
    // provisioningStatus / deactivatedAt / deactivatedBy cannot be present.
    try {
      await _writeStudentProfile(
        uid:         user.uid,
        email:       user.email ?? email.trim(),
        displayName: name.trim(),
        photoUrl:    user.photoURL,
        isNewUser:   true,
      );
    } catch (e, st) {
      logger.errorWithStack(
        'AuthRepository',
        'Firestore profile write failed for ${user.uid}. '
        'Auth account exists but profile is missing.',
        e, st,
      );
      rethrow; // surface to AuthService so the user gets feedback
    }

    return user;
  }

  Future<User> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});

    final UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(provider);
    } else {
      credential = await _auth.signInWithProvider(provider);
    }
    final user = credential.user;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');

    final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
    if (isNewUser) {
      try {
        await _writeStudentProfile(
          uid:         user.uid,
          email:       user.email ?? '',
          displayName: user.displayName ??
              user.email?.split('@').first ??
              'User',
          photoUrl:    user.photoURL,
          isNewUser:   true,
        );
      } catch (e, st) {
        logger.errorWithStack(
          'AuthRepository',
          'Firestore profile write failed for new Google user ${user.uid}.',
          e, st,
        );
        rethrow;
      }
    } else {
      // Pertahankan nama tampilan kustom yang sudah pernah diubah pengguna di Firestore
      try {
        final docRef = _firestore.collection('users').doc(user.uid);
        final snap = await docRef.get();
        if (snap.exists) {
          final savedName = (snap.data()?['displayName'] as String?)?.trim();
          if (savedName != null &&
              savedName.isNotEmpty &&
              savedName != user.displayName) {
            await user.updateDisplayName(savedName);
            await user.reload();
          }
          await docRef.update({
            'lastLoginAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await _writeStudentProfile(
            uid:         user.uid,
            email:       user.email ?? '',
            displayName: user.displayName ??
                user.email?.split('@').first ??
                'User',
            photoUrl:    user.photoURL,
            isNewUser:   false,
          );
        }
      } catch (e) {
        logger.info('AuthRepository', 'Existing Google profile sync skipped: $e');
      }
    }

    return user;
  }

  Future<void> signOut() => _auth.signOut();

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Writes a minimal student profile document.
  ///
  /// Fields included here must stay within what the Firestore Security Rules
  /// allow for a client create:
  ///   - role == 'student'
  ///   - isActive == true
  ///   - no privileged fields (roleVersion, provisioningStatus, deactivatedAt,
  ///     deactivatedBy, claimsOutOfSync)
  Future<void> _writeStudentProfile({
    required String  uid,
    required String  email,
    required String  displayName,
    required String? photoUrl,
    required bool    isNewUser,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid':         uid,
      'email':       email,
      'displayName': displayName,
      'studentId':   null,
      'program':     null,
      'photoUrl':    photoUrl,
      'role':        'student',   // enforced by Security Rules
      'isActive':    true,        // enforced by Security Rules
      'createdAt':   FieldValue.serverTimestamp(),
      'updatedAt':   FieldValue.serverTimestamp(),
      'lastLoginAt': isNewUser ? null : FieldValue.serverTimestamp(),
    });
    logger.info('AuthRepository', 'Student profile written for $uid');
  }
}
