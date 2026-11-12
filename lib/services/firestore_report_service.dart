import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../enums/report_status.dart';
import '../models/report_model.dart';

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

  Stream<List<ReportModel>> watchReports() {
    return _reportsRef.snapshots().map((snapshot) {
      final items = snapshot.docs.map(_fromDoc).toList();
      items.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Future<List<ReportModel>> getReports() async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _reportsRef.get();
    } catch (e) {
      rethrow;
    }

    if (snapshot.docs.isEmpty) {
      await _seedInitialReports();
      snapshot = await _reportsRef.get();
    }

    final items = snapshot.docs.map(_fromDoc).toList();
    items.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return items;
  }

  Future<ReportModel> createReport({
    required String category,
    required String locationId,
    required String description,
    String? photoUrl,
    String? userId,
    double? latitude,
    double? longitude,
    String? locationDetail,
  }) async {
    final now = DateTime.now().toUtc();
    final uid = userId ?? _auth.currentUser?.uid ?? 'user_campus';
    final docRef = _reportsRef.doc();

    final data = <String, dynamic>{
      'id': docRef.id,
      'Id': docRef.id,
      'userId': uid,
      'UserId': uid,
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

    await docRef.set(data);

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
    );
  }

  Future<void> _seedInitialReports() async {
    try {
      final now = DateTime.now().toUtc();
      final seeds = [
        {
          'category': 'Wifi',
          'locationId': 'Gedung 1 - Lantai 3',
          'description': 'Koneksi Wi-Fi di lantai 3 Gedung 1 sering terputus.',
          'status': 'Active',
        },
        {
          'category': 'Ac',
          'locationId': 'Gedung 2 - Ruang 202',
          'description':
              'AC di ruang 202 tidak dingin dan mengeluarkan bunyi bising.',
          'status': 'Active',
        },
        {
          'category': 'Proyektor',
          'locationId': 'Auditorium Utama',
          'description': 'Proyektor utama berkedip saat digunakan kuliah umum.',
          'status': 'Active',
        },
      ];

      for (var i = 0; i < seeds.length; i++) {
        final seed = seeds[i];
        final docRef = _reportsRef.doc();
        final created = now.subtract(Duration(hours: (i + 1) * 2));
        final data = <String, dynamic>{
          'id': docRef.id,
          'Id': docRef.id,
          'userId': 'seed_system',
          'UserId': 'seed_system',
          'locationId': seed['locationId'],
          'LocationId': seed['locationId'],
          'category': seed['category'],
          'Category': seed['category'],
          'description': seed['description'],
          'Description': seed['description'],
          'status': seed['status'],
          'Status': seed['status'],
          'createdAt': created.toIso8601String(),
          'CreatedAt': created.toIso8601String(),
          'updatedAt': created.toIso8601String(),
          'UpdatedAt': created.toIso8601String(),
        };
        await docRef.set(data);
      }
    } catch (_) {
      // Ignore seed error if write permissions or offline
    }
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
    );
  }
}
