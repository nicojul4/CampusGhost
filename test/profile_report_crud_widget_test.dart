import 'package:campus_ghost/providers/firebase_provider.dart';
import 'package:campus_ghost/providers/report_provider.dart';
import 'package:campus_ghost/repositories/report_repository.dart';
import 'package:campus_ghost/screens/profile/profile_screen.dart';
import 'package:campus_ghost/services/local_campus_store.dart';
import 'package:campus_ghost/widgets/theme_mode_scope.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

class _MockUser extends Fake implements User {
  @override
  String get uid => 'tester_123';
  @override
  String? get displayName => 'Mahasiswa Test';
  @override
  String? get email => 'test@student.pradita.ac.id';
}

class _MockFirebaseAuth extends Fake implements FirebaseAuth {
  _MockFirebaseAuth(this.user);
  final User? user;
  @override
  User? get currentUser => user;
  @override
  Stream<User?> userChanges() => Stream.value(user);
}

void main() {
  testWidgets('ProfileScreen merender riwayat laporan dengan aksi Edit & Hapus',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockStorage = _FakeMemorySecureStorage();
    final store = LocalCampusStore(mockStorage, enableTimer: false);
    final mockUser = _MockUser();
    final mockAuth = _MockFirebaseAuth(mockUser);
    final reportRepo = ReportRepository(store, mockAuth);

    // Siapkan 1 laporan awal secara lokal
    await reportRepo.submitReport(
      locationId: 'gedung-1-lt3',
      category: 'Wifi',
      description: 'Laporan kendala koneksi awal untuk testing UI.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localCampusStoreProvider.overrideWithValue(store),
          firebaseAuthProvider.overrideWithValue(mockAuth),
          reportRepositoryProvider.overrideWithValue(reportRepo),
        ],
        child: ThemeModeScope(
          isDark: false,
          onChanged: (_) {},
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pastikan card riwayat laporan muncul
    expect(find.text('Wifi'), findsOneWidget);
    expect(find.text('Laporan kendala koneksi awal untuk testing UI.'),
        findsOneWidget);
    expect(find.text('Laporan Anda • Baru saja'), findsOneWidget);

    // Pastikan popup menu button ada di card laporan
    final menuButton = find.byTooltip('Opsi laporan');
    expect(menuButton, findsOneWidget);

    // Buka menu opsi
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit laporan'), findsOneWidget);
    expect(find.text('Hapus laporan'), findsOneWidget);

    // Tap 'Edit laporan' untuk membuka dialog Edit
    await tester.tap(find.text('Edit laporan'));
    await tester.pumpAndSettle();

    // Verifikasi dialog Edit muncul
    expect(find.text('Edit Laporan'), findsOneWidget);
    expect(find.text('Deskripsi Kendala'), findsOneWidget);
    expect(find.text('Status Laporan'), findsOneWidget);

    // Ganti deskripsi
    final descriptionField = find.byType(TextFormField);
    await tester.enterText(
        descriptionField, 'Deskripsi telah diperbarui melalui form UI.');
    await tester.pumpAndSettle();

    // Simpan perubahan
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    // Pastikan teks deskripsi baru tampil di riwayat laporan
    expect(find.text('Deskripsi telah diperbarui melalui form UI.'),
        findsOneWidget);

    // Sekarang uji HAPUS: Buka menu opsi lagi
    await tester.tap(find.byTooltip('Opsi laporan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Hapus laporan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi dialog konfirmasi hapus muncul
    expect(find.text('Hapus Laporan?'), findsOneWidget);

    // Konfirmasi hapus
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    // Verifikasi card sudah tidak ada dan empty state muncul
    expect(find.text('Belum ada laporan yang dibuat.'), findsOneWidget);

    store.dispose();
  });
}
