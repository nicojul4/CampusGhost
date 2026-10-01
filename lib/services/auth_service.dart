import '../repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthService {
  const AuthService();

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    final user = await AuthRepository().signIn(
      email: email.trim(),
      password: password,
    );
    return UserModel(
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
    final user = await AuthRepository().register(
      name: name,
      email: email,
      password: password,
    );
    return UserModel(
      name: name.trim(),
      email: user.email ?? email.trim(),
      studentId: '',
      program: 'Mahasiswa',
    );
  }

  Future<void> signOut() => AuthRepository().signOut();
}
