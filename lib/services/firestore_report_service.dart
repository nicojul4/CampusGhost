import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../enums/report_status.dart';
import '../models/report_model.dart';
import '../utils/logger.dart';

class FirestoreReportService {
  FirestoreReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection('reports');

  Stream<List<ReportModel>> watchReports({String? forUserId}) {
    final Query<Map<String, dynamic>> query = forUserId != null
        ? _reportsRef.where('userId', isEqualTo: forUserId)
        : _reportsRef;
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map(_fromDoc).toList();
      items.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Future<List<ReportModel>> getReports({String? forUserId}) async {
    logger.info('FirestoreReportService', 'Fetching reports from Firestore');
    final Query<Map<String, dynamic>> query = forUserId != null
        ? _reportsRef.where('userId', isEqualTo: forUserId)
        : _reportsRef;
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get();
      logger.info('FirestoreReportService', 'Successfully fetched ${snapshot.docs.length} reports');
    } catch (e, stackTrace) {
      logger.errorWithStack('FirestoreReportService', 'Failed to fetch reports from Firestore', e, stackTrace);
      rethrow;
    }

    final items = snapshot.docs.map(_fromDoc).toList();
    items.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return items;
  }

  Future<ReportModel> createReport({
    String? id,
    required String category,
    required String locationId,
    required String description,
    String? photoUrl,
    String? userId,
    String? reporterName,
    double? latitude,
    double? longitude,
    String? locationDetail,
  }) async {
    logger.info('FirestoreReportService', 'Creating report: location=$locationId, category=$category');
    final now = DateTime.now().toUtc();
    final uid = userId ?? _auth.currentUser?.uid ?? 'user_campus';
    final docRef = (id != null && id.trim().isNotEmpty)
        ? _reportsRef.doc(id.trim())
        : _reportsRef.doc();

    final data = <String, dynamic>{
      'id': docRef.id,
      'Id': docRef.id,
      'userId': uid,
      'UserId': uid,
      if (reporterName != null && reporterName.trim().isNotEmpty)
        'reporterName': reporterName.trim(),
      'locationId': locationId.trim(),
      'LocationId': locationId.trim(),
      'category': category.trim(),
      'Category': category.trim(),
      'description': description.trim(),
      'Description': description.trim(),
      'status': ReportStatus.active.value,
      'Status': ReportStatus.active.value,
      'createdAt': now.toIso8601String(),
      'CreatedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'UpdatedAt': now.toIso8601String(),
      if (photoUrl != null) ...{
        'photoUrl': photoUrl,
        'PhotoUrl': photoUrl,
      },
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationDetail != null) 'locationDetail': locationDetail,
    };

    try {
      await docRef.set(data);
      logger.info('FirestoreReportService', 'Report created successfully: ${docRef.id}');
    } catch (e, stackTrace) {
      logger.errorWithStack('FirestoreReportService', 'Failed to create report in Firestore', e, stackTrace);
      rethrow;
    }

    return ReportModel(
      id: docRef.id,
      userId: uid,
      locationId: locationId.trim(),
      category: category.trim(),
      description: description.trim(),
      status: ReportStatus.active,
      incidentId: null,
      createdAt: now,
      updatedAt: now,
      photoUrl: photoUrl,
      latitude: latitude,
      longitude: longitude,
      locationDetail: locationDetail,
      reporterName: reporterName?.trim(),
    );
  }

  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? assignedTo,
    String? technicianNote,
    DateTime? resolvedAt,
  }) async {
    logger.info('FirestoreReportService', 'Updating report $reportId status to ${status.value}');
    final now = DateTime.now().toUtc();
    try {
      await _reportsRef.doc(reportId).update({
        'status': status.value,
        'Status': status.value,
        'updatedAt': now.toIso8601String(),
        'UpdatedAt': now.toIso8601String(),
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (technicianNote != null) 'technicianNote': technicianNote,
        if (resolvedAt != null) 'resolvedAt': resolvedAt.toIso8601String(),
      });
      logger.info('FirestoreReportService', 'Report status updated successfully');
    } catch (e, stackTrace) {
      logger.errorWithStack('FirestoreReportService', 'Failed to update report status in Firestore', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteReport(String reportId) async {
    logger.info('FirestoreReportService', 'Deleting report $reportId from Firestore');
    try {
      await _reportsRef.doc(reportId).delete();
      logger.info('FirestoreReportService', 'Report deleted from Firestore');
    } catch (e, stackTrace) {
      logger.errorWithStack('FirestoreReportService', 'Failed to delete report from Firestore', e, stackTrace);
      rethrow;
    }
  }

  /// Menghapus seluruh dokumen laporan di Firestore yang dapat diakses user/staf saat ini
  /// (digunakan untuk mereset data demo agar antrean benar-benar bersih).
  Future<int> deleteAllAccessibleReports({String? forUserId}) async {
    final uid = forUserId ?? _auth.currentUser?.uid;
    final docsById = <String, DocumentReference<Map<String, dynamic>>>{};

    try {
      final allSnap = await _reportsRef.get();
      for (final doc in allSnap.docs) {
        docsById[doc.id] = doc.reference;
      }
    } catch (_) {
      // Jika rules membatasi query koleksi penuh, kueri milik user saat ini (camelCase & PascalCase)
      if (uid != null && uid.isNotEmpty) {
        try {
          final snapLower =
              await _reportsRef.where('userId', isEqualTo: uid).get();
          for (final doc in snapLower.docs) {
            docsById[doc.id] = doc.reference;
          }
        } catch (_) {}
        try {
          final snapUpper =
              await _reportsRef.where('UserId', isEqualTo: uid).get();
          for (final doc in snapUpper.docs) {
            docsById[doc.id] = doc.reference;
          }
        } catch (_) {}
      }
    }

    var deletedCount = 0;
    for (final ref in docsById.values) {
      try {
        await ref.delete();
        deletedCount++;
      } catch (e) {
        logger.warning('FirestoreReportService', 'Could not delete ${ref.id}: $e');
      }
    }
    logger.info('FirestoreReportService', 'Cleared $deletedCount Firestore demo reports');
    return deletedCount;
  }

  ReportModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final id = doc.id;
    final userId = data['userId'] ?? data['UserId'] ?? 'user_guest';
    final locationId = data['locationId'] ?? data['LocationId'] ?? '';
    final category = data['category'] ?? data['Category'] ?? 'Lainnya';
    final description = data['description'] ?? data['Description'] ?? '';
    final statusStr = data['status'] ?? data['Status'] ?? 'Active';
    final photoUrl = data['photoUrl'] ?? data['PhotoUrl'];
    final createdAtRaw = data['createdAt'] ?? data['CreatedAt'];
    final updatedAtRaw = data['updatedAt'] ?? data['UpdatedAt'];

    DateTime? createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    }

    DateTime? updatedAt;
    if (updatedAtRaw is String) {
      updatedAt = DateTime.tryParse(updatedAtRaw);
    } else if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    }

    final latRaw = data['latitude'] ?? data['Latitude'];
    final lngRaw = data['longitude'] ?? data['Longitude'];
    final resolvedAtRaw = data['resolvedAt'];
    DateTime? resolvedAt;
    if (resolvedAtRaw is String) {
      resolvedAt = DateTime.tryParse(resolvedAtRaw);
    } else if (resolvedAtRaw is Timestamp) {
      resolvedAt = resolvedAtRaw.toDate();
    }

    return ReportModel(
      id: id,
      userId: userId.toString(),
      locationId: locationId.toString(),
      category: category.toString(),
      description: description.toString(),
      status: ReportStatus.fromValue(statusStr.toString()),
      incidentId:
          data['incidentId']?.toString() ?? data['IncidentId']?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      photoUrl: photoUrl?.toString(),
      latitude: latRaw is num ? latRaw.toDouble() : null,
      longitude: lngRaw is num ? lngRaw.toDouble() : null,
      locationDetail: (data['locationDetail'] ?? data['LocationDetail'])?.toString(),
      assignedTo: data['assignedTo']?.toString(),
      technicianNote: data['technicianNote']?.toString(),
      reporterName: data['reporterName']?.toString(),
      resolvedAt: resolvedAt,
    );
  }
}
