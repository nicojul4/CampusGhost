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
import 'package:campus_ghost/repositories/report_repository.dart';

class FakeReportRepository extends Fake implements ReportRepository {
  ReportStatus? lastUpdatedStatus;
  String? lastUpdatedReportId;
  String? lastAssignedTo;
  String? lastTechnicianNote;

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

  @override
  Future<void> updateTicketByTechnician({
    required String reportId,
    required ReportStatus status,
    String? ownerUserId,
    String? assignedTo,
    String? technicianNote,
    DateTime? resolvedAt,
  }) async {
    lastUpdatedReportId = reportId;
    lastUpdatedStatus = status;
    lastAssignedTo = assignedTo;
    lastTechnicianNote = technicianNote;
  }
}

void main() {
  group('Role-Based Panel & Technician Workflow Tests', () {
    test('UserRole enum has correct properties', () {
      expect(UserRole.student.isStudent, isTrue);
      expect(UserRole.student.isTechnician, isFalse);
      expect(UserRole.student.isAdmin, isFalse);
      
      expect(UserRole.technician.isStudent, isFalse);
      expect(UserRole.technician.isTechnician, isTrue);
      expect(UserRole.technician.isAdmin, isFalse);
      
      expect(UserRole.admin.isStudent, isFalse);
      expect(UserRole.admin.isTechnician, isFalse);
      expect(UserRole.admin.isAdmin, isTrue);
      
      // Test fromString parsing
      expect(UserRole.fromString('student'), equals(UserRole.student));
      expect(UserRole.fromString('technician'), equals(UserRole.technician));
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      
      // Test that invalid role throws
      expect(() => UserRole.fromString('invalid'), throwsArgumentError);
      
      // Test toClaimValue
      expect(UserRole.student.toClaimValue(), equals('student'));
      expect(UserRole.technician.toClaimValue(), equals('technician'));
      expect(UserRole.admin.toClaimValue(), equals('admin'));
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
      expect(fakeRepo.lastAssignedTo, isNotEmpty);

      final notifsAfterStart = container.read(notificationsProvider);
      expect(notifsAfterStart.length, equals(notifsBefore + 1));
      expect(notifsAfterStart.first.title, contains('Sedang Diperbaiki'));
      expect(notifsAfterStart.first.type, equals(CampusNotificationType.inProgress));

      // 2. Teknisi klik "Tandai Selesai" dengan catatan perbaikan
      await technicianAction.resolveTicket(
        report,
        technicianNote: 'Filter AC dibersihkan dan suhu sudah normal.',
      );

      expect(fakeRepo.lastUpdatedStatus, equals(ReportStatus.resolved));
      expect(
        fakeRepo.lastTechnicianNote,
        equals('Filter AC dibersihkan dan suhu sudah normal.'),
      );

      final notifsAfterResolve = container.read(notificationsProvider);
      expect(notifsAfterResolve.length, equals(notifsBefore + 2));
      expect(notifsAfterResolve.first.title, contains('Perbaikan Selesai'));
      expect(notifsAfterResolve.first.message, contains('Filter AC dibersihkan'));
      expect(notifsAfterResolve.first.type, equals(CampusNotificationType.resolved));
    });
  });
}
