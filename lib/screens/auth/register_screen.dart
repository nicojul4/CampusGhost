import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/routes.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/campus_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _loading || _googleLoading) return;
    setState(() => _loading = true);
    try {
      await const AuthService().register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.dashboard, (route) => false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'email-already-in-use' => 'Email ini sudah terdaftar. Silakan masuk.',
        'invalid-email' => 'Format email tidak valid.',
        'weak-password' =>
          'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
        'operation-not-allowed' =>
          'Pendaftaran email belum diaktifkan pada proyek Firebase.',
        'network-request-failed' =>
          'Tidak dapat terhubung. Periksa koneksi internet Anda.',
        _ =>
          'Pendaftaran gagal. Periksa kembali data dan konfigurasi Firebase.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Pendaftaran gagal karena layanan akun bermasalah. Coba kembali sebentar lagi.'),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    if (_loading || _googleLoading) return;
    setState(() => _googleLoading = true);
    UserModel? user;
    try {
      user = await const AuthService().signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        final message = switch (error.code) {
          'popup-closed-by-user' => 'Proses masuk Google dibatalkan.',
          'account-exists-with-different-credential' =>
            'Akun dengan email ini sudah terdaftar melalui metode lain.',
          'network-request-failed' =>
            'Tidak dapat terhubung. Periksa koneksi internet Anda.',
          _ =>
            'Gagal mendaftar dengan Google: ${error.message ?? error.code}',
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Gagal mendaftar dengan Google. Periksa koneksi internet Anda.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }

    if (!mounted) return;
    if (user != null) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.dashboard, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buat Akun',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          tooltip: 'Kembali ke halaman masuk',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'web/icons/Ghost Campus Map Pin Icon.png',
                          width: 44,
                          height: 44,
                          cacheWidth: 120,
                          cacheHeight: 120,
                          filterQuality: FilterQuality.medium,
                          fit: BoxFit.cover,
                          semanticLabel: 'Logo CampusGhost',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Image.asset(
                        'image/LOGO-PRADITA-removebg-preview.png',
                        width: 170,
                        height: 72,
                        cacheWidth: 380,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: 'Logo Pradita University',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2B21)
                          : const Color(0xFFE7F3EA),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E4633)
                            : const Color(0xFFC8E3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 8, color: campusOrange),
                        const SizedBox(width: 8),
                        Text(
                          'CAMPUSGHOST × PRADITA UNIVERSITY',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark
                                ? const Color(0xFF8FE1AA)
                                : campusGreen,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Daftar Akun Mahasiswa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? colors.primary : campusGreen,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Buat akun untuk memantau dan melaporkan kondisi fasilitas kampus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.outline),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : const Color(0x0E0B6837),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.how_to_reg_rounded,
                                  color: campusOrange, size: 19),
                              const SizedBox(width: 8),
                              Text(
                                'REGISTRASI MAHASISWA',
                                style: TextStyle(
                                  color:
                                      isDark ? colors.primary : campusGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: .7,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Lengkapi Data Diri',
                            style: TextStyle(
                              color: isDark ? colors.primary : campusGreen,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gunakan email Pradita atau email aktif untuk verifikasi akun Anda.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nama Lengkap',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              hintText: 'Nama sesuai kartu mahasiswa',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Masukkan nama lengkap'
                                    : null,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email Akun',
                              prefixIcon:
                                  Icon(Icons.alternate_email_rounded),
                              hintText: 'nama@student.pradita.ac.id',
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return email.contains('@') && email.contains('.')
                                  ? null
                                  : 'Masukkan alamat email yang valid';
                            },
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              hintText: 'Minimal 6 karakter',
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Tampilkan kata sandi'
                                    : 'Sembunyikan kata sandi',
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (value) =>
                                value == null || value.length < 6
                                    ? 'Kata sandi minimal 6 karakter'
                                    : null,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _confirmPassword,
                            obscureText: _obscureConfirmation,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _register(),
                            decoration: InputDecoration(
                              labelText: 'Ulangi Kata Sandi',
                              prefixIcon:
                                  const Icon(Icons.lock_reset_rounded),
                              hintText: 'Ketik ulang kata sandi Anda',
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmation
                                    ? 'Tampilkan kata sandi'
                                    : 'Sembunyikan kata sandi',
                                onPressed: () => setState(() =>
                                    _obscureConfirmation =
                                        !_obscureConfirmation),
                                icon: Icon(_obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (value) => value != _password.text
                                ? 'Kata sandi belum sama'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _loading || _googleLoading
                                  ? null
                                  : _register,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1_rounded,
                                      size: 19),
                              label: Text(
                                _loading ? 'Mendaftarkan akun...' : 'Daftar',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'ATAU DAFTAR DENGAN',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .8,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GoogleSignInButton(
                            label: 'Daftar dengan Akun Google',
                            isLoading: _googleLoading,
                            onPressed: _loading || _googleLoading
                                ? null
                                : _registerWithGoogle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun?',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        ),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scientia Business Park, Gading Serpong',
                    style: TextStyle(
                      color: isDark ? colors.primary : campusGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Layanan Pradita University  •  Bantuan Teknis Pradita  •  Kebijakan Privasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
