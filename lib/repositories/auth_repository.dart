import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    return user;
  }

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
    return user;
  }

  Future<User> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    provider.setCustomParameters({'prompt': 'select_account'});
    final UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(provider);
    } else {
      credential = await _auth.signInWithProvider(provider);
    }
    final user = credential.user;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    return user;
  }

  Future<void> signOut() => _auth.signOut();
}
