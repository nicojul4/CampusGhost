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

  Stream<List<ReportModel>> watchAll() => watchCurrentUser();

  Stream<List<ReportModel>> watchIncident(String incidentId) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield const [];
      return;
    }
    await for (final values in _store.watchReports(user.uid)) {
      yield values
          .where((value) => value['IncidentId'] == incidentId)
          .map((value) => _toModel(value, values))
          .toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
  }

  Stream<List<ReportModel>> watchCurrentUser() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield const [];
      return;
    }
    await for (final values in _store.watchReports(user.uid)) {
      yield values.map((value) => _toModel(value, values)).toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
  }

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
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'unauthenticated');
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
    final reports = await _store.readReports(user.uid);
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
      'UserId': user.uid,
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
    await _store.saveReports(user.uid, reports);
    return ReportSubmissionResult(
        ReportSubmissionState.processed, reportId, incidentId);
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
    final resolved = lastReportAt != null &&
        lastReportAt.isBefore(DateTime.now().toUtc().subtract(
              const Duration(hours: 24),
            ));
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
