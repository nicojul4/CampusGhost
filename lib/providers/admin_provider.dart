import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'auth_provider.dart';
import 'firebase_provider.dart';
import 'report_provider.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  final service = AdminService(
    store: ref.watch(localCampusStoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    reportRepository: ref.watch(reportRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final adminUsersProvider = StreamProvider<List<CampusUserSummary>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(adminServiceProvider).watchUsers();
});

final adminAuditLogsProvider = StreamProvider<List<AuditLogEntry>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(adminServiceProvider).watchAuditLogs();
});
