import 'dart:convert';

import 'package:campus_ghost/enums/report_status.dart';
import 'package:campus_ghost/repositories/report_repository.dart';
import 'package:campus_ghost/services/local_campus_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemorySecureStorage extends Fake implements FlutterSecureStorage {
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

class FakeUser extends Fake implements User {
  @override
  String get uid => 'user_test_123';
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth({this.mockUser});
  final User? mockUser;

  @override
  User? get currentUser => mockUser;
}

void main() {
  group('Local Data & Persistence - Report CRUD & Storage Verification', () {
    late InMemorySecureStorage memoryStorage;
    late LocalCampusStore store;
    late FakeFirebaseAuth auth;
    late ReportRepository repository;

    setUp(() {
      memoryStorage = InMemorySecureStorage();
      store = LocalCampusStore(memoryStorage);
      auth = FakeFirebaseAuth(mockUser: FakeUser());
      repository = ReportRepository(store, auth);
    });

    tearDown(() {
      store.dispose();
    });

    test('1. CREATE: Berhasil menambahkan data laporan ke local storage',
        () async {
      final result = await repository.submitReport(
        locationId: 'gedung-1-lt3',
        category: 'Wifi',
        description: 'Koneksi Wi-Fi di lantai 3 Gedung 1 terputus-putus.',
      );

      expect(result.state, ReportSubmissionState.processed);
      expect(result.reportId, isNotEmpty);

      // Verifikasi langsung ke data raw di local storage
      final rawData = memoryStorage.data['campus_ghost_reports_user_test_123'];
      expect(rawData, isNotNull);

      final List<dynamic> decoded = jsonDecode(rawData!);
      expect(decoded.length, 1);
      final record = decoded.first as Map<String, dynamic>;
      expect(record['Id'], result.reportId);
      expect(record['LocationId'], 'gedung-1-lt3');
      expect(record['Category'], 'Wifi');
      expect(record['Description'],
          'Koneksi Wi-Fi di lantai 3 Gedung 1 terputus-putus.');
      expect(record['Status'], ReportStatus.active.value);
      expect(record['UserId'], 'user_test_123');
      expect(record['CreatedAt'], isNotNull);
      expect(record['UpdatedAt'], isNotNull);
    });

    test('2. READ: Berhasil membaca data laporan dari local storage ke UI model',
        () async {
      await repository.submitReport(
        locationId: 'gedung-2-lt1',
        category: 'Wifi',
        description: 'Kecepatan Wi-Fi di lantai 1 Gedung 2 sangat lambat.',
      );

      final reports = await repository.watchCurrentUser().first;
      expect(reports.length, 1);
      final report = reports.first;
      expect(report.locationId, 'gedung-2-lt1');
      expect(report.category, 'Wifi');
      expect(report.description,
          'Kecepatan Wi-Fi di lantai 1 Gedung 2 sangat lambat.');
      expect(report.status, ReportStatus.active);
      expect(report.userId, 'user_test_123');
    });

    test(
        '3. UPDATE: Berhasil memperbarui deskripsi dan status laporan di local storage',
        () async {
      final result = await repository.submitReport(
        locationId: 'gedung-1-lt2',
        category: 'Wifi',
        description: 'Access Point di lab komputer mati mendadak.',
      );
      final reportId = result.reportId;

      // Update deskripsi dan status menjadi resolved
      await repository.updateReport(
        reportId: reportId,
        description: 'Access Point sudah menyala kembali setelah di-restart staf.',
        status: ReportStatus.resolved,
      );

      // Verifikasi melalui pembacaan model
      final updatedReports = await repository.watchCurrentUser().first;
      final updatedReport =
          updatedReports.firstWhere((r) => r.id == reportId);
      expect(updatedReport.description,
          'Access Point sudah menyala kembali setelah di-restart staf.');
      expect(updatedReport.status, ReportStatus.resolved);

      // Verifikasi di raw local storage
      final rawData =
          memoryStorage.data['campus_ghost_reports_user_test_123']!;
      final List<dynamic> decoded = jsonDecode(rawData);
      final record =
          decoded.firstWhere((r) => r['Id'] == reportId) as Map<String, dynamic>;
      expect(record['Description'],
          'Access Point sudah menyala kembali setelah di-restart staf.');
      expect(record['Status'], ReportStatus.resolved.value);
    });

    test('3b. UPDATE Validation: Menolak deskripsi kurang dari 10 karakter',
        () async {
      final result = await repository.submitReport(
        locationId: 'gedung-1-lt1',
        category: 'Wifi',
        description: 'Wi-Fi lantai 1 tidak bisa connect sama sekali.',
      );

      expect(
        () => repository.updateReport(
          reportId: result.reportId,
          description: 'Pendek',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('4. DELETE: Berhasil menghapus laporan dari local storage', () async {
      final result = await repository.submitReport(
        locationId: 'gedung-1-lt4',
        category: 'Wifi',
        description: 'Signal Wi-Fi hilang di ruang seminar lantai 4.',
      );
      final reportId = result.reportId;

      // Pastikan ada 1 data tersimpan
      var currentReports = await repository.watchCurrentUser().first;
      expect(currentReports.length, 1);

      // Hapus data
      await repository.deleteReport(reportId);

      // Pastikan data terhapus dari pembacaan model
      currentReports = await repository.watchCurrentUser().first;
      expect(currentReports.isEmpty, isTrue);

      // Pastikan data di raw local storage sudah kosong
      final rawData =
          memoryStorage.data['campus_ghost_reports_user_test_123']!;
      final List<dynamic> decoded = jsonDecode(rawData);
      expect(decoded.isEmpty, isTrue);
    });

    test('4b. DELETE Error: Melempar StateError jika reportId tidak ditemukan',
        () async {
      expect(
        () => repository.deleteReport('non_existent_report_id'),
        throwsA(isA<StateError>()),
      );
    });

    test(
        '5. PERSISTENCE: Data tetap tersedia setelah aplikasi dibuka kembali / instansiasi baru',
        () async {
      // Step A: Tulis data pada sesi pertama
      await repository.submitReport(
        locationId: 'gedung-3-lt1',
        category: 'Wifi',
        description: 'Jaringan Wi-Fi guest di lobi utama terputus.',
      );

      // Step B: Simulasikan penutupan sesi / restart aplikasi
      // Dispose store lama
      store.dispose();

      // Buat instance store dan repository baru dengan storage yang sama
      final reopenedStore = LocalCampusStore(memoryStorage);
      final reopenedRepository = ReportRepository(reopenedStore, auth);

      // Step C: Verifikasi data masih utuh dan persisten
      final persistentReports =
          await reopenedRepository.watchCurrentUser().first;
      expect(persistentReports.length, 1);
      expect(persistentReports.first.locationId, 'gedung-3-lt1');
      expect(persistentReports.first.description,
          'Jaringan Wi-Fi guest di lobi utama terputus.');
      expect(persistentReports.first.status, ReportStatus.active);

      // Step D: Modifikasi di sesi baru (Update)
      await reopenedRepository.updateReport(
        reportId: persistentReports.first.id,
        status: ReportStatus.resolved,
      );

      // Dispose store kedua dan buka ketiga untuk verifikasi persistence update
      reopenedStore.dispose();
      final thirdStore = LocalCampusStore(memoryStorage);
      final thirdRepository = ReportRepository(thirdStore, auth);

      final finalReports = await thirdRepository.watchCurrentUser().first;
      expect(finalReports.length, 1);
      expect(finalReports.first.status, ReportStatus.resolved);

      thirdStore.dispose();
    });

    test(
        '6. ERROR HANDLING: Data kosong atau rusak ditangani secara wajar tanpa crash',
        () async {
      // Kasus data rusak di storage
      memoryStorage.data['campus_ghost_reports_user_test_123'] =
          'corrupted_non_json_string';

      final reports = await store.readReports('user_test_123');
      expect(reports, isEmpty);

      // Kasus data bukan List
      memoryStorage.data['campus_ghost_reports_user_test_123'] =
          jsonEncode({'error': 'not a list'});
      final reports2 = await store.readReports('user_test_123');
      expect(reports2, isEmpty);
    });

    test('7. GUEST MODE: Berhasil CRUD saat unauthenticated menggunakan fallback guest_user',
        () async {
      final unauthenticatedAuth = FakeFirebaseAuth(mockUser: null);
      final guestRepo = ReportRepository(store, unauthenticatedAuth);

      // Create
      final result = await guestRepo.submitReport(
        locationId: 'gedung-tamu-lt1',
        category: 'Wifi',
        description: 'Laporan dibuat oleh pengguna dalam mode tamu kampus.',
      );
      expect(result.reportId, isNotEmpty);

      // Read
      final guestReports = await guestRepo.watchCurrentUser().first;
      expect(guestReports.length, 1);
      expect(guestReports.first.userId, 'guest_user');

      // Update
      await guestRepo.updateReport(
        reportId: result.reportId,
        status: ReportStatus.resolved,
      );
      final updatedGuestReports = await guestRepo.watchCurrentUser().first;
      expect(updatedGuestReports.first.status, ReportStatus.resolved);

      // Delete
      await guestRepo.deleteReport(result.reportId);
      final deletedGuestReports = await guestRepo.watchCurrentUser().first;
      expect(deletedGuestReports.isEmpty, isTrue);
    });
  });
}
