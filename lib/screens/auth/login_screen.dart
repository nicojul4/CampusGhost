import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../config/routes.dart';
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
  bool _obscure = true, _remember = true, _loading = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    UserModel? user;
    try {
      user = await const AuthService()
          .signIn(email: _email.text, password: _password.text);
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
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (user != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(children: [
                        Image.asset(
                          'image/LOGO-PRADITA-removebg-preview.png',
                          width: 200,
                          height: 86,
                          fit: BoxFit.contain,
                          semanticLabel: 'Logo Pradita University',
                        ),
                        const SizedBox(height: 15),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE7F3EA),
                                borderRadius: BorderRadius.circular(30),
                                border:
                                    Border.all(color: const Color(0xFFC8E3D0))),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 8, color: campusOrange),
                                  SizedBox(width: 7),
                                  Text('CAMPUSGHOST × PRADITA UNIVERSITY',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: campusGreen,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .5))
                                ])),
                        const SizedBox(height: 10),
                        const Text('Portal Fasilitas Mahasiswa',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: campusGreen,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5)),
                        const SizedBox(height: 3),
                        Text(
                            'Pantau, lapor, & kawal kenyamanan kampus Pradita.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13)),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: campusLine),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x100B6837),
                                      blurRadius: 22,
                                      offset: Offset(0, 7))
                                ]),
                            child: Form(
                                key: _formKey,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(children: [
                                        Icon(Icons.school_rounded,
                                            color: campusOrange, size: 19),
                                        SizedBox(width: 7),
                                        Text('PRADITA UNIVERSITY PORTAL',
                                            style: TextStyle(
                                                color: campusGreen,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                                letterSpacing: .7))
                                      ]),
                                      const SizedBox(height: 8),
                                      const Text('Selamat Datang, Mahasiswa!',
                                          style: TextStyle(
                                              color: campusGreen,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Masuk dengan akun institusi Pradita untuk memantau dan melaporkan sarana kampus.',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 12,
                                              height: 1.45)),
                                      const SizedBox(height: 18),
                                      const Text(
                                          'Email Mahasiswa / NIM Pradita',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                          controller: _email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons
                                                  .alternate_email_rounded),
                                              hintText:
                                                  'nama.mahasiswa@student.pradita.ac.id'),
                                          validator: (v) =>
                                              v == null || v.trim().length < 4
                                                  ? 'Masukkan email atau NIM'
                                                  : null),
                                      const SizedBox(height: 13),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Kata Sandi',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            TextButton(
                                                onPressed: () => ScaffoldMessenger
                                                        .of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Hubungi Bantuan Teknis ICT untuk bantuan akun.'))),
                                                child: const Text(
                                                    'Lupa kata sandi?',
                                                    style: TextStyle(
                                                        fontSize: 11)))
                                          ]),
                                      TextFormField(
                                          controller: _password,
                                          obscureText: _obscure,
                                          decoration: InputDecoration(
                                              prefixIcon: const Icon(
                                                  Icons.lock_outline_rounded),
                                              hintText: '••••••••',
                                              suffixIcon: IconButton(
                                                  onPressed: () => setState(
                                                      () =>
                                                          _obscure = !_obscure),
                                                  icon: Icon(_obscure
                                                      ? Icons
                                                          .visibility_outlined
                                                      : Icons
                                                          .visibility_off_outlined))),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Masukkan kata sandi'
                                                  : null),
                                      CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          dense: true,
                                          value: _remember,
                                          onChanged: (v) => setState(
                                              () => _remember = v ?? false),
                                          title: Text(
                                              'Ingat saya di perangkat ini',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant))),
                                      SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: FilledButton.icon(
                                              onPressed: _loading
                                                  ? null
                                                  : _login,
                                              icon: _loading
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white))
                                                  : const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 19),
                                              label: Text(
                                                  _loading
                                                      ? 'Memverifikasi akun...'
                                                      : 'Masuk Portal',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800)))),
                                      const SizedBox(height: 15),
                                      Row(children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Text('ATAU SSO KAMPUS',
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: .7))),
                                        const Expanded(child: Divider())
                                      ]),
                                      const SizedBox(height: 13),
                                      SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: OutlinedButton.icon(
                                              onPressed: () {
                                                _email.text =
                                                    'nicolas.julian@student.pradita.ac.id';
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Akun institusi Pradita siap digunakan.')));
                                              },
                                              icon: const Icon(
                                                  Icons
                                                      .assured_workload_rounded,
                                                  color: campusOrange),
                                              label: const Text(
                                                  'Masuk dengan SSO Pradita',
                                                  style: TextStyle(
                                                      color: campusGreen,
                                                      fontWeight:
                                                          FontWeight.w700)))),
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        Expanded(
                                            child: OutlinedButton.icon(
                                                onPressed: () => ScaffoldMessenger
                                                        .of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Sensor biometrik Pradita Gateway aktif.'))),
                                                icon: const Icon(
                                                    Icons.fingerprint,
                                                    size: 19),
                                                label:
                                                    const Text('Biometrik'))),
                                        const SizedBox(width: 9),
                                        Expanded(
                                            child: OutlinedButton.icon(
                                                onPressed: () => Navigator
                                                    .pushReplacementNamed(
                                                        context,
                                                        AppRoutes.dashboard),
                                                icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 18),
                                                label: const Text('Mode Tamu')))
                                      ]),
                                    ]))),
                        const SizedBox(height: 18),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Belum punya akun?',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 13)),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context, AppRoutes.register),
                                child: const Text('Daftar'),
                              ),
                            ]),
                        const SizedBox(height: 15),
                        const Text('Scientia Business Park, Gading Serpong',
                            style: TextStyle(
                                color: campusGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            'Layanan Pradita University  •  Bantuan Teknis Pradita  •  Kebijakan Privasi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 10)),
                      ]))))));
}
