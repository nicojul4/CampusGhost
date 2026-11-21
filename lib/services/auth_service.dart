import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';

class AuthService {
  const AuthService();

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    logger.info('AuthService', 'Signing in user (email masked)');
    
    final user = await AuthRepository().signIn(
      email: email.trim(),
      password: password,
    );
    
    logger.info('AuthService', 'User signed in successfully');
    
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? user.email?.split('@').first ?? 'Mahasiswa',
      email: user.email ?? email,
      studentId: '',
      program: 'Mahasiswa',
    );
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    logger.info('AuthService', 'Registering new user (email masked)');
    
    final user = await AuthRepository().register(
      name: name,
      email: email,
      password: password,
    );
    
    logger.info('AuthService', 'User registered successfully');
    
    // Wait for Custom Claims to be set by onCreate trigger
    await _waitForCustomClaims(user.uid);
    
    // Force token refresh to get claims
    await user.getIdToken(true);
    
    return UserModel(
      uid: user.uid,
      name: name.trim(),
      email: user.email ?? email.trim(),
      studentId: '',
      program: 'Mahasiswa',
    );
  }

  /// Wait for Custom Claims to be set after registration
  /// onCreate trigger sets role: 'student' asynchronously
  Future<void> _waitForCustomClaims(String uid, {int maxAttempts = 10}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) break;

        final tokenResult = await user.getIdTokenResult();
        
        if (tokenResult.claims?['role'] != null) {
          logger.info('AuthService', 'Custom Claims detected after ${i + 1} attempts');
          return;
        }
        
        // Exponential backoff: 100ms, 200ms, 400ms, 800ms, ...
        final delay = Duration(milliseconds: 100 * (1 << i));
        logger.info('AuthService', 'Waiting for Custom Claims, attempt ${i + 1}/$maxAttempts');
        await Future.delayed(delay);
      } catch (e) {
        logger.warning('AuthService', 'Error checking Custom Claims: $e');
      }
    }
    
    logger.warning('AuthService', 'Custom Claims not detected after $maxAttempts attempts (non-fatal)');
    // Non-fatal: user can still use app, reconciliation will fix later
  }

  Future<UserModel?> signInWithGoogle() async {
    logger.info('AuthService', 'Initiating Google Sign-In');
    
    final user = await AuthRepository().signInWithGoogle();
    
    if (user.email != null) {
      logger.info('AuthService', 'Google Sign-In successful (email masked)');
    } else {
      logger.warning('AuthService', 'Google Sign-In returned null email');
    }
    
    // Wait for claims if this is first-time registration
    final isNewUser = user.metadata.creationTime == user.metadata.lastSignInTime;
    if (isNewUser) {
      await _waitForCustomClaims(user.uid);
      await user.getIdToken(true);
    }
    
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? user.email?.split('@').first ?? 'Mahasiswa',
      email: user.email ?? '',
      studentId: '',
      program: 'Mahasiswa',
    );
  }

  Future<void> signOut() {
    logger.info('AuthService', 'Signing out current user');
    return AuthRepository().signOut();
  }
}
