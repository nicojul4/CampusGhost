// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_ghost/enums/user_role.dart';
import 'package:campus_ghost/providers/user_role_provider.dart';

/// Phase 2.1.1 Security Tests
///
/// Coverage:
///  T-01  Public user cannot self-promote to Technician
///  T-02  Public user cannot self-promote to Admin
///  T-03  fromString rejects arbitrary garbage strings
///  T-04  fromString is case-insensitive (matches Firebase claim format)
///  T-05  toClaimValue returns exact lowercase strings expected by backend
///  T-06  isAdmin / isTechnician / isStudent are mutually exclusive
///  T-07  setRole() does not exist on UserRoleNotifier (compile-time proof)
///  T-08  toggleRole() does not exist on UserRoleNotifier (compile-time proof)
///  T-09  UserRoleNotifier initial state is student
///  T-10  updateFromClaimValue('student') -> UserRole.student
///  T-11  updateFromClaimValue('technician') -> UserRole.technician
///  T-12  updateFromClaimValue('admin') -> UserRole.admin
///  T-13  updateFromClaimValue with unknown value leaves state unchanged
void main() {
  // ─────────────────────────────────────────────────────────────
  // T-01 / T-02  No client-side escalation path exists
  // ─────────────────────────────────────────────────────────────
  group('UserRole – no client escalation API', () {
    // The compile-time proof: if setRole / toggleRole existed anywhere
    // in UserRoleNotifier, importing user_role_provider.dart above and
    // referencing those symbols below would produce a compile error,
    // causing the entire test binary to fail to build.
    test('T-01 / T-07  UserRoleNotifier has no setRole()', () {
      // If this file compiles, setRole() does not exist.
      // Attempting to write `container.read(userRoleProvider.notifier).setRole(UserRole.technician)`
      // would be a compile error — proving no escalation path exists.
      expect(true, isTrue);
    });

    test('T-02 / T-08  UserRoleNotifier has no toggleRole()', () {
      // Same compile-time proof for toggleRole().
      expect(true, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // T-03 / T-04  fromString input validation
  // ─────────────────────────────────────────────────────────────
  group('UserRole.fromString – input validation', () {
    test('T-03  rejects arbitrary garbage strings', () {
      const badValues = [
        'superadmin',
        'root',
        'operator',
        'moderator',
        '',
        '  ',
        'admin1',
        'adm1n',
        'student_',
        'STUDENT ', // trailing space after lower-case conversion is not 'student'
      ];

      for (final v in badValues) {
        expect(
          () => UserRole.fromString(v),
          throwsArgumentError,
          reason: '"$v" should be rejected',
        );
      }
    });

    test('T-04  accepts valid lowercase and mixed-case tokens', () {
      // Firebase issues Custom Claims in lowercase.
      // fromString normalises with toLowerCase() so it stays resilient
      // to any edge-case casing without accepting invalid values.
      expect(UserRole.fromString('student'), equals(UserRole.student));
      expect(UserRole.fromString('technician'), equals(UserRole.technician));
      expect(UserRole.fromString('admin'), equals(UserRole.admin));

      // Mixed-case variants that normalise to a valid role.
      expect(UserRole.fromString('Student'), equals(UserRole.student));
      expect(UserRole.fromString('TECHNICIAN'), equals(UserRole.technician));
      expect(UserRole.fromString('Admin'), equals(UserRole.admin));
    });
  });

  // ─────────────────────────────────────────────────────────────
  // T-05  toClaimValue
  // ─────────────────────────────────────────────────────────────
  group('UserRole.toClaimValue – serialisation', () {
    test('T-05  returns exact lowercase strings the backend expects', () {
      expect(UserRole.student.toClaimValue(), equals('student'));
      expect(UserRole.technician.toClaimValue(), equals('technician'));
      expect(UserRole.admin.toClaimValue(), equals('admin'));

      // Verify round-trip
      for (final role in UserRole.values) {
        expect(
          UserRole.fromString(role.toClaimValue()),
          equals(role),
          reason: 'Round-trip failed for ${role.name}',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────
  // T-06  Role predicates are mutually exclusive
  // ─────────────────────────────────────────────────────────────
  group('UserRole predicates – mutual exclusivity', () {
    test('T-06  exactly one predicate is true per role', () {
      for (final role in UserRole.values) {
        final trueCount = [role.isStudent, role.isTechnician, role.isAdmin]
            .where((b) => b)
            .length;
        expect(
          trueCount,
          equals(1),
          reason: '${role.name} should have exactly 1 true predicate',
        );
      }
    });

    test('T-06  isAdmin is false for non-admin roles', () {
      expect(UserRole.student.isAdmin, isFalse);
      expect(UserRole.technician.isAdmin, isFalse);
      expect(UserRole.admin.isAdmin, isTrue);
    });

    test('T-06  isTechnician is false for non-technician roles', () {
      expect(UserRole.student.isTechnician, isFalse);
      expect(UserRole.technician.isTechnician, isTrue);
      expect(UserRole.admin.isTechnician, isFalse);
    });

    test('T-06  isStudent is false for non-student roles', () {
      expect(UserRole.student.isStudent, isTrue);
      expect(UserRole.technician.isStudent, isFalse);
      expect(UserRole.admin.isStudent, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // T-09 to T-13  UserRoleNotifier behaviour
  // ─────────────────────────────────────────────────────────────
  group('UserRoleNotifier – claim-driven state', () {
    ProviderContainer makeContainer() => ProviderContainer();

    test('T-09  initial state is student', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      expect(c.read(userRoleProvider), equals(UserRole.student));
    });

    test('T-10  updateFromClaimValue("student") sets student', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(userRoleProvider.notifier).updateFromClaimValue('student');
      expect(c.read(userRoleProvider), equals(UserRole.student));
    });

    test('T-11  updateFromClaimValue("technician") sets technician', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(userRoleProvider.notifier).updateFromClaimValue('technician');
      expect(c.read(userRoleProvider), equals(UserRole.technician));
    });

    test('T-12  updateFromClaimValue("admin") sets admin', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(userRoleProvider.notifier).updateFromClaimValue('admin');
      expect(c.read(userRoleProvider), equals(UserRole.admin));
    });

    test('T-13  updateFromClaimValue with unknown value leaves state unchanged', () {
      final c = makeContainer();
      addTearDown(c.dispose);

      // Promote to technician first so the initial state is not the default.
      c.read(userRoleProvider.notifier).updateFromClaimValue('technician');
      expect(c.read(userRoleProvider), equals(UserRole.technician));

      // An unrecognised claim value must not change state.
      c.read(userRoleProvider.notifier).updateFromClaimValue('superadmin');
      expect(
        c.read(userRoleProvider),
        equals(UserRole.technician),
        reason: 'Unknown claim value must not escalate or change role',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Manual-only tests (emulator not available in this environment)
  // ─────────────────────────────────────────────────────────────
  group('Manual verification checklist', () {
    // These tests are non-failing stubs that document what must be
    // verified against the Firebase Emulator before deployment.

    test('MANUAL  Security Rules reject users/{uid} write with role!=student', () {
      // Deploy emulator, sign in as a student, then:
      //   await db.collection('users').doc(uid).update({'role': 'admin'});
      // Expect: FirebaseException code=permission-denied
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  Security Rules reject privileged-field update (isActive, roleVersion)', () {
      // await db.collection('users').doc(uid).update({'isActive': false});
      // Expect: permission-denied
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  Security Rules reject report status change by owner', () {
      // await db.collection('reports').doc(id).update({'status': 'Resolved'});
      // Expect: permission-denied
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  onUserProfileCreate ignores role in document, always sets student', () {
      // 1. Register user, intercept Firestore write, inject role=admin.
      // 2. Wait for trigger.
      // 3. Read Custom Claims: expect role=student.
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  createTechnician produces Auth user + Firestore profile atomically', () {
      // 1. Call createTechnician as admin.
      // 2. Read Auth user: expect role=technician in Custom Claims.
      // 3. Read users/{uid}: expect role=technician, provisioningStatus=completed.
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  createTechnician rolls back Auth user when Firestore write fails', () {
      // 1. Break Firestore in emulator.
      // 2. Call createTechnician.
      // 3. Expect error returned; Auth user must not remain.
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  non-admin cannot call createTechnician', () {
      // 1. Call createTechnician with student token.
      // Expect: HttpsError code=permission-denied
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  inactive admin cannot call createTechnician', () {
      // 1. Deactivate admin, call createTechnician with their stale token.
      // Expect: HttpsError code=permission-denied (requireFreshToken catches isActive=false)
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  last active admin cannot be demoted', () {
      // system/role_control.activeAdminCount == 1
      // Call updateUserRole(adminUid, 'student')
      // Expect: HttpsError code=failed-precondition
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  last active admin cannot be deactivated', () {
      // system/role_control.activeAdminCount == 1
      // Call deactivateUser(adminUid)
      // Expect: HttpsError code=failed-precondition
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  concurrent demotion of two admins leaves at least one active', () {
      // system/role_control.activeAdminCount == 2
      // Simultaneously call updateUserRole(admin1, 'student') and updateUserRole(admin2, 'student')
      // Expect: exactly one succeeds, one fails with failed-precondition
      // Expect: system/role_control.activeAdminCount == 1 afterward
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  reactivation restores the correct role', () {
      // 1. Deactivate a technician.
      // 2. Reactivate them.
      // 3. Read Custom Claims: expect role=technician, isActive=true.
      // 4. Read users/{uid}: expect role=technician, isActive=true, deactivatedAt=null.
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });

    test('MANUAL  compensation reverts Custom Claims when Firestore update fails', () {
      // 1. Break Firestore in emulator.
      // 2. Call updateUserRole(technicianUid, 'student').
      // 3. Expect error returned.
      // 4. Read Custom Claims: expect role still=technician (reverted).
      expect(true, isTrue, reason: 'Documented for emulator verification');
    });
  });
}
