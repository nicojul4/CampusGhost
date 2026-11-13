import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_ghost/enums/incident_status.dart';
import 'package:campus_ghost/enums/report_status.dart';
import 'package:campus_ghost/enums/user_role.dart';
import 'package:campus_ghost/models/notification_model.dart';
import 'package:campus_ghost/models/report_model.dart';
import 'package:campus_ghost/providers/notification_provider.dart';
import 'package:campus_ghost/providers/report_provider.dart';
import 'package:campus_ghost/providers/technician_tickets_provider.dart';
import 'package:campus_ghost/providers/user_role_provider.dart';
import 'package:campus_ghost/repositories/report_repository.dart';

class FakeReportRepository extends Fake implements ReportRepository {
  ReportStatus? lastUpdatedStatus;
  String? lastUpdatedReportId;

  @override
  Future<void> updateReport({
    required String reportId,
    String? description,
    ReportStatus? status,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? locationDetail,
  }) async {
    lastUpdatedReportId = reportId;
    lastUpdatedStatus = status;
  }
}

void main() {
  group('Role-Based Panel & Technician Workflow Tests', () {
    test('UserRole defaults to student and toggles to technician', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(userRoleProvider), equals(UserRole.student));
      expect(container.read(userRoleProvider).isStudent, isTrue);
      expect(container.read(userRoleProvider).isTechnician, isFalse);

      container.read(userRoleProvider.notifier).toggleRole();
      expect(container.read(userRoleProvider), equals(UserRole.technician));
      expect(container.read(userRoleProvider).isTechnician, isTrue);

      container.read(userRoleProvider.notifier).setRole(UserRole.student);
      expect(container.read(userRoleProvider), equals(UserRole.student));
    });

    test('ReportStatus & IncidentStatus parse inProgress and labels correctly', () {
      expect(ReportStatus.fromValue('In Progress'), equals(ReportStatus.inProgress));
      expect(ReportStatus.fromValue('Sedang Dikerjakan'), equals(ReportStatus.inProgress));
      expect(ReportStatus.fromValue('Resolved'), equals(ReportStatus.resolved));
      expect(ReportStatus.fromValue('Active'), equals(ReportStatus.active));

      expect(ReportStatus.inProgress.labelIndonesian, equals('Sedang Dikerjakan'));
      expect(ReportStatus.resolved.labelIndonesian, equals('Selesai'));
      expect(ReportStatus.active.labelIndonesian, equals('Menunggu'));

      expect(IncidentStatus.fromValue('In Progress'), equals(IncidentStatus.inProgress));
      expect(IncidentStatus.fromValue('Sedang Dikerjakan'), equals(IncidentStatus.inProgress));
    });

    test('TechnicianAction updates report status and dispatches live notification', () async {
      final fakeRepo = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(fakeRepo),
      ]);
      addTearDown(container.dispose);

      final notifsBefore = container.read(notificationsProvider).length;

      final report = ReportModel(
        id: 'test_rep_101',
        incidentId: 'inc_101',
        userId: 'user_student',
        locationId: 'Gedung 2 - Ruang 202',
        category: 'Ac',
        description: 'AC bocor dan menetes ke meja kuliah',
        status: ReportStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final technicianAction = container.read(technicianActionProvider);

      // 1. Teknisi klik "Mulai Kerjakan"
      await technicianAction.startWorking(report);

      expect(fakeRepo.lastUpdatedReportId, equals('test_rep_101'));
      expect(fakeRepo.lastUpdatedStatus, equals(ReportStatus.inProgress));

      final notifsAfterStart = container.read(notificationsProvider);
      expect(notifsAfterStart.length, equals(notifsBefore + 1));
      expect(notifsAfterStart.first.title, contains('Sedang Diperbaiki'));
      expect(notifsAfterStart.first.type, equals(CampusNotificationType.inProgress));

      // 2. Teknisi klik "Tandai Selesai"
      await technicianAction.resolveTicket(report);

      expect(fakeRepo.lastUpdatedStatus, equals(ReportStatus.resolved));

      final notifsAfterResolve = container.read(notificationsProvider);
      expect(notifsAfterResolve.length, equals(notifsBefore + 2));
      expect(notifsAfterResolve.first.title, contains('Perbaikan Selesai'));
      expect(notifsAfterResolve.first.type, equals(CampusNotificationType.resolved));
    });
  });
}
