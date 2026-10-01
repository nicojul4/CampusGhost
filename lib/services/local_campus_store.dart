import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalCampusStore {
  LocalCampusStore(this._storage) {
    _expiryRefresh = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _changes.add(null),
    );
  }

  final FlutterSecureStorage _storage;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late final Timer _expiryRefresh;

  Stream<List<Map<String, dynamic>>> watchReports(String userId) async* {
    yield await readReports(userId);
    await for (final _ in _changes.stream) {
      yield await readReports(userId);
    }
  }

  Future<List<Map<String, dynamic>>> readReports(String userId) async {
    final raw = await _storage.read(key: _key(userId));
    if (raw == null) return [];
    final values = jsonDecode(raw);
    if (values is! List) {
      throw const FormatException('Data laporan lokal tidak valid.');
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> saveReports(
      String userId, List<Map<String, dynamic>> reports) async {
    await _storage.write(key: _key(userId), value: jsonEncode(reports));
    _changes.add(null);
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
    _expiryRefresh.cancel();
    _changes.close();
  }
}
