import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_ghost/enums/report_status.dart';
import 'package:campus_ghost/enums/user_role.dart';
import 'package:campus_ghost/models/admin_models.dart';
import 'package:campus_ghost/repositories/report_repository.dart';
import 'package:campus_ghost/services/admin_service.dart';
import 'package:campus_ghost/services/local_campus_store.dart';

class _MemoryStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

class _FakeAdminUser extends Fake implements User {
  @override
  String get uid => 'admin_001';

  @override
  String? get displayName => 'Admin Kampus';

  @override
  String? get email => 'admin@pradita.ac.id';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this._user);
  final User? _user;

  @override
  User? get currentUser => _user;
}

void main() {
  group('Administrator Workflow Tests', () {
    late LocalCampusStore store;
    late ReportRepository reportRepo;
    late AdminService adminService;

    setUp(() {
      store = LocalCampusStore(_MemoryStorage(), enableTimer: false);
      final auth = _FakeAuth(_FakeAdminUser());
      reportRepo = ReportRepository(store, auth);
      adminService = AdminService(
        store: store,
        auth: auth,
        reportRepository: reportRepo,
      );
    });

    tearDown(() {
      adminService.dispose();
      store.dispose();
    });

    test('createTechnician, updateUserRole, and setUserActive record audit logs',
        () async {
      await adminService.createTechnician(
        displayName: 'Pak Budi GA',
        email: 'budi.ga@pradita.ac.id',
        password: 'Password123',
      );

      final users = await adminService.watchUsers().first;
      final tech = users.firstWhere((u) => u.email == 'budi.ga@pradita.ac.id');
      expect(tech.role, equals(UserRole.technician));
      expect(tech.isActive, isTrue);

      await adminService.updateUserRole(
        targetUser: tech,
        newRole: UserRole.admin,
      );
      await adminService.setUserActive(targetUser: tech, activate: false);

      final updatedUsers = await adminService.watchUsers().first;
      final updatedTech =
          updatedUsers.firstWhere((u) => u.email == 'budi.ga@pradita.ac.id');
      expect(updatedTech.role, equals(UserRole.admin));
      expect(updatedTech.isActive, isFalse);

      final logs = await adminService.watchAuditLogs().first;
      expect(logs.length, greaterThanOrEqualTo(3));
      expect(logs.any((l) => l.action == 'create_technician'), isTrue);
      expect(logs.any((l) => l.action == 'update_role'), isTrue);
      expect(logs.any((l) => l.action == 'deactivate_user'), isTrue);
    });

    test('assignTicket assigns technician and moves Active ticket to In Progress',
        () async {
      final result = await reportRepo.submitReport(
        locationId: 'Gedung 1 Lantai 2',
        category: 'Wifi',
        description: 'Access point ruang 204 mati total sejak pagi.',
      );

      final reports = await reportRepo.watchAllReports().first;
      final report = reports.firstWhere((r) => r.id == result.reportId);
      expect(report.status, equals(ReportStatus.active));

      await adminService.assignTicket(
        report: report,
        technicianName: 'Pak Budi GA',
      );

      final afterAssign = await reportRepo.watchAllReports().first;
      final updated = afterAssign.firstWhere((r) => r.id == result.reportId);
      expect(updated.assignedTo, equals('Pak Budi GA'));
      expect(updated.status, equals(ReportStatus.inProgress));

      final logs = await adminService.watchAuditLogs().first;
      expect(logs.any((l) => l.action == 'assign_ticket'), isTrue);
    });

    test('CampusUserSummary & AuditLogEntry parse data gracefully', () {
      final user = CampusUserSummary.fromMap({
        'uid': 'u1',
        'email': 'nico@student.pradita.ac.id',
        'displayName': 'Nico',
        'role': 'technician',
        'isActive': true,
      });
      expect(user.role, equals(UserRole.technician));
      expect(user.isActive, isTrue);

      final audit = AuditLogEntry.fromMap({
        'action': 'update_role',
        'performedBy': 'admin_001',
        'targetUser': 'u1',
        'oldRole': 'student',
        'newRole': 'technician',
      }, id: 'log_1');
      expect(audit.summary, contains('student → technician'));
    });
  });
}
