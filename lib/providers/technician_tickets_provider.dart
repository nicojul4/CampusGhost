import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/report_status.dart';
import '../models/notification_model.dart';
import '../models/report_model.dart';
import 'notification_provider.dart';
import 'report_provider.dart';

final technicianTicketsProvider = StreamProvider<List<ReportModel>>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(reportRepositoryProvider).watchReportsForUser(userId);
});

final technicianActionProvider = Provider<TechnicianAction>((ref) {
  return TechnicianAction(ref);
});

class TechnicianAction {
  TechnicianAction(this._ref);
  final Ref _ref;

  Future<void> startWorking(ReportModel report) async {
    final repo = _ref.read(reportRepositoryProvider);
    await repo.updateReport(
      reportId: report.id,
      status: ReportStatus.inProgress,
    );

    _ref.read(notificationsProvider.notifier).addNotification(
          title: '${report.category} di ${report.locationId} Sedang Diperbaiki',
          message:
              'Petugas Teknisi GA/Sarpras telah menerima tiket laporan Anda dan sedang melakukan perbaikan di lokasi.',
          category: report.category,
          type: CampusNotificationType.inProgress,
        );
  }

  Future<void> resolveTicket(ReportModel report) async {
    final repo = _ref.read(reportRepositoryProvider);
    await repo.updateReport(
      reportId: report.id,
      status: ReportStatus.resolved,
    );

    _ref.read(notificationsProvider.notifier).addNotification(
          title: 'Perbaikan Selesai: ${report.category} di ${report.locationId}',
          message:
              'Fasilitas kampus telah berhasil diperbaiki oleh tim Teknisi GA dan kini berfungsi normal. Terima kasih atas laporannya!',
          category: report.category,
          type: CampusNotificationType.resolved,
        );
  }

  Future<void> reopenTicket(ReportModel report) async {
    final repo = _ref.read(reportRepositoryProvider);
    await repo.updateReport(
      reportId: report.id,
      status: ReportStatus.active,
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
