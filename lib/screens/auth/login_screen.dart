import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/routes.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/campus_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _loading || _googleLoading) return;
    setState(() => _loading = true);
    UserModel? user;
    try {
      user = await const AuthService().signIn(
        email: _email.text,
        password: _password.text,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        final message = error.code == 'user-not-found' ||
                error.code == 'wrong-password' ||
                error.code == 'invalid-credential'
            ? 'Email atau kata sandi tidak sesuai.'
            : 'Gagal masuk. Periksa konfigurasi Firebase dan koneksi Anda.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } on FirebaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Gagal masuk. Periksa koneksi internet lalu coba kembali.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    }
  }

  Future<void> _loginWithGoogle() async {
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
            'Gagal masuk dengan Google: ${error.message ?? error.code}',
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Gagal masuk dengan Google. Periksa koneksi internet Anda.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }

    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Image.asset(
                    'image/LOGO-PRADITA-removebg-preview.png',
                    width: 200,
                    height: 86,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo Pradita University',
                  ),
                  const SizedBox(height: 14),
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
                    'Portal Fasilitas Mahasiswa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? colors.primary : campusGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pantau, lapor, & kawal kenyamanan kampus Pradita.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 22),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school_rounded,
                                  color: campusOrange, size: 19),
                              const SizedBox(width: 8),
                              Text(
                                'PRADITA UNIVERSITY PORTAL',
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
                          const SizedBox(height: 8),
                          Text(
                            'Selamat Datang, Mahasiswa!',
                            style: TextStyle(
                              color: isDark ? colors.primary : campusGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Masuk dengan akun institusi Pradita untuk memantau dan melaporkan sarana kampus.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email Mahasiswa / NIM Pradita',
                              prefixIcon:
                                  Icon(Icons.alternate_email_rounded),
                              hintText:
                                  'nama.mahasiswa@student.pradita.ac.id',
                            ),
                            validator: (v) =>
                                v == null || v.trim().length < 4
                                    ? 'Masukkan email atau NIM'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Tampilkan kata sandi'
                                    : 'Sembunyikan kata sandi',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Masukkan kata sandi'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _remember = !_remember),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _remember,
                                            onChanged: (v) => setState(
                                                () => _remember = v ?? false),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Ingat saya di perangkat ini',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Hubungi Bantuan Teknis ICT untuk bantuan akun.'),
                                )),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Lupa kata sandi?',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed:
                                  _loading || _googleLoading ? null : _login,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded,
                                      size: 19),
                              label: Text(
                                _loading
                                    ? 'Memverifikasi akun...'
                                    : 'Masuk Portal',
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
                                  'ATAU MASUK DENGAN',
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
                            label: 'Masuk dengan Akun Google',
                            isLoading: _googleLoading,
                            onPressed:
                                _loading || _googleLoading
                                    ? null
                                    : _loginWithGoogle,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Sensor biometrik Pradita Gateway aktif.'),
                                  )),
                                  icon: const Icon(Icons.fingerprint, size: 19),
                                  label: const Text('Biometrik'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.dashboard,
                                  ),
                                  icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 18),
                                  label: const Text('Mode Tamu'),
                                ),
                              ),
                            ],
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
                        'Belum punya akun?',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _loading || _googleLoading
                            ? null
                            : () => Navigator.pushNamed(
                                context, AppRoutes.register),
                        child: const Text(
                          'Daftar Sekarang',
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
