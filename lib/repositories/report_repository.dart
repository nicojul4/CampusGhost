import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

import '../enums/report_status.dart';
import '../models/report_model.dart';
import '../services/local_campus_store.dart';
import '../services/report_photo_codec.dart';

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
  ReportRepository(this._store, this._auth);

  final LocalCampusStore _store;
  final FirebaseAuth _auth;

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

    final activeIncident = reports.where((report) =>
        report['LocationId'] == locationId &&
        report['Category'] == category &&
        DateTime.tryParse(report['CreatedAt'] as String? ?? '')
                ?.isAfter(now.subtract(const Duration(hours: 24))) ==
            true);
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
    reports.add(record);
    await _store.saveReports(userId, reports);
    return ReportSubmissionResult(
        ReportSubmissionState.processed, reportId, incidentId);
  }

  Future<void> updateReport({
    required String reportId,
    String? description,
    ReportStatus? status,
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
    existing['UpdatedAt'] = now.toIso8601String();
    reports[index] = existing;
    await _store.saveReports(userId, reports);
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
    final incidentId = value['IncidentId'];
    final incidentReports = allReports.where(
        (report) => report['IncidentId'] == incidentId && incidentId != null);
    final lastReportAt = incidentReports
        .map(
            (report) => DateTime.tryParse(report['CreatedAt'] as String? ?? ''))
        .whereType<DateTime>()
        .fold<DateTime?>(
            null,
            (latest, date) =>
                latest == null || date.isAfter(latest) ? date : latest);
    final explicitlyResolved =
        value['Status'] == ReportStatus.resolved.value;
    final autoResolved = lastReportAt != null &&
        lastReportAt.isBefore(DateTime.now().toUtc().subtract(
              const Duration(hours: 24),
            ));
    final resolved = explicitlyResolved || autoResolved;
    return ReportModel(
      id: value['Id'] as String? ?? '',
      userId: value['UserId'] as String? ?? '',
      locationId: value['LocationId'] as String? ?? '',
      category: value['Category'] as String? ?? 'Lainnya',
      description: value['Description'] as String? ?? '',
      photoUrl: value['PhotoUrl'] as String?,
      status: resolved ? ReportStatus.resolved : ReportStatus.active,
      incidentId: value['IncidentId'] as String?,
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(value['UpdatedAt'] as String? ?? ''),
    );
  }

  String _newId(DateTime now) {
    final random = Random.secure();
    final suffix =
        List.generate(18, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${now.microsecondsSinceEpoch}_$suffix';
  }
}
