/**
 * Seed / promote an existing user to Admin.
 *
 * Usage:
 *   node scripts/seed-admin.js <email>
 *
 * Prerequisites:
 *   1. The user must already be registered in Firebase Auth via the app.
 *   2. serviceAccountKey.json must exist in the PROJECT ROOT (never commit it).
 *   3. Build Functions first so the shared transition helper exists:
 *      npm --prefix functions run build
 *   4. Run from the repository root: node scripts/seed-admin.js admin@example.com
 *
 * Safety:
 *   - Safe to run multiple times on the same account (idempotent).
 *   - Reconciles system/role_control by counting ALL active admins after the
 *     profile update, so running this in a system that already has admins will
 *     not corrupt the counter.
 *   - Uses Firestore transactions for the counter update to avoid TOCTOU races.
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');
const {randomUUID} = require('crypto');
// Build Functions first so the seed uses the exact shared Claims/finalizer code.
const {applyRoleTransition} = require('../functions/lib/role_transitions');

const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');

let serviceAccount;
try {
  serviceAccount = require(serviceAccountPath);
} catch (_) {
  console.error('❌  serviceAccountKey.json not found at project root.');
  console.error('    Download it from Firebase Console → Project Settings → Service Accounts.');
  console.error('    Never commit it.');
  process.exit(1);
}

admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

const db   = admin.firestore();
const auth = admin.auth();

async function seedAdmin(email) {
  const user = await auth.getUserByEmail(email);
  const uid = user.uid;
  const userRef = db.collection('users').doc(uid);
  const controlRef = db.collection('system').doc('role_control');
  const operations = db.collection('system').doc('role_operations').collection('operations');

  // Reuse the pending operation after interruption; otherwise create a new
  // backend operation and transition identity.
  const observed = await userRef.get();
  const observedData = observed.data() || {};
  if (observedData.roleTransitionStatus === 'pending' &&
      (observedData.pendingRole !== 'admin' || observedData.pendingIsActive !== true)) {
    throw new Error('Target has a different pending role transition; finish it before seeding');
  }
  const operationId = observedData.roleTransitionStatus === 'pending' &&
    typeof observedData.operationId === 'string' ? observedData.operationId : randomUUID();
  const transitionId = observedData.roleTransitionStatus === 'pending' &&
    typeof observedData.transitionId === 'string' ? observedData.transitionId : randomUUID();
  const operationRef = operations.doc(operationId);

  await db.runTransaction(async (tx) => {
    const [controlSnap, profileSnap, adminsSnap, operationSnap] = await Promise.all([
      tx.get(controlRef),
      tx.get(userRef),
      tx.get(db.collection('users').where('role', '==', 'admin').where('isActive', '==', true)),
      tx.get(operationRef),
    ]);
    const actualCount = adminsSnap.size;
    const current = profileSnap.data() || {};
    const storedCount = controlSnap.data()?.activeAdminCount;
    if (controlSnap.exists && (!Number.isInteger(storedCount) || storedCount !== actualCount)) {
      throw new Error(`role_control mismatch (stored=${storedCount}, actual=${actualCount}); reconcile explicitly`);
    }
    if (operationSnap.exists) {
      const op = operationSnap.data();
      if (op.targetUid !== uid) throw new Error('Operation ID is bound to a different target UID');
      if (op.pendingRole !== 'admin' || op.pendingIsActive !== true) {
        throw new Error('Pending operation is not an active Admin seed transition');
      }
      if (op.status === 'completed') return;
      if (current.operationId !== operationId || current.transitionId !== op.transitionId ||
          current.pendingRoleVersion !== op.pendingRoleVersion ||
          current.pendingRole !== 'admin' || current.pendingIsActive !== true ||
          current.roleTransitionStatus !== 'pending') {
        throw new Error('Pending operation and profile do not match');
      }
      tx.update(operationRef, {attempts: admin.firestore.FieldValue.increment(1)});
      tx.update(userRef, {transitionAttemptCount: admin.firestore.FieldValue.increment(1)});
      return;
    }

    const legacyPendingSeed = current.roleTransitionStatus === 'pending' &&
      current.claimsOutOfSync === true && current.pendingRole === 'admin' &&
      current.pendingIsActive === true && current.operationId === undefined;
    if ((current.roleTransitionStatus === 'pending' || current.claimsOutOfSync === true ||
        current.provisioningStatus === 'claims_pending') && !legacyPendingSeed) {
      throw new Error('Target profile has an unfinished transition; recover it before seeding');
    }

    const oldRole = current.role || 'student';
    if (current.roleVersion !== undefined &&
        (!Number.isInteger(current.roleVersion) || current.roleVersion < 1)) {
      throw new Error('Target profile has an invalid roleVersion; reconcile it explicitly');
    }
    const oldActive = current.isActive === true;
    const delta = 1 - Number(oldRole === 'admin' && oldActive);
    const version = Number.isInteger(current.roleVersion) && current.roleVersion >= 1 ?
      current.roleVersion + (legacyPendingSeed ? 0 : 1) : 2;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const storedTransitionId = legacyPendingSeed && current.transitionId ?
      current.transitionId : transitionId;
    const pendingVersion = legacyPendingSeed && current.pendingRoleVersion ?
      current.pendingRoleVersion : version;

    tx.set(controlRef, {
      activeAdminCount: actualCount + delta,
      lastUpdatedMs: Date.now(),
      lastOperation: `seed_admin:${operationId}`,
    }, {merge: true});
    tx.set(userRef, {
      uid,
      email: user.email || email,
      displayName: user.displayName || email.split('@')[0],
      studentId: current.studentId ?? null,
      program: current.program ?? null,
      photoUrl: user.photoURL || current.photoUrl || null,
      role: 'admin',
      isActive: true,
      createdAt: current.createdAt || admin.firestore.Timestamp.fromDate(new Date(user.metadata.creationTime)),
      updatedAt: now,
      lastLoginAt: current.lastLoginAt || null,
      deactivatedAt: null,
      deactivatedBy: null,
      roleVersion: pendingVersion,
      operationId,
      transitionId: storedTransitionId,
      transitionStartedAt: now,
      transitionAttemptCount: 1,
      pendingRole: 'admin',
      pendingIsActive: true,
      pendingRoleVersion: pendingVersion,
      roleTransitionStatus: 'pending',
      provisioningStatus: 'pending',
      claimsOutOfSync: true,
    }, {merge: true});
    tx.create(operationRef, {
      targetUid: uid,
      transitionId: storedTransitionId,
      pendingRole: 'admin',
      pendingIsActive: true,
      pendingRoleVersion: pendingVersion,
      status: 'pending',
      attempts: 1,
      oldRole,
      oldActive,
      createdAt: now,
    });
  });

  await applyRoleTransition(db, auth, uid, operationId);
  const [profile, control] = await Promise.all([userRef.get(), controlRef.get()]);
  console.log(`Seeded ${email} as Admin; activeAdminCount=${control.data()?.activeAdminCount}; roleVersion=${profile.data()?.roleVersion}`);
}

const email = process.argv[2];
if (!email || !email.includes('@')) {
  console.error('Usage:   node scripts/seed-admin.js <admin-email>');
  console.error('Example: node scripts/seed-admin.js admin@university.ac.id');
  process.exit(1);
}

seedAdmin(email)
  .then(() => process.exit(0))
  .catch((err) => { console.error('Fatal:', err.message); process.exit(1); });
