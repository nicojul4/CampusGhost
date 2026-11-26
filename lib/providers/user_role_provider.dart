import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/user_role.dart';
import '../utils/logger.dart';

/// User role provider that reads role from Firebase Custom Claims
/// with fallback to Firestore user profile.
/// Role changes MUST go through Cloud Functions (not client-side).
class UserRoleNotifier extends Notifier<UserRole> {
  @override
  UserRole build() {
    // Initialize from token asynchronously
    _initializeFromToken();
    return UserRole.student; // Default while loading
  }

  Future<void> _initializeFromToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.info('UserRoleNotifier', 'No authenticated user, using default student role');
        return;
      }

      // 1. Check claims from cached token first
      var tokenResult = await user.getIdTokenResult();
      var roleStr = tokenResult.claims?['role'] as String?;

      // 2. If not present in cached token, try a fresh token from server
      if (roleStr == null) {
        try {
          tokenResult = await user.getIdTokenResult(true);
          roleStr = tokenResult.claims?['role'] as String?;
        } catch (_) {
          // Token refresh failure (e.g. offline) - continue to fallback
        }
      }

      // 3. If role claim is present, parse and assign
      if (roleStr != null) {
        try {
          state = UserRole.fromString(roleStr);
          logger.info('UserRoleNotifier', 'Role initialized from token: $roleStr');
          return;
        } catch (e) {
          logger.info('UserRoleNotifier', 'Invalid role claim ($roleStr), checking profile fallback');
        }
      }

      // 4. Fallback: check Firestore profile if claims are not populated yet
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final docRole = doc.data()?['role'] as String?;
        if (docRole != null) {
          state = UserRole.fromString(docRole);
          logger.info('UserRoleNotifier', 'Role initialized from user profile: $docRole');
          return;
        }
      } catch (_) {
        // Fallback Firestore read error (e.g., offline or rules)
      }

      // 5. Default role for standard accounts is student (normal behavior, not a warning)
      state = UserRole.student;
      logger.info('UserRoleNotifier', 'Standard account: default student role applied');
    } catch (e) {
      logger.info('UserRoleNotifier', 'Role initialized with default student role ($e)');
      state = UserRole.student;
    }
  }

  /// Refresh role from token (call after role change or app resume)
  Future<void> refreshFromToken() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Force token refresh
      await user.getIdToken(true);

      // Re-read from refreshed token
      final tokenResult = await user.getIdTokenResult();
      final roleStr = tokenResult.claims?['role'] as String?;

      if (roleStr != null) {
        try {
          state = UserRole.fromString(roleStr);
          logger.info('UserRoleNotifier', 'Role refreshed from token: $roleStr');
          return;
        } catch (e) {
          logger.info('UserRoleNotifier', 'Invalid role after refresh: $roleStr');
        }
      }

      // Fallback to Firestore profile
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final docRole = doc.data()?['role'] as String?;
        if (docRole != null) {
          state = UserRole.fromString(docRole);
          logger.info('UserRoleNotifier', 'Role refreshed from user profile: $docRole');
          return;
        }
      } catch (_) {}

      state = UserRole.student;
      logger.info('UserRoleNotifier', 'Role refresh completed (student)');
    } catch (e) {
      logger.info('UserRoleNotifier', 'Role refresh completed with fallback: $e');
    }
  }

  /// Update role from token value (internal use only)
  /// This is called after successful role change via Cloud Function
  void updateFromClaimValue(String roleStr) {
    try {
      state = UserRole.fromString(roleStr);
      logger.info('UserRoleNotifier', 'Role updated: $roleStr');
    } catch (e) {
      logger.error('UserRoleNotifier', 'Invalid role value: $roleStr');
    }
  }
}

final userRoleProvider =
    NotifierProvider<UserRoleNotifier, UserRole>(UserRoleNotifier.new);
