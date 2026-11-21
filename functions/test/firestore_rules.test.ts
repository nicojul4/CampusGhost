/**
 * Firestore Security Rules tests using @firebase/rules-unit-testing
 *
 * These tests run against the Firestore emulator.
 * They are skipped automatically when the emulator is not reachable.
 *
 * To run:
 *   firebase emulators:start --only firestore &
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 npm --prefix functions test
 *
 * Or all at once:
 *   firebase emulators:exec --only firestore \
 *     "FIRESTORE_EMULATOR_HOST=localhost:8080 npm --prefix functions test"
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import type {RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {readFileSync}  from 'fs';
import {resolve}       from 'path';
import {expect}        from 'chai';

const EMULATOR_HOST = process.env['FIRESTORE_EMULATOR_HOST'];
const SKIP = !EMULATOR_HOST;

const PROJECT_ID   = 'campus-ghost-rules-test';
const FUNCTIONS_DIR = process.cwd().endsWith('/functions') ? process.cwd() : resolve(process.cwd(), 'functions');
const RULES_PATH   = resolve(FUNCTIONS_DIR, '../firestore.rules');

let env: RulesTestEnvironment;

// ── Setup / teardown ───────────────────���────────────────────────────────────

before(async function () {
  if (SKIP) return;

  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules:    readFileSync(RULES_PATH, 'utf8'),
      host:     'localhost',
      port:     8080,
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async function () {
  if (env) await env.clearFirestore();
});

// ── helpers ─────────────────────────────────────────────────────────────────

function authed(uid: string) {
  return env.authenticatedContext(uid).firestore();
}
function unauthed() {
  return env.unauthenticatedContext().firestore();
}
/** Write via admin (bypasses rules) */
async function adminSet(collection: string, docId: string, data: object) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection(collection).doc(docId).set(data);
  });
}

// ── users/{userId} ──────────────────────────────────────────────────────────

(SKIP ? describe.skip : describe)('Security Rules: users collection', () => {

  const UID = 'user-abc';

  it('owner can read own profile', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertSucceeds(
      authed(UID).collection('users').doc(UID).get(),
    );
  });

  it('non-owner cannot read another profile', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertFails(
      authed('other-user').collection('users').doc(UID).get(),
    );
  });

  it('allows create with role=student and isActive=true', async () => {
    await assertSucceeds(
      authed(UID).collection('users').doc(UID).set({
        uid:         UID,
        email:       'test@example.com',
        displayName: 'Test User',
        studentId:   null,
        program:     null,
        photoUrl:    null,
        role:        'student',
        isActive:    true,
        createdAt:   new Date(),
        updatedAt:   new Date(),
        lastLoginAt: null,
      }),
    );
  });

  it('rejects create with role=admin', async () => {
    await assertFails(
      authed(UID).collection('users').doc(UID).set({
        uid:      UID,
        role:     'admin',   // ← privilege escalation attempt
        isActive: true,
      }),
    );
  });

  it('rejects create with role=technician', async () => {
    await assertFails(
      authed(UID).collection('users').doc(UID).set({
        uid:      UID,
        role:     'technician',
        isActive: true,
      }),
    );
  });

  it('rejects create with isActive=false', async () => {
    await assertFails(
      authed(UID).collection('users').doc(UID).set({
        uid:      UID,
        role:     'student',
        isActive: false,  // ← not allowed at create
      }),
    );
  });

  it('rejects create with privileged field roleVersion', async () => {
    await assertFails(
      authed(UID).collection('users').doc(UID).set({
        uid:         UID,
        role:        'student',
        isActive:    true,
        roleVersion: 1,  // ← privileged field
      }),
    );
  });

  it('rejects create with privileged field provisioningStatus', async () => {
    await assertFails(
      authed(UID).collection('users').doc(UID).set({
        uid:                UID,
        role:               'student',
        isActive:           true,
        provisioningStatus: 'completed',  // ← privileged field
      }),
    );
  });

  it('rejects create with backend transition identifiers', async () => {
    await assertFails(authed(UID).collection('users').doc(UID).set({
      uid: UID, role: 'student', isActive: true,
      operationId: 'client-controlled-operation',
      transitionId: 'client-controlled-transition',
      roleVersion: 1,
    }));
  });

  it('allows owner to update non-privileged fields', async () => {
    await adminSet('users', UID, {
      uid: UID, role: 'student', isActive: true,
      displayName: 'Old Name',
    });
    await assertSucceeds(
      authed(UID).collection('users').doc(UID).update({
        displayName: 'New Name',
      }),
    );
  });

  it('rejects owner update that changes role', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertFails(
      authed(UID).collection('users').doc(UID).update({role: 'admin'}),
    );
  });

  it('rejects owner update that changes isActive', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertFails(
      authed(UID).collection('users').doc(UID).update({isActive: false}),
    );
  });

  it('rejects owner update that sets claimsOutOfSync', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertFails(
      authed(UID).collection('users').doc(UID).update({claimsOutOfSync: true}),
    );
  });

  it('rejects owner update to pending transition state', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertFails(authed(UID).collection('users').doc(UID).update({
      roleTransitionStatus: 'pending',
      pendingRole: 'admin',
      pendingIsActive: true,
      pendingRoleVersion: 2,
      transitionAttemptCount: 1,
    }));
  });

  it('delete is always denied', async () => {
    await adminSet('users', UID, {uid: UID, role: 'student', isActive: true});
    await assertFails(
      authed(UID).collection('users').doc(UID).delete(),
    );
  });
});

// ── reports/{reportId} ──────────────────────────────────────────────────────

(SKIP ? describe.skip : describe)('Security Rules: reports collection', () => {

  const UID     = 'reporter-xyz';
  const OTHER   = 'other-user';
  const REPORT  = 'report-001';

  const validReport = {
    userId:      UID,
    UserId:      UID,
    locationId:  'bldg-1',
    LocationId:  'bldg-1',
    category:    'Wifi',
    Category:    'Wifi',
    description: 'Network is down on floor 3',
    Description: 'Network is down on floor 3',
    status:      'Active',
    Status:      'Active',
    createdAt:   new Date().toISOString(),
    CreatedAt:   new Date().toISOString(),
    updatedAt:   new Date().toISOString(),
    UpdatedAt:   new Date().toISOString(),
  };

  it('owner can create a valid report', async () => {
    await assertSucceeds(
      authed(UID).collection('reports').doc(REPORT).set(validReport),
    );
  });

  it('rejects report create with no userId and no UserId', async () => {
    const {userId: _u, UserId: _U, ...noOwner} = validReport;
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).set(noOwner),
    );
  });

  it('rejects create where userId != auth.uid', async () => {
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).set({
        ...validReport,
        userId: OTHER,
        UserId: OTHER,
      }),
    );
  });

  it('rejects create with incidentId present', async () => {
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).set({
        ...validReport,
        incidentId: 'inc-123',  // ← workflow field
      }),
    );
  });

  it('rejects create with assignedTo present', async () => {
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).set({
        ...validReport,
        assignedTo: 'tech-456',
      }),
    );
  });

  it('rejects create with status=Resolved', async () => {
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).set({
        ...validReport,
        status: 'Resolved',
        Status: 'Resolved',
      }),
    );
  });

  it('rejects create with description shorter than 10 chars', async () => {
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).set({
        ...validReport,
        description: 'Short',
        Description: 'Short',
      }),
    );
  });

  it('owner can read own report', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertSucceeds(
      authed(UID).collection('reports').doc(REPORT).get(),
    );
  });

  it('non-owner cannot read report', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertFails(
      authed(OTHER).collection('reports').doc(REPORT).get(),
    );
  });

  it('owner can update description', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertSucceeds(
      authed(UID).collection('reports').doc(REPORT).update({
        description: 'Updated description with enough length',
      }),
    );
  });

  it('owner cannot change status directly', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).update({
        status: 'Resolved',
      }),
    );
  });

  it('owner cannot change Status (PascalCase) directly', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).update({
        Status: 'In Progress',
      }),
    );
  });

  it('owner cannot change userId', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).update({userId: OTHER}),
    );
  });

  it('owner cannot set incidentId', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertFails(
      authed(UID).collection('reports').doc(REPORT).update({
        incidentId: 'inc-999',
      }),
    );
  });

  it('unauthenticated user cannot read reports', async () => {
    await adminSet('reports', REPORT, {...validReport, userId: UID, UserId: UID});
    await assertFails(
      unauthed().collection('reports').doc(REPORT).get(),
    );
  });
});

// ── system/{document} ───────────────────────────────────────────────────────

(SKIP ? describe.skip : describe)('Security Rules: system collection', () => {
  it('no authenticated user can read system/role_control', async () => {
    await adminSet('system', 'role_control', {activeAdminCount: 1});
    await assertFails(
      authed('any-user').collection('system').doc('role_control').get(),
    );
  });

  it('no authenticated user can write system/role_control', async () => {
    await assertFails(
      authed('any-user').collection('system').doc('role_control').set({
        activeAdminCount: 99,
      }),
    );
  });

  it('no client can read or write role operation ledger documents', async () => {
    const ref = authed('any-user').collection('system').doc('role_operations')
      .collection('operations').doc('operation-identifier-1234');
    await assertFails(ref.get());
    await assertFails(ref.set({targetUid: 'any-user'}));
  });
});

// ── audit_logs ───────────────────────────────────────────────────────────────

(SKIP ? describe.skip : describe)('Security Rules: audit_logs collection', () => {
  it('no client can read audit_logs', async () => {
    await adminSet('audit_logs', 'log-1', {action: 'test'});
    await assertFails(
      authed('any-user').collection('audit_logs').doc('log-1').get(),
    );
  });

  it('no client can write audit_logs', async () => {
    await assertFails(
      authed('any-user').collection('audit_logs').add({action: 'inject'}),
    );
  });
});
