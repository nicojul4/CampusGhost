import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalCampusStore {
  LocalCampusStore(this._storage, {bool enableTimer = true}) {
    if (enableTimer) {
      _expiryRefresh = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _changes.add(null),
      );
    } else {
      _expiryRefresh = null;
    }
  }

  static const _usersIndexKey = 'campus_ghost_report_users';

  final FlutterSecureStorage _storage;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late final Timer? _expiryRefresh;

  Stream<List<Map<String, dynamic>>> watchReports(String userId) async* {
    yield await readReports(userId);
    await for (final _ in _changes.stream) {
      yield await readReports(userId);
    }
  }

  /// Stream semua laporan dari seluruh akun pengguna yang tersimpan secara lokal
  /// (digunakan oleh Teknisi GA & Satpam untuk memantau seluruh antrean tiket).
  Stream<List<Map<String, dynamic>>> watchAllReports() async* {
    yield await readAllReports();
    await for (final _ in _changes.stream) {
      yield await readAllReports();
    }
  }

  Future<List<Map<String, dynamic>>> readReports(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return [];
      final values = jsonDecode(raw);
      if (values is! List) return [];
      return values
          .whereType<Map<String, dynamic>>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _readIndexedUserIds() async {
    try {
      final raw = await _storage.read(key: _usersIndexKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _registerUserId(String userId) async {
    final users = await _readIndexedUserIds();
    if (!users.contains(userId)) {
      users.add(userId);
      await _storage.write(key: _usersIndexKey, value: jsonEncode(users));
    }
  }

  /// Membaca seluruh laporan dari semua user yang tercatat di penyimpanan lokal.
  Future<List<Map<String, dynamic>>> readAllReports() async {
    final userIds = <String>{...await _readIndexedUserIds()};

    // Fallback scan via readAll() bila ada key lama sebelum index dibuat.
    try {
      final allEntries = await _storage.readAll();
      for (final key in allEntries.keys) {
        if (key.startsWith('campus_ghost_reports_')) {
          userIds.add(key.substring('campus_ghost_reports_'.length));
        }
      }
    } catch (_) {
      // Abaikan bila Fake storage di test tidak mengimplementasikan readAll().
    }

    final merged = <String, Map<String, dynamic>>{};
    for (final uid in userIds) {
      final list = await readReports(uid);
      for (final item in list) {
        final id = item['Id'] as String?;
        if (id != null && id.isNotEmpty) {
          merged[id] = item;
        }
      }
    }
    return merged.values.toList();
  }

  Future<void> saveReports(
      String userId, List<Map<String, dynamic>> reports) async {
    await _registerUserId(userId);
    await _storage.write(key: _key(userId), value: jsonEncode(reports));
    _changes.add(null);
  }

  Future<void> updateReport(String userId, String reportId,
      Map<String, dynamic> updatedRecord) async {
    final reports = await readReports(userId);
    final index = reports.indexWhere((r) => r['Id'] == reportId);
    if (index != -1) {
      reports[index] = updatedRecord;
      await saveReports(userId, reports);
    }
  }

  /// Mencari dan memperbarui laporan berdasarkan [reportId] di seluruh user
  /// (dipakai oleh Teknisi GA saat menangani laporan milik mahasiswa lain).
  Future<bool> updateReportAcrossUsers(
    String reportId,
    Map<String, dynamic> Function(Map<String, dynamic> current) updater, {
    String? preferredUserId,
  }) async {
    final userIds = <String>{
      if (preferredUserId != null && preferredUserId.isNotEmpty) preferredUserId,
      ...await _readIndexedUserIds(),
    };

    try {
      final allEntries = await _storage.readAll();
      for (final key in allEntries.keys) {
        if (key.startsWith('campus_ghost_reports_')) {
          userIds.add(key.substring('campus_ghost_reports_'.length));
        }
      }
    } catch (_) {}

    for (final uid in userIds) {
      final reports = await readReports(uid);
      final index = reports.indexWhere((r) => r['Id'] == reportId);
      if (index != -1) {
        reports[index] = updater(Map<String, dynamic>.from(reports[index]));
        await saveReports(uid, reports);
        return true;
      }
    }
    return false;
  }

  Future<bool> deleteReport(String userId, String reportId) async {
    final reports = await readReports(userId);
    final initialLength = reports.length;
    reports.removeWhere((r) => r['Id'] == reportId);
    if (reports.length != initialLength) {
      await saveReports(userId, reports);
      return true;
    }
    return false;
  }

  /// Menghapus seluruh cache laporan lokal dari semua akun (untuk reset sebelum demo).
  Future<void> clearAllReports() async {
    final userIds = <String>{...await _readIndexedUserIds()};
    try {
      final allEntries = await _storage.readAll();
      for (final key in allEntries.keys) {
        if (key.startsWith('campus_ghost_reports_')) {
          userIds.add(key.substring('campus_ghost_reports_'.length));
        }
      }
    } catch (_) {}

    for (final uid in userIds) {
      await _storage.delete(key: _key(uid));
    }
    await _storage.delete(key: _usersIndexKey);
    _changes.add(null);
  }

  Future<String?> readProfilePhoto(String userId) =>
      _storage.read(key: _profilePhotoKey(userId));

  Future<void> saveProfilePhoto(String userId, String photoData) =>
      _storage.write(key: _profilePhotoKey(userId), value: photoData);

  Future<void> deleteProfilePhoto(String userId) =>
      _storage.delete(key: _profilePhotoKey(userId));

  Future<String?> readProfileName(String userId) =>
      _storage.read(key: _profileNameKey(userId));

  Future<void> saveProfileName(String userId, String name) =>
      _storage.write(key: _profileNameKey(userId), value: name);

  static const _themeModeKey = 'campus_ghost_theme_mode';

  Future<bool?> readThemeMode() async {
    try {
      final raw = await _storage.read(key: _themeModeKey);
      if (raw == null || raw.isEmpty) return null;
      return raw == 'dark';
    } catch (_) {
      return null;
    }
  }

  Future<void> saveThemeMode(bool isDark) async {
    try {
      await _storage.write(
        key: _themeModeKey,
        value: isDark ? 'dark' : 'light',
      );
      _changes.add(null);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveJsonList(
      String key, List<Map<String, dynamic>> items) async {
    await _storage.write(key: key, value: jsonEncode(items));
    _changes.add(null);
  }

  String _key(String userId) => 'campus_ghost_reports_$userId';

  String _profilePhotoKey(String userId) =>
      'campus_ghost_profile_photo_$userId';

  String _profileNameKey(String userId) =>
      'campus_ghost_profile_name_$userId';

  void dispose() {
    _expiryRefresh?.cancel();
    _changes.close();
  }
}
