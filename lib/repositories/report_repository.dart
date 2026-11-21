import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

import '../enums/report_status.dart';
import '../models/report_model.dart';
import '../services/firestore_report_service.dart';
import '../services/local_campus_store.dart';
import '../services/report_photo_codec.dart';
import '../utils/logger.dart';

enum ReportSubmissionState { processed, duplicate, processing }

class ReportSubmissionResult {
  const ReportSubmissionResult(this.state, this.reportId, this.incidentId);

  final ReportSubmissionState state;
  final String reportId;
  final String? incidentId;
}

class LocalPhotoStorageLimitException implements Exception {}

class RequiredReportPhotoException implements Exception {}

class InvalidReportPhotoException implements Exception {}

class ReportRepository {
  ReportRepository(
    this._store,
    this._auth, {
    FirestoreReportService? firestoreService,
  }) : _firestoreService = firestoreService;

  final LocalCampusStore _store;
  final FirebaseAuth _auth;
  final FirestoreReportService? _firestoreService;

  String _currentUserId() => _auth.currentUser?.uid ?? 'guest_user';

  Stream<List<ReportModel>> watchReportsForUser([String? targetUserId]) async* {
    final userId = targetUserId ?? _currentUserId();
    await for (final values in _store.watchReports(userId)) {
      yield values.map((value) => _toModel(value, values)).toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
  }

  Stream<List<ReportModel>> watchAll([String? targetUserId]) =>
      watchCurrentUser(targetUserId);

  Stream<List<ReportModel>> watchIncident(String incidentId,
      [String? targetUserId]) async* {
    final userId = targetUserId ?? _currentUserId();
    await for (final values in _store.watchReports(userId)) {
      yield values
          .where((value) => value['IncidentId'] == incidentId)
          .map((value) => _toModel(value, values))
          .toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
  }

  Stream<List<ReportModel>> watchCurrentUser([String? targetUserId]) =>
      watchReportsForUser(targetUserId);

  Future<String> createReport({
    required String locationId,
    required String category,
    required String description,
    String? photoUrl,
  }) async {
    final result = await submitReport(
      locationId: locationId,
      category: category,
      description: description,
      photoUrl: photoUrl,
    );
    if (result.state == ReportSubmissionState.duplicate) {
      throw StateError('duplicate_report');
    }
    return result.reportId;
  }

  Future<ReportSubmissionResult> createQuickReport({
    required String locationId,
    required String category,
  }) =>
      submitReport(
        locationId: locationId,
        category: category,
        description: 'Saya juga mengalami masalah ini.',
      );

  Future<ReportSubmissionResult> submitReport({
    required String locationId,
    required String category,
    required String description,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? locationDetail,
  }) async {
    final userId = _currentUserId();
    final photoBytes = decodeReportPhoto(photoUrl);
    if (photoUrl != null &&
        (photoBytes == null ||
            photoBytes.length > maxReportPhotoBytes ||
            detectReportPhotoMimeType(photoBytes) == null)) {
      throw InvalidReportPhotoException();
    }
    if (category != 'Wifi' && photoBytes == null) {
      throw RequiredReportPhotoException();
    }
    final reports = await _store.readReports(userId);
    final now = DateTime.now().toUtc();
    final isDuplicate = reports.any((report) =>
        report['LocationId'] == locationId &&
        report['Category'] == category &&
        DateTime.tryParse(report['CreatedAt'] as String? ?? '')
                ?.isAfter(now.subtract(const Duration(minutes: 5))) ==
            true);
    if (isDuplicate) {
      return const ReportSubmissionResult(
          ReportSubmissionState.duplicate, '', null);
    }
    final existingPhotoCharacters = reports.fold<int>(
      0,
      (total, report) => total + (report['PhotoUrl'] as String? ?? '').length,
    );
    if (photoUrl != null &&
        existingPhotoCharacters + photoUrl.length >
            maxLocalPhotoDataCharacters) {
      throw LocalPhotoStorageLimitException();
    }

    final activeIncident = reports.where((report) {
      // Validasi field wajib untuk grouping
      if (report['LocationId'] != locationId) {
        return false;
      }
      if (report['Category'] != category) {
        return false;
      }

      // Validasi CreatedAt
      final createdAtStr = report['CreatedAt'] as String?;
      final createdAt =
          createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      if (createdAt == null) {
        return false;
      }
      if (!createdAt.isAfter(now.subtract(const Duration(hours: 24)))) {
        return false;
      }

      // Validasi IncidentId: harus tersedia dan valid untuk grouping
      final incidentIdRaw = report['IncidentId'];
      if (incidentIdRaw == null) {
        return false;
      }
      if (incidentIdRaw is! String) {
        return false;
      }
      if (incidentIdRaw.trim().isEmpty) {
        return false;
      }

      return true;
    });
    final incidentId = activeIncident.isEmpty
        ? _newId(now)
        : activeIncident.first['IncidentId'] as String;
    final reportId = _newId(now);
    final record = <String, dynamic>{
      'Id': reportId,
      'UserId': userId,
      'LocationId': locationId,
      'Category': category,
      'Description': description,
      'Status': ReportStatus.active.value,
      'IncidentId': incidentId,
      'CreatedAt': now.toIso8601String(),
      'UpdatedAt': now.toIso8601String(),
    };
    if (photoUrl != null) record['PhotoUrl'] = photoUrl;
    if (latitude != null) record['Latitude'] = latitude;
    if (longitude != null) record['Longitude'] = longitude;
    if (locationDetail != null) record['LocationDetail'] = locationDetail;
    reports.add(record);
    await _store.saveReports(userId, reports);

    if (_firestoreService != null) {
      try {
        logger.info('ReportRepository',
            'Creating report in Firestore for location: $locationId, category: $category');
        await _firestoreService.createReport(
          category: category,
          locationId: locationId,
          description: description,
          userId: userId,
          photoUrl: photoUrl,
          latitude: latitude,
          longitude: longitude,
          locationDetail: locationDetail,
        );
        logger.info(
            'ReportRepository', 'Report created in Firestore successfully');
      } catch (e, stackTrace) {
        logger.errorWithStack('ReportRepository',
            'Failed to create report in Firestore', e, stackTrace);
        // Fallback aman: data tetap tersimpan persisten di LocalCampusStore
      }
    }

    return ReportSubmissionResult(
        ReportSubmissionState.processed, reportId, incidentId);
  }

  Future<void> updateReport({
    required String reportId,
    String? description,
    ReportStatus? status,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? locationDetail,
  }) async {
    final userId = _currentUserId();
    final reports = await _store.readReports(userId);
    final index = reports.indexWhere((report) => report['Id'] == reportId);
    if (index == -1) {
      throw StateError('report_not_found');
    }
    final existing = Map<String, dynamic>.from(reports[index]);
    final now = DateTime.now().toUtc();
    if (description != null) {
      final trimmed = description.trim();
      if (trimmed.length < 10) {
        throw ArgumentError.value(
            description, 'description', 'Deskripsi minimal 10 karakter.');
      }
      existing['Description'] = trimmed;
    }
    if (status != null) {
      existing['Status'] = status.value;
    }
    if (photoUrl != null) {
      if (photoUrl.isEmpty) {
        existing.remove('PhotoUrl');
      } else {
        final photoBytes = decodeReportPhoto(photoUrl);
        if (photoBytes == null ||
            photoBytes.length > maxReportPhotoBytes ||
            detectReportPhotoMimeType(photoBytes) == null) {
          throw InvalidReportPhotoException();
        }
        existing['PhotoUrl'] = photoUrl;
      }
    }
    if (latitude != null) existing['Latitude'] = latitude;
    if (longitude != null) existing['Longitude'] = longitude;
    if (locationDetail != null) existing['LocationDetail'] = locationDetail;
    existing['UpdatedAt'] = now.toIso8601String();
    reports[index] = existing;
    await _store.saveReports(userId, reports);

    if (_firestoreService != null && status != null) {
      try {
        logger.info('ReportRepository',
            'Updating report status in Firestore: $reportId to ${status.value}');
        await _firestoreService.updateReportStatus(
          reportId: reportId,
          status: status,
        );
        logger.info('ReportRepository', 'Report status updated successfully');
      } catch (e, stackTrace) {
        logger.errorWithStack('ReportRepository',
            'Failed to update report status in Firestore', e, stackTrace);
        // Fallback: penyimpanan lokal sudah diperbarui
      }
    }
  }

  Future<void> deleteReport(String reportId) async {
    final userId = _currentUserId();
    final removed = await _store.deleteReport(userId, reportId);
    if (!removed) {
      throw StateError('report_not_found');
    }
  }

  ReportModel _toModel(
      Map<String, dynamic> value, List<Map<String, dynamic>> allReports) {
    final createdAt = DateTime.tryParse(value['CreatedAt'] as String? ?? '');

    // Validasi IncidentId sebelum digunakan untuk grouping
    final incidentIdRaw = value['IncidentId'];
    String? incidentId;
    if (incidentIdRaw != null &&
        incidentIdRaw is String &&
        incidentIdRaw.trim().isNotEmpty) {
      incidentId = incidentIdRaw;
    }

    // Hitung lastReportAt hanya jika incidentId valid
    DateTime? lastReportAt;
    if (incidentId != null) {
      final incidentReports = allReports.where((report) {
        final rIncidentId = report['IncidentId'];
        if (rIncidentId == null ||
            rIncidentId is! String ||
            rIncidentId.trim().isEmpty) {
          return false;
        }
        return rIncidentId == incidentId;
      });

      lastReportAt = incidentReports
          .map((report) {
            final rCreatedAt = report['CreatedAt'] as String?;
            return rCreatedAt != null ? DateTime.tryParse(rCreatedAt) : null;
          })
          .whereType<DateTime>()
          .fold<DateTime?>(
              null,
              (latest, date) =>
                  latest == null || date.isAfter(latest) ? date : latest);
    }

    final explicitlyResolved = value['Status'] == ReportStatus.resolved.value;
    final autoResolved = lastReportAt != null &&
        lastReportAt.isBefore(
          DateTime.now().toUtc().subtract(
                const Duration(hours: 24),
              ),
        );
    final resolved = explicitlyResolved || autoResolved;
    final latRaw = value['Latitude'];
    final lngRaw = value['Longitude'];
    return ReportModel(
      id: value['Id'] as String? ?? '',
      userId: value['UserId'] as String? ?? '',
      locationId: value['LocationId'] as String? ?? '',
      category: value['Category'] as String? ?? 'Lainnya',
      description: value['Description'] as String? ?? '',
      photoUrl: value['PhotoUrl'] as String?,
      status: resolved ? ReportStatus.resolved : ReportStatus.active,
      incidentId: incidentId,
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(value['UpdatedAt'] as String? ?? ''),
      latitude: latRaw is num ? latRaw.toDouble() : null,
      longitude: lngRaw is num ? lngRaw.toDouble() : null,
      locationDetail: value['LocationDetail'] as String?,
    );
  }

  String _newId(DateTime now) {
    final random = Random.secure();
    final suffix =
        List.generate(18, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${now.microsecondsSinceEpoch}_$suffix';
  }
}
