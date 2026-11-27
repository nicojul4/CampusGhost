import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/report_status.dart';
import '../models/notification_model.dart';
import '../models/report_model.dart';
import 'auth_provider.dart';
import 'firebase_provider.dart';
import 'notification_provider.dart';
import 'report_provider.dart';

final technicianTicketsProvider = StreamProvider<List<ReportModel>>((ref) {
  ref.watch(activeUserIdProvider);
  return ref.watch(reportRepositoryProvider).watchAllReports();
});

final technicianActionProvider = Provider<TechnicianAction>((ref) {
  return TechnicianAction(ref);
});

class TechnicianAction {
  TechnicianAction(this._ref);
  final Ref _ref;

  String _currentTechnicianLabel() {
    try {
      final user = _ref.read(authStateProvider).asData?.value ??
          _ref.read(firebaseAuthProvider).currentUser;
      final name = user?.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
      final emailPrefix = user?.email?.split('@').first;
      if (emailPrefix != null && emailPrefix.isNotEmpty) return emailPrefix;
    } catch (_) {}
    return 'Teknisi GA';
  }

  Future<void> startWorking(ReportModel report) async {
    final repo = _ref.read(reportRepositoryProvider);
    final techName = _currentTechnicianLabel();
    await repo.updateTicketByTechnician(
      reportId: report.id,
      status: ReportStatus.inProgress,
      ownerUserId: report.userId,
      assignedTo: techName,
    );

    _ref.read(notificationsProvider.notifier).addNotification(
          title: '${report.category} di ${report.locationId} Sedang Diperbaiki',
          message:
              '$techName telah menerima tiket laporan Anda dan sedang melakukan perbaikan di lokasi.',
          category: report.category,
          type: CampusNotificationType.inProgress,
        );
  }

  Future<void> resolveTicket(
    ReportModel report, {
    String? technicianNote,
  }) async {
    final repo = _ref.read(reportRepositoryProvider);
    final techName = _currentTechnicianLabel();
    final trimmedNote = technicianNote?.trim();
    final effectiveNote = (trimmedNote != null && trimmedNote.isNotEmpty)
        ? trimmedNote
        : null;

    await repo.updateTicketByTechnician(
      reportId: report.id,
      status: ReportStatus.resolved,
      ownerUserId: report.userId,
      assignedTo: report.assignedTo ?? techName,
      technicianNote: effectiveNote,
      resolvedAt: DateTime.now().toUtc(),
    );

    final noteSuffix =
        effectiveNote != null ? ' Catatan: $effectiveNote' : '';
    _ref.read(notificationsProvider.notifier).addNotification(
          title: 'Perbaikan Selesai: ${report.category} di ${report.locationId}',
          message:
              'Fasilitas kampus telah selesai diperbaiki oleh $techName dan kembali normal.$noteSuffix',
          category: report.category,
          type: CampusNotificationType.resolved,
        );
  }

  Future<void> reopenTicket(ReportModel report) async {
    final repo = _ref.read(reportRepositoryProvider);
    await repo.updateTicketByTechnician(
      reportId: report.id,
      status: ReportStatus.active,
      ownerUserId: report.userId,
    );

    _ref.read(notificationsProvider.notifier).addNotification(
          title: 'Pemeriksaan Lanjutan: ${report.category} di ${report.locationId}',
          message:
              'Tiket kendala fasilitas telah dibuka kembali untuk pemeriksaan lanjutan oleh petugas.',
          category: report.category,
          type: CampusNotificationType.info,
        );
  }
}
