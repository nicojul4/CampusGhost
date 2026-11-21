import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/user_role.dart';
import '../utils/logger.dart';

/// User role provider that reads role from Firebase Custom Claims
/// Role changes MUST go through Cloud Functions (not client-side)
class UserRoleNotifier extends Notifier<UserRole> {
  @override
  UserRole build() {
    // Initialize from token
    _initializeFromToken();
    return UserRole.student; // Default while loading
  }

  Future<void> _initializeFromToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.info('UserRoleNotifier', 'No authenticated user');
        return;
      }

      final tokenResult = await user.getIdTokenResult();
      final roleStr = tokenResult.claims?['role'] as String?;

      if (roleStr != null) {
        try {
          state = UserRole.fromString(roleStr);
          logger.info('UserRoleNotifier', 'Role initialized from token: $roleStr');
        } catch (e) {
          logger.warning('UserRoleNotifier', 'Invalid role in token: $roleStr');
          state = UserRole.student; // Fallback to student
        }
      } else {
        logger.warning('UserRoleNotifier', 'No role claim in token');
        state = UserRole.student;
      }
    } catch (e) {
      logger.error('UserRoleNotifier', 'Failed to initialize role from token: $e');
      state = UserRole.student;
    }
  }

  /// Refresh role from token (call after role change or app resume)
  Future<void> refreshFromToken() async {
    try {
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
        } catch (e) {
          logger.warning('UserRoleNotifier', 'Invalid role after refresh: $roleStr');
        }
      }
    } catch (e) {
      logger.error('UserRoleNotifier', 'Failed to refresh role: $e');
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

  // ❌ REMOVED: setRole() - role changes must go through Cloud Functions
  // ❌ REMOVED: toggleRole() - role switching not allowed
}

final userRoleProvider =
    NotifierProvider<UserRoleNotifier, UserRole>(UserRoleNotifier.new);
