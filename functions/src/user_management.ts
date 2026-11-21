/**
 * User management Cloud Functions
 * Admin-only operations for creating and managing users
 *
 * SAGA DESIGN:
 * Firebase Auth Custom Claims and Firestore cannot be updated atomically.
 * Every operation that touches both follows this explicit ordering:
 *
 *   1. Validate caller freshness and Admin role.
 *   2. Commit an operation record, pending profile intent, and Admin counter
 *      delta in one transaction. Reusing operationId resumes the same intent.
 *   3. Write role claims through the shared helper, preserving unrelated keys.
 *   4. Finalize profile and operation records with transitionId/version CAS.
 *   5. Revoke refresh tokens as appropriate.
 *
 * AUTHORIZATION DURING PARTIAL COMPLETION:
 *   While pending, requireFreshToken rejects the account regardless of token
 *   Claims. This phase provides callable retry; scheduled recovery is deferred.
 */

import {onCall, HttpsError} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {randomUUID} from 'crypto';
import * as logger from 'firebase-functions/logger';
import {
  requireAdmin,
  requireFreshToken,
  validateEmail,
  validateDisplayName,
  validatePassword,
  validateRole,
} from './security_helpers';
import {UserProfile, UserRole} from './types';
import {applyRoleTransition, beginRoleTransition, validateOperationId} from './role_transitions';
import {setRoleClaims} from './custom_claims';

// ─────────────────────────────────────────────────────────────────────────────
// Role-control helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Mark a technician provisioning saga for operator/retry reconciliation. */
async function markClaimsOutOfSync(
  db: FirebaseFirestore.Firestore,
  uid: string,
  intendedRole: string,
  intendedActive: boolean,
): Promise<void> {
  try {
    await db.collection('users').doc(uid).update({
      claimsOutOfSync: true,
      intendedRole,
      intendedActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error(`Could not mark claims out of sync for ${uid}`, error);
  }
}

/**
 * Run a Firestore transaction that:
 *   - Reads system/role_control and users/{targetUid}
 *   - Rejects the operation if it would remove the last active admin
 *   - Atomically updates the counter AND the user profile
 *
 * @param targetUid   the user being changed
 * @param operation   human-readable label for logs / audit
 * @param profileUpdates  fields to merge into users/{targetUid}
 * @param counterDelta  +1, -1, or 0 — change to activeAdminCount
 * @param db
 */
async function runAdminCounterTransaction(
  actorUid: string,
  targetUid: string,
  operationId: string,
  operation: string,
  newRole: UserRole | null,
  newActive: boolean | null,
  profileUpdates: Record<string, unknown>,
  db: FirebaseFirestore.Firestore,
): ReturnType<typeof beginRoleTransition> {
  return beginRoleTransition(
    db, actorUid, targetUid, operationId, operation,
    newRole, newActive, profileUpdates,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// createTechnician
// ─────────────────────────────────────────────────────────────────────────────

export const createTechnician = onCall(async (request) => {
  await requireFreshToken(request);
  requireAdmin(request);

  const {email, displayName, password} = request.data;
  validateEmail(email);
  validateDisplayName(displayName);
  validatePassword(password);

  const db   = admin.firestore();
  const auth = admin.auth();

  logger.info(`Admin ${request.auth!.uid} creating technician: ${email}`);

  // ── Step 1: Create Auth user ──────────────────────────────────────────────
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email:         email.trim(),
      displayName:   displayName.trim(),
      password,
      emailVerified: false,
    });
  } catch (err: any) {
    if (err.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'Email already in use');
    }
    logger.error('createTechnician: failed to create Auth user', err);
    throw new HttpsError('internal', `Failed to create user: ${err.message}`);
  }

  const uid = userRecord.uid;

  // ── Step 2: Create Firestore profile (before Claims) ─────────────────────
  // Profile is created first with provisioningStatus='claims_pending' so the
  // system always knows this user exists even if the Claims write fails.
  const profile: UserProfile = {
    uid,
    email:              email.trim(),
    displayName:        displayName.trim(),
    studentId:          null,
    program:            null,
    photoUrl:           null,
    role:               'technician',
    isActive:           true,
    createdAt:          admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
    updatedAt:          admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
    lastLoginAt:        null,
    deactivatedAt:      null,
    deactivatedBy:      null,
    roleVersion:        1,
    provisioningStatus: 'claims_pending',
  };

  try {
    await db.collection('users').doc(uid).set(profile);
  } catch (err: any) {
    // Firestore failed — roll back the Auth user.
    logger.error(`createTechnician: profile write failed for ${uid}, rolling back`, err);
    try {
      await auth.deleteUser(uid);
    } catch (delErr) {
      logger.error(`ORPHANED_AUTH_ACCOUNT uid=${uid} email=${email}`, delErr);
    }
    throw new HttpsError('internal', `Failed to create profile: ${err.message}`);
  }

  // ── Step 3: Set Custom Claims ─────────────────────────────────────────────
  try {
    await setRoleClaims(auth, uid, {role: 'technician', isActive: true, roleVersion: 1});
    // Mark provisioning complete
    await db.collection('users').doc(uid).update({
      provisioningStatus: 'completed',
      claimsOutOfSync:    false,
      updatedAt:          admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`createTechnician: provisioned ${uid} successfully`);
  } catch (err: any) {
    logger.error(`createTechnician: Claims write failed for ${uid}`, err);
    await markClaimsOutOfSync(db, uid, 'technician', true);
    // The profile exists; a reconciliation job can retry the Claims write.
    // We still throw so the caller knows provisioning is incomplete.
    throw new HttpsError(
      'internal',
      `Firestore profile created but Claims write failed. ` +
      `Account uid=${uid} requires manual reconciliation.`,
    );
  }

  // ── Step 4: Audit log (best-effort) ──────────────────────────────────────
  try {
    await db.collection('audit_logs').add({
      action:      'create_technician',
      performedBy: request.auth!.uid,
      targetUser:  uid,
      timestamp:   admin.firestore.FieldValue.serverTimestamp(),
      details:     {email: email.trim(), displayName: displayName.trim()},
    });
  } catch (e) {
    logger.error('createTechnician: audit log failed (non-fatal)', e);
  }

  return {success: true, uid, email: userRecord.email, displayName: userRecord.displayName};
});

// ─────────────────────────────────────────────────────────────────────────────
// updateUserRole
// ─────────────────────────────────────────────────────────────────────────────

export const updateUserRole = onCall(async (request) => {
  await requireFreshToken(request);
  requireAdmin(request);

  const {targetUid, newRole} = request.data;
  if (!targetUid || typeof targetUid !== 'string') {
    throw new HttpsError('invalid-argument', 'targetUid is required');
  }
  validateRole(newRole);
  const operationId = request.data.operationId || randomUUID();
  validateOperationId(operationId);

  // Self-demotion guard
  if (request.auth!.uid === targetUid && newRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Cannot demote yourself from admin');
  }

  const db   = admin.firestore();
  const auth = admin.auth();

  const transitioned = await runAdminCounterTransaction(
    request.auth!.uid, targetUid, operationId, 'update_role', newRole, null, {}, db,
  );
  if (transitioned.completed) return {success: true, alreadySet: true, operationId};
  const oldRole = transitioned.oldRole;

  try {
    await applyRoleTransition(db, auth, targetUid, operationId);
  } catch (err) {
    logger.error(`updateUserRole: transition completion failed for ${targetUid}`, err);
    throw new HttpsError('internal', `Role transition is pending recovery for uid=${targetUid}`, {operationId});
  }

  // ── Step 5: Revoke tokens ─────────────────────────────────────────────────
  try {
    await auth.revokeRefreshTokens(targetUid);
  } catch (e) {
    logger.error(`updateUserRole: token revocation failed for ${targetUid} (non-fatal)`, e);
  }

  // ── Step 6: Audit log ─────────────────────────────────────────────────────
  try {
    await db.collection('audit_logs').add({
      action:      'update_role',
      performedBy: request.auth!.uid,
      targetUser:  targetUid,
      oldRole,
      newRole,
      timestamp:   admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.error('updateUserRole: audit log failed (non-fatal)', e);
  }

  return {success: true, operationId};
});

/** Admin initiated, idempotent recovery for a saga interrupted after its
 * Firestore transaction committed. The profile remains inaccessible while
 * pending, and the transaction's counter change is never applied twice. */
export const reconcileRoleTransition = onCall(async (request) => {
  await requireFreshToken(request);
  requireAdmin(request);
  const {targetUid, operationId} = request.data;
  if (typeof targetUid !== 'string' || targetUid.length === 0) {
    throw new HttpsError('invalid-argument', 'targetUid is required');
  }
  validateOperationId(operationId);
  try {
    const result = await applyRoleTransition(admin.firestore(), admin.auth(), targetUid, operationId);
    await admin.auth().revokeRefreshTokens(targetUid);
    return {success: true, ...result};
  } catch (err) {
    logger.error(`reconcileRoleTransition failed for ${targetUid}`, err);
    throw new HttpsError('failed-precondition', 'Role transition remains pending; retry after resolving the underlying service error', {operationId});
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// deactivateUser
// ─────────────────────────────────────────────────────────────────────────────

export const deactivateUser = onCall(async (request) => {
  await requireFreshToken(request);
  requireAdmin(request);

  const {targetUid, reason} = request.data;
  if (!targetUid || typeof targetUid !== 'string') {
    throw new HttpsError('invalid-argument', 'targetUid is required');
  }
  const operationId = request.data.operationId || randomUUID();
  validateOperationId(operationId);
  if (request.auth!.uid === targetUid) {
    throw new HttpsError('permission-denied', 'Cannot deactivate yourself');
  }

  const db   = admin.firestore();
  const auth = admin.auth();

  logger.info(`Admin ${request.auth!.uid} deactivating ${targetUid}`);

  const transitioned = await runAdminCounterTransaction(
    request.auth!.uid, targetUid, operationId, 'deactivate', null, false,
    {deactivatedAt: admin.firestore.FieldValue.serverTimestamp(), deactivatedBy: request.auth!.uid}, db,
  );
  if (transitioned.completed) return {success: true, alreadyDeactivated: true, operationId};
  const currentRole = transitioned.oldRole;
  try {
    await applyRoleTransition(db, auth, targetUid, operationId);
  } catch (err) {
    logger.error(`deactivateUser: transition completion failed for ${targetUid}`, err);
    throw new HttpsError('internal', `Deactivation is pending recovery for uid=${targetUid}`, {operationId});
  }

  // ── Step 5: Audit log ─────────────────────────────────────────────────────
  try {
    await db.collection('audit_logs').add({
      action:        'deactivate_user',
      performedBy:   request.auth!.uid,
      targetUser:    targetUid,
      reason:        reason || null,
      preservedRole: currentRole,
      timestamp:     admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.error('deactivateUser: audit log failed (non-fatal)', e);
  }

  logger.info(`deactivateUser: ${targetUid} deactivated successfully`);
  return {success: true, operationId};
});

// ─────────────────────────────────────────────────────────────────────────────
// reactivateUser
// ─────────────────────────────────────────────────────────────────────────────

export const reactivateUser = onCall(async (request) => {
  await requireFreshToken(request);
  requireAdmin(request);

  const {targetUid} = request.data;
  if (!targetUid || typeof targetUid !== 'string') {
    throw new HttpsError('invalid-argument', 'targetUid is required');
  }
  const operationId = request.data.operationId || randomUUID();
  validateOperationId(operationId);

  const db   = admin.firestore();
  const auth = admin.auth();

  logger.info(`Admin ${request.auth!.uid} reactivating ${targetUid}`);

  const transitioned = await runAdminCounterTransaction(
    request.auth!.uid, targetUid, operationId, 'reactivate', null, true,
    {deactivatedAt: null, deactivatedBy: null}, db,
  );
  if (transitioned.completed) return {success: true, alreadyActive: true, operationId};
  const currentRole = transitioned.oldRole;
  try {
    await applyRoleTransition(db, auth, targetUid, operationId);
  } catch (err) {
    logger.error(`reactivateUser: transition completion failed for ${targetUid}`, err);
    throw new HttpsError('internal', `Reactivation is pending recovery for uid=${targetUid}`, {operationId});
  }

  // ── Step 5: Audit log ─────────────────────────────────────────────────────
  try {
    await db.collection('audit_logs').add({
      action:        'reactivate_user',
      performedBy:   request.auth!.uid,
      targetUser:    targetUid,
      restoredRole:  currentRole,
      timestamp:     admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.error('reactivateUser: audit log failed (non-fatal)', e);
  }

  logger.info(`reactivateUser: ${targetUid} reactivated successfully`);
  return {success: true, restoredRole: currentRole, operationId};
});
