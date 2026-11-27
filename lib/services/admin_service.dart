import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../enums/report_status.dart';
import '../enums/user_role.dart';
import '../models/admin_models.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import '../services/local_campus_store.dart';
import '../utils/logger.dart';

/// Layanan manajemen pengguna, penugasan tiket, dan audit untuk Administrator.
///
/// Mengintegrasikan Cloud Functions (`createTechnician`, `updateUserRole`,
/// `deactivateUser`, `reactivateUser`) dan koleksi Firestore `users` / `audit_logs`,
/// serta menyediakan fallback lokal di `kDebugMode` bila backend Functions
/// belum dideploy atau akun masih berjalan dalam mode preview/uji coba.
class AdminService {
  AdminService({
    required LocalCampusStore store,
    required FirebaseAuth auth,
    required ReportRepository reportRepository,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _store = store,
        _auth = auth,
        _reportRepo = reportRepository,
        _firestore = firestore,
        _functions = functions;

  static const _localUsersKey = 'campus_ghost_admin_users';
  static const _localAuditKey = 'campus_ghost_admin_audit_logs';

  final LocalCampusStore _store;
  final FirebaseAuth _auth;
  final ReportRepository _reportRepo;
  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  final StreamController<void> _localChanges =
      StreamController<void>.broadcast();

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    if (Firebase.apps.isNotEmpty) return FirebaseFirestore.instance;
    return null;
  }

  FirebaseFunctions? get _fn {
    if (_functions != null) return _functions;
    if (Firebase.apps.isNotEmpty) return FirebaseFunctions.instance;
    return null;
  }

  String _actorLabel() {
    final user = _auth.currentUser;
    if (user == null) return 'Administrator';
    try {
      final name = user.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    try {
      final email = user.email?.trim();
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {}
    return user.uid;
  }

  /// Stream daftar pengguna kampus (gabungan Firestore `users` + akun aktif + direktori lokal).
  Stream<List<CampusUserSummary>> watchUsers() {
    final controller = StreamController<List<CampusUserSummary>>();
    List<CampusUserSummary> localUsers = const [];
    List<CampusUserSummary> remoteUsers = const [];

    Future<void> refreshLocal() async {
      final raw = await _store.readJsonList(_localUsersKey);
      localUsers = raw.map((e) => CampusUserSummary.fromMap(e)).toList();
    }

    void emitMerged() {
      if (controller.isClosed) return;
      final merged = <String, CampusUserSummary>{};

      // Pastikan akun yang sedang login selalu tampil di direktori
      final current = _auth.currentUser;
      if (current != null) {
        String name = 'Pengguna';
        String email = '';
        try {
          name = (current.displayName?.trim().isNotEmpty == true)
              ? current.displayName!.trim()
              : (current.email?.split('@').first ?? 'Pengguna');
        } catch (_) {}
        try {
          email = current.email ?? '';
        } catch (_) {}
        merged[current.uid] = CampusUserSummary(
          uid: current.uid,
          email: email,
          displayName: name,
          role: UserRole.student,
          isActive: true,
        );
      }

      for (final u in remoteUsers) {
        if (u.uid.isNotEmpty) merged[u.uid] = u;
      }
      for (final u in localUsers) {
        if (u.uid.isNotEmpty) merged[u.uid] = u;
      }

      final list = merged.values.toList()
        ..sort((a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()));
      controller.add(list);
    }

    refreshLocal().then((_) => emitMerged());

    final localSub = _localChanges.stream.listen((_) async {
      await refreshLocal();
      emitMerged();
    });

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;
    final db = _db;
    if (db != null) {
      remoteSub = db.collection('users').snapshots().listen(
        (snap) {
          remoteUsers = snap.docs
              .map((doc) => CampusUserSummary.fromMap(doc.data(), id: doc.id))
              .toList();
          emitMerged();
        },
        onError: (Object error) {
          logger.info('AdminService', 'Firestore users read fallback: $error');
        },
      );
    }

    controller.onCancel = () async {
      await localSub.cancel();
      await remoteSub?.cancel();
    };

    return controller.stream;
  }

  /// Stream catatan audit sistem (gabungan Firestore `audit_logs` + log lokal).
  Stream<List<AuditLogEntry>> watchAuditLogs() {
    final controller = StreamController<List<AuditLogEntry>>();
    List<AuditLogEntry> localLogs = const [];
    List<AuditLogEntry> remoteLogs = const [];

    Future<void> refreshLocal() async {
      final raw = await _store.readJsonList(_localAuditKey);
      localLogs = raw.map((e) => AuditLogEntry.fromMap(e)).toList();
    }

    void emitMerged() {
      if (controller.isClosed) return;
      final merged = <String, AuditLogEntry>{};
      for (final item in remoteLogs) {
        merged[item.id] = item;
      }
      for (final item in localLogs) {
        merged[item.id] = item;
      }
      final list = merged.values.toList()
        ..sort((a, b) =>
            (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
      controller.add(list);
    }

    refreshLocal().then((_) => emitMerged());

    final localSub = _localChanges.stream.listen((_) async {
      await refreshLocal();
      emitMerged();
    });

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;
    final db = _db;
    if (db != null) {
      remoteSub = db
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen(
        (snap) {
          remoteLogs = snap.docs
              .map((doc) => AuditLogEntry.fromMap(doc.data(), id: doc.id))
              .toList();
          emitMerged();
        },
        onError: (Object error) {
          logger.info('AdminService', 'Firestore audit_logs fallback: $error');
        },
      );
    }

    controller.onCancel = () async {
      await localSub.cancel();
      await remoteSub?.cancel();
    };

    return controller.stream;
  }

  /// Membuat akun Teknisi GA baru (memanggil Cloud Function `createTechnician`).
  Future<bool> createTechnician({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final fn = _fn;
    if (fn != null) {
      try {
        await fn.httpsCallable('createTechnician').call({
          'displayName': displayName.trim(),
          'email': email.trim(),
          'password': password,
        });
        logger.info('AdminService', 'Technician created via Cloud Function');
        await _appendLocalAudit(
          action: 'create_technician',
          targetUser: email.trim(),
          summary: 'Membuat akun teknisi baru: ${displayName.trim()} (${email.trim()})',
        );
        return true;
      } on FirebaseFunctionsException catch (e) {
        if (!_canFallbackInPreview(e.code)) rethrow;
        logger.info('AdminService', 'createTechnician fallback (${e.code})');
      } catch (e) {
        if (!kDebugMode) rethrow;
        logger.info('AdminService', 'createTechnician debug fallback: $e');
      }
    }

    // Fallback mode demo lokal
    final uid = 'tech_${DateTime.now().millisecondsSinceEpoch}';
    final user = CampusUserSummary(
      uid: uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: UserRole.technician,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _upsertLocalUser(user);
    await _appendLocalAudit(
      action: 'create_technician',
      targetUser: uid,
      summary:
          'Membuat akun teknisi baru (Mode Lokal): ${displayName.trim()} (${email.trim()})',
    );
    return false;
  }

  /// Mengubah peran pengguna (`student`, `technician`, `admin`).
  Future<bool> updateUserRole({
    required CampusUserSummary targetUser,
    required UserRole newRole,
  }) async {
    var syncedRemote = false;
    final fn = _fn;
    if (fn != null) {
      try {
        await fn.httpsCallable('updateUserRole').call({
          'targetUid': targetUser.uid,
          'newRole': newRole.toClaimValue(),
        });
        logger.info('AdminService',
            'Updated role for ${targetUser.uid} -> ${newRole.name}');
        syncedRemote = true;
      } on FirebaseFunctionsException catch (e) {
        if (!_canFallbackInPreview(e.code)) rethrow;
        logger.info('AdminService', 'updateUserRole fallback (${e.code})');
      } catch (e) {
        if (!kDebugMode) rethrow;
        logger.info('AdminService', 'updateUserRole debug fallback: $e');
      }
    }

    await _patchLocalUser(targetUser, role: newRole);
    await _appendLocalAudit(
      action: 'update_role',
      targetUser: targetUser.uid,
      summary:
          'Mengubah peran ${targetUser.displayName}: ${targetUser.role.label} → ${newRole.label}',
    );
    return syncedRemote;
  }

  /// Mengaktifkan atau menonaktifkan akun pengguna.
  Future<bool> setUserActive({
    required CampusUserSummary targetUser,
    required bool activate,
    String? reason,
  }) async {
    var syncedRemote = false;
    final fn = _fn;
    if (fn != null) {
      try {
        if (activate) {
          await fn.httpsCallable('reactivateUser').call({
            'targetUid': targetUser.uid,
          });
        } else {
          await fn.httpsCallable('deactivateUser').call({
            'targetUid': targetUser.uid,
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
          });
        }
        syncedRemote = true;
      } on FirebaseFunctionsException catch (e) {
        if (!_canFallbackInPreview(e.code)) rethrow;
        logger.info('AdminService', 'setUserActive fallback (${e.code})');
      } catch (e) {
        if (!kDebugMode) rethrow;
        logger.info('AdminService', 'setUserActive debug fallback: $e');
      }
    }

    await _patchLocalUser(targetUser, isActive: activate);
    await _appendLocalAudit(
      action: activate ? 'reactivate_user' : 'deactivate_user',
      targetUser: targetUser.uid,
      summary: activate
          ? 'Mengaktifkan kembali akun ${targetUser.displayName}'
          : 'Menonaktifkan akun ${targetUser.displayName}',
    );
    return syncedRemote;
  }

  /// Menugaskan tiket laporan ke teknisi tertentu dan mencatat audit.
  Future<void> assignTicket({
    required ReportModel report,
    required String technicianName,
  }) async {
    final cleanTech = technicianName.trim();
    final nextStatus = report.status == ReportStatus.active
        ? ReportStatus.inProgress
        : report.status;

    await _reportRepo.updateTicketByTechnician(
      reportId: report.id,
      status: nextStatus,
      ownerUserId: report.userId,
      assignedTo: cleanTech,
    );

    await _appendLocalAudit(
      action: 'assign_ticket',
      targetUser: report.id,
      summary:
          'Menugaskan tiket ${report.category} (${report.locationId}) kepada $cleanTech',
    );
  }

  /// Menghapus laporan yang tidak valid / spam oleh Administrator.
  Future<void> deleteTicket(ReportModel report) async {
    await _store.deleteReport(report.userId, report.id);
    final db = _db;
    if (db != null) {
      try {
        await db.collection('reports').doc(report.id).delete();
      } catch (e) {
        logger.info('AdminService', 'Firestore deleteTicket skipped: $e');
      }
    }
    await _appendLocalAudit(
      action: 'delete_report',
      targetUser: report.id,
      summary:
          'Menghapus laporan ${report.category} di ${report.locationId}',
    );
  }

  bool _canFallbackInPreview(String code) {
    if (!kDebugMode) return false;
    return code == 'permission-denied' ||
        code == 'unauthenticated' ||
        code == 'unimplemented' ||
        code == 'not-found' ||
        code == 'unavailable';
  }

  Future<void> _patchLocalUser(
    CampusUserSummary fallbackUser, {
    UserRole? role,
    bool? isActive,
  }) async {
    final list = await _store.readJsonList(_localUsersKey);
    final idx = list.indexWhere((u) =>
        (fallbackUser.uid.isNotEmpty && u['uid'] == fallbackUser.uid) ||
        (fallbackUser.email.isNotEmpty && u['email'] == fallbackUser.email));
    final base = idx != -1
        ? CampusUserSummary.fromMap(list[idx])
        : fallbackUser;
    final updated = base.copyWith(role: role, isActive: isActive);
    if (idx != -1) {
      list[idx] = updated.toMap();
    } else {
      list.add(updated.toMap());
    }
    await _store.saveJsonList(_localUsersKey, list);
    _localChanges.add(null);
  }

  Future<void> _upsertLocalUser(CampusUserSummary user) async {
    final list = await _store.readJsonList(_localUsersKey);
    final idx = list.indexWhere((u) => u['uid'] == user.uid);
    if (idx != -1) {
      list[idx] = user.toMap();
    } else {
      list.add(user.toMap());
    }
    await _store.saveJsonList(_localUsersKey, list);
    _localChanges.add(null);
  }

  Future<void> _appendLocalAudit({
    required String action,
    String? targetUser,
    required String summary,
  }) async {
    final list = await _store.readJsonList(_localAuditKey);
    final entry = AuditLogEntry(
      id: 'audit_${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      performedBy: _actorLabel(),
      summary: summary,
      targetUser: targetUser,
      timestamp: DateTime.now(),
    );
    list.insert(0, entry.toMap());
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    await _store.saveJsonList(_localAuditKey, list);
    _localChanges.add(null);
  }

  void dispose() {
    _localChanges.close();
  }
}
