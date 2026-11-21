import {expect} from 'chai';
import * as admin from 'firebase-admin';
import {randomUUID} from 'crypto';
import type {Auth} from 'firebase-admin/auth';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {setRoleClaims, isLegacyVersionCompatible} from '../src/custom_claims';
import {beginRoleTransition, applyRoleTransition, isLegacyProfileReady} from '../src/role_transitions';
import {requireFreshToken} from '../src/security_helpers';

describe('transition foundation: unit behavior', () => {
  it('preserves unrelated custom claims while changing role claims', async () => {
    let written: Record<string, unknown> | undefined;
    const auth = {
      getUser: async () => ({customClaims: {tenant: 'campus-a', feature: true, role: 'student'}}),
      setCustomUserClaims: async (_uid: string, claims: Record<string, unknown>) => { written = claims; },
    } as unknown as Auth;

    await setRoleClaims(auth, 'unit-user', {role: 'technician', isActive: true, roleVersion: 4});
    expect(written).to.include({tenant: 'campus-a', feature: true});
    expect(written).to.include({role: 'technician', isActive: true, roleVersion: 4});
  });

  it('accepts a missing token roleVersion only for legacy version 1', () => {
    expect(isLegacyVersionCompatible(1, undefined)).to.equal(true);
    expect(isLegacyVersionCompatible(2, undefined)).to.equal(false);
    expect(isLegacyVersionCompatible(1, 2)).to.equal(false);
  });

  it('recognizes only unmarked version-1 profiles as legacy-ready', () => {
    expect(isLegacyProfileReady({role: 'student', isActive: true})).to.equal(true);
    expect(isLegacyProfileReady({role: 'student', isActive: true, roleVersion: 2})).to.equal(false);
    expect(isLegacyProfileReady({role: 'student', isActive: true, claimsOutOfSync: true})).to.equal(false);
  });
});

const HAS_EMULATORS = Boolean(process.env.FIRESTORE_EMULATOR_HOST &&
  process.env.FIREBASE_AUTH_EMULATOR_HOST);
const integration = HAS_EMULATORS ? describe : describe.skip;

integration('transition foundation: Auth + Firestore emulator', function () {
  const projectId = 'demo-campusghost-b1';
  let db: FirebaseFirestore.Firestore;
  let auth: Auth;
  const uidList: string[] = [];
  const profileRefs: FirebaseFirestore.DocumentReference[] = [];
  const operationRefs: FirebaseFirestore.DocumentReference[] = [];
  let adminUid: string;
  let studentUid: string;
  let otherStudentUid: string;

  before(async () => {
    if (!admin.apps.length) admin.initializeApp({projectId});
    db = admin.firestore();
    auth = admin.auth();
    const host = process.env.FIRESTORE_EMULATOR_HOST!;
    db.settings({host, ssl: false});
  });

  beforeEach(async () => {
    adminUid = randomUUID();
    studentUid = randomUUID();
    otherStudentUid = randomUUID();
    uidList.push(adminUid, studentUid, otherStudentUid);
    await Promise.all(uidList.slice(-3).map((uid) => auth.createUser({uid})));
    const users = db.collection('users');
    const control = db.collection('system').doc('role_control');
    profileRefs.push(users.doc(adminUid), users.doc(studentUid), users.doc(otherStudentUid));
    await Promise.all([
      users.doc(adminUid).set({uid: adminUid, role: 'admin', isActive: true, roleVersion: 1,
        provisioningStatus: 'completed', roleTransitionStatus: 'completed', claimsOutOfSync: false}),
      users.doc(studentUid).set({uid: studentUid, role: 'student', isActive: true, roleVersion: 1,
        provisioningStatus: 'completed', roleTransitionStatus: 'completed', claimsOutOfSync: false}),
      users.doc(otherStudentUid).set({uid: otherStudentUid, role: 'student', isActive: true, roleVersion: 1,
        provisioningStatus: 'completed', roleTransitionStatus: 'completed', claimsOutOfSync: false}),
      control.set({activeAdminCount: 1, lastUpdatedMs: Date.now(), lastOperation: 'test'}),
    ]);
  });

  afterEach(async () => {
    await Promise.all([...profileRefs.splice(0).map((ref) => ref.delete()),
      ...operationRefs.splice(0).map((ref) => ref.delete())]);
    await db.collection('system').doc('role_control').delete();
    await Promise.all(uidList.splice(0).map((uid) => auth.deleteUser(uid).catch(() => undefined)));
  });

  function operationRef(id: string): FirebaseFirestore.DocumentReference {
    const ref = db.collection('system').doc('role_operations').collection('operations').doc(id);
    operationRefs.push(ref);
    return ref;
  }

  async function promote(uid: string, operationId: string) {
    return beginRoleTransition(db, adminUid, uid, operationId, 'test_promotion', 'admin', null);
  }

  it('retries one operation without incrementing counter or roleVersion twice', async () => {
    const operationId = randomUUID();
    operationRef(operationId);
    const first = await promote(studentUid, operationId);
    const retry = await promote(studentUid, operationId);
    expect(retry.transitionId).to.equal(first.transitionId);
    expect(retry.pendingRoleVersion).to.equal(first.pendingRoleVersion);
    expect((await db.collection('system').doc('role_control').get()).data()?.activeAdminCount).to.equal(2);
    expect((await db.collection('users').doc(studentUid).get()).data()?.roleVersion).to.equal(2);
    await applyRoleTransition(db, auth, studentUid, operationId);
    const repeated = await applyRoleTransition(db, auth, studentUid, operationId);
    expect(repeated.alreadyCompleted).to.equal(true);
  });

  it('does not allow an operation ID to be reused for another UID', async () => {
    const operationId = randomUUID();
    operationRef(operationId);
    await promote(studentUid, operationId);
    let rejected = false;
    try { await promote(otherStudentUid, operationId); } catch (_) { rejected = true; }
    expect(rejected).to.equal(true);
  });

  it('rejects a new operation while the target has another pending transition', async () => {
    const firstId = randomUUID();
    const secondId = randomUUID();
    operationRef(firstId);
    operationRef(secondId);
    await promote(studentUid, firstId);
    let rejected = false;
    try { await promote(studentUid, secondId); } catch (_) { rejected = true; }
    expect(rejected).to.equal(true);
  });

  it('rejects a stale transition ID and keeps the account pending', async () => {
    const operationId = randomUUID();
    operationRef(operationId);
    await promote(studentUid, operationId);
    await db.collection('users').doc(studentUid).update({transitionId: randomUUID()});
    let rejected = false;
    try { await applyRoleTransition(db, auth, studentUid, operationId); } catch (_) { rejected = true; }
    expect(rejected).to.equal(true);
    expect((await db.collection('users').doc(studentUid).get()).data()?.roleTransitionStatus).to.equal('pending');
  });

  it('allows concurrent finalizers to complete only the same operation once', async () => {
    const operationId = randomUUID();
    operationRef(operationId);
    await promote(studentUid, operationId);
    await Promise.all([
      applyRoleTransition(db, auth, studentUid, operationId),
      applyRoleTransition(db, auth, studentUid, operationId),
    ]);
    const profile = (await db.collection('users').doc(studentUid).get()).data();
    const op = (await operationRef(operationId).get()).data();
    expect(profile?.roleTransitionStatus).to.equal('completed');
    expect(profile?.roleVersion).to.equal(2);
    expect(profile?.operationId).to.equal(operationId);
    expect(op?.status).to.equal('completed');
    expect((await db.collection('system').doc('role_control').get()).data()?.activeAdminCount).to.equal(2);
  });

  it('a completed old finalizer cannot apply to a later transition', async () => {
    const firstId = randomUUID();
    operationRef(firstId);
    await promote(studentUid, firstId);
    await applyRoleTransition(db, auth, studentUid, firstId);

    const secondId = randomUUID();
    operationRef(secondId);
    await beginRoleTransition(db, adminUid, studentUid, secondId, 'test_demotion', 'student', null);
    let rejected = false;
    try { await applyRoleTransition(db, auth, studentUid, firstId); } catch (_) { rejected = true; }
    expect(rejected).to.equal(true);
    await applyRoleTransition(db, auth, studentUid, secondId);
    const profile = (await db.collection('users').doc(studentUid).get()).data();
    expect(profile?.operationId).to.equal(secondId);
    expect(profile?.roleVersion).to.equal(3);
  });

  it('rejects privileged access on roleVersion mismatch', async () => {
    const user = await auth.createUser({uid: randomUUID()});
    uidList.push(user.uid);
    profileRefs.push(db.collection('users').doc(user.uid));
    await db.collection('users').doc(user.uid).set({role: 'student', isActive: true,
      roleVersion: 2, provisioningStatus: 'completed', roleTransitionStatus: 'completed', claimsOutOfSync: false});
    const request = {auth: {uid: user.uid, token: {
      auth_time: Math.floor(Date.now() / 1000), role: 'student', isActive: true, roleVersion: 1,
    }}} as unknown as CallableRequest;
    let rejected = false;
    try { await requireFreshToken(request); } catch (_) { rejected = true; }
    expect(rejected).to.equal(true);
  });

  it('allows a consistent legacy profile and token without roleVersion', async () => {
    const user = await auth.createUser({uid: randomUUID()});
    uidList.push(user.uid);
    profileRefs.push(db.collection('users').doc(user.uid));
    await db.collection('users').doc(user.uid).set({role: 'student', isActive: true});
    const request = {auth: {uid: user.uid, token: {
      auth_time: Math.floor(Date.now() / 1000), role: 'student', isActive: true,
    }}} as unknown as CallableRequest;
    await requireFreshToken(request);
  });
});
