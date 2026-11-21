import 'package:campus_ghost/screens/auth/login_screen.dart';
import 'package:campus_ghost/screens/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets(
        'menampilkan UI login yang diperbarui dan tombol Akun Google tanpa SSO',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan branding Pradita & Portal Fasilitas Mahasiswa muncul
      expect(find.text('Portal Fasilitas Mahasiswa'), findsOneWidget);
      expect(find.text('Selamat Datang, Mahasiswa!'), findsOneWidget);

      // Memastikan input email & kata sandi ada
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Masuk Portal'), findsOneWidget);

      // Memastikan fitur SSO telah dihapus
      expect(find.text('ATAU SSO KAMPUS'), findsNothing);
      expect(find.text('Masuk dengan SSO Pradita'), findsNothing);

      // Memastikan fitur Masuk dengan Akun Google hadir
      expect(find.text('ATAU MASUK DENGAN'), findsOneWidget);
      expect(find.text('Masuk dengan Akun Google'), findsOneWidget);

      // Memastikan aksi navigasi daftar ada
      expect(find.text('Daftar Sekarang'), findsOneWidget);
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('menampilkan UI registrasi lengkap dan tombol Akun Google',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan branding & form registrasi
      expect(find.text('Daftar Akun Mahasiswa'), findsOneWidget);
      expect(find.text('Lengkapi Data Diri'), findsOneWidget);

      // 4 input: Nama, Email, Password, Confirm Password
      expect(find.byType(TextFormField), findsNWidgets(4));

      // Memastikan tombol Daftar hadir
      expect(find.text('Daftar'), findsOneWidget);

      // Memastikan tombol Akun Google di form registrasi hadir
      expect(find.text('ATAU DAFTAR DENGAN'), findsOneWidget);
      expect(find.text('Daftar dengan Akun Google'), findsOneWidget);

      // Navigasi kembali ke Masuk
      expect(find.text('Sudah punya akun?'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
    });
  });
}
