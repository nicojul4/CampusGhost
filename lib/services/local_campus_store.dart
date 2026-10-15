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

  final FlutterSecureStorage _storage;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late final Timer? _expiryRefresh;

  Stream<List<Map<String, dynamic>>> watchReports(String userId) async* {
    yield await readReports(userId);
    await for (final _ in _changes.stream) {
      yield await readReports(userId);
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

  Future<void> saveReports(
      String userId, List<Map<String, dynamic>> reports) async {
    await _storage.write(key: _key(userId), value: jsonEncode(reports));
    _changes.add(null);
  }

  Future<void> updateReport(
      String userId, String reportId, Map<String, dynamic> updatedRecord) async {
    final reports = await readReports(userId);
    final index = reports.indexWhere((r) => r['Id'] == reportId);
    if (index != -1) {
      reports[index] = updatedRecord;
      await saveReports(userId, reports);
    }
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

  Future<String?> readProfilePhoto(String userId) =>
      _storage.read(key: _profilePhotoKey(userId));

  Future<void> saveProfilePhoto(String userId, String photoData) =>
      _storage.write(key: _profilePhotoKey(userId), value: photoData);

  Future<void> deleteProfilePhoto(String userId) =>
      _storage.delete(key: _profilePhotoKey(userId));

  String _key(String userId) => 'campus_ghost_reports_$userId';

  String _profilePhotoKey(String userId) =>
      'campus_ghost_profile_photo_$userId';

  void dispose() {
    _expiryRefresh?.cancel();
    _changes.close();
  }
}
