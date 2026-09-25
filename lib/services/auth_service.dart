import '../models/user_model.dart';

/// Autentikasi lokal untuk kebutuhan prototype, tanpa server.
class AuthService {
  const AuthService();

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (email.trim().isEmpty || password.isEmpty) return null;
    return UserModel.demo;
  }

  Future<void> signOut() async {}
}
