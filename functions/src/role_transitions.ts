import {randomUUID} from 'crypto';
import * as admin from 'firebase-admin';
import {HttpsError} from 'firebase-functions/v2/https';
import {Auth} from 'firebase-admin/auth';
import {setRoleClaims} from './custom_claims';
import {UserRole} from './types';

export interface RoleTransitionResult {
  operationId: string;
  transitionId: string;
  pendingRoleVersion: number;
  oldRole: UserRole;
  oldActive: boolean;
  newRole: UserRole;
  newActive: boolean;
  changed: boolean;
  completed: boolean;
}

interface RoleOperation {
  targetUid: string;
  transitionId: string;
  pendingRole: UserRole;
  pendingIsActive: boolean;
  pendingRoleVersion: number;
  status: 'pending' | 'completed';
  attempts: number;
  oldRole: UserRole;
  oldActive: boolean;
  noChange?: boolean;
  createdAt?: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  completedAt?: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
}

const operationIdPattern = /^[A-Za-z0-9_-]{16,128}$/;

export function validateOperationId(value: unknown): asserts value is string {
  if (typeof value !== 'string' || !operationIdPattern.test(value)) {
    throw new HttpsError('invalid-argument', 'operationId must be a 16–128 character idempotency key');
  }
}

export function isLegacyProfileReady(profile: Record<string, unknown>): boolean {
  return profile.provisioningStatus === undefined &&
    profile.claimsOutOfSync !== true && profile.roleTransitionStatus === undefined &&
    (profile.roleVersion === undefined || profile.roleVersion === 1) &&
    typeof profile.isActive === 'boolean';
}

async function ensureRoleControl(db: FirebaseFirestore.Firestore): Promise<void> {
  const controlRef = db.collection('system').doc('role_control');
  await db.runTransaction(async (tx) => {
    const control = await tx.get(controlRef);
    if (control.exists) return;
    const activeAdmins = await tx.get(db.collection('users')
      .where('role', '==', 'admin').where('isActive', '==', true));
    tx.create(controlRef, {
      activeAdminCount: activeAdmins.size,
      lastUpdatedMs: Date.now(),
      lastOperation: 'auto_initialize',
    });
  });
}

/** Commit an idempotent operation record, profile intent, and counter delta. */
export async function beginRoleTransition(
  db: FirebaseFirestore.Firestore,
  actorUid: string,
  targetUid: string,
  operationId: string,
  operation: string,
  desiredRole: UserRole | null,
  desiredActive: boolean | null,
  profileUpdates: Record<string, unknown> = {},
): Promise<RoleTransitionResult> {
  validateOperationId(operationId);
  await ensureRoleControl(db);
  const transitionId = randomUUID();
  const controlRef = db.collection('system').doc('role_control');
  const targetRef = db.collection('users').doc(targetUid);
  const actorRef = db.collection('users').doc(actorUid);
  const operationRef = db.collection('system').doc('role_operations')
    .collection('operations').doc(operationId);

  return db.runTransaction(async (tx) => {
    const [controlSnap, targetSnap, actorSnap, operationSnap] = await Promise.all([
      tx.get(controlRef), tx.get(targetRef), tx.get(actorRef), tx.get(operationRef),
    ]);
    if (!targetSnap.exists) throw new HttpsError('not-found', 'User profile not found');
    const actor = actorSnap.data() || {};
    if (!actorSnap.exists || actor.role !== 'admin' || actor.isActive !== true ||
        (actor.provisioningStatus !== 'completed' && !isLegacyProfileReady(actor)) ||
        (actor.roleTransitionStatus !== undefined && actor.roleTransitionStatus !== 'completed') ||
        actor.claimsOutOfSync === true ||
        (actor.roleVersion !== undefined &&
          (!Number.isInteger(actor.roleVersion) || Number(actor.roleVersion) < 1))) {
      throw new HttpsError('permission-denied', 'Caller is no longer an eligible active admin');
    }

    const target = targetSnap.data() || {};
    if (typeof target.isActive !== 'boolean' ||
        (target.roleVersion !== undefined &&
          (!Number.isInteger(target.roleVersion) || Number(target.roleVersion) < 1))) {
      throw new HttpsError('failed-precondition', 'Target profile has invalid role state');
    }
    const oldRole = (target.role || 'student') as UserRole;
    const oldActive = target.isActive === true;
    const finalRole = desiredRole ?? oldRole;
    const finalActive = desiredActive ?? oldActive;
    const currentVersion = Number.isInteger(target.roleVersion) && Number(target.roleVersion) >= 1 ?
      Number(target.roleVersion) : 1;

    if (operationSnap.exists) {
      const prior = operationSnap.data() as RoleOperation;
      if (prior.targetUid !== targetUid) {
        throw new HttpsError('already-exists', 'operationId is already bound to a different target');
      }
      if (prior.pendingRole !== finalRole || prior.pendingIsActive !== finalActive) {
        throw new HttpsError('already-exists', 'operationId is already bound to a different transition');
      }
      if (prior.status === 'completed') {
        const stillMatches = prior.noChange === true ?
          oldRole === prior.pendingRole && oldActive === prior.pendingIsActive &&
            currentVersion === prior.pendingRoleVersion &&
            target.roleTransitionStatus !== 'pending' && target.claimsOutOfSync !== true :
          target.operationId === operationId && target.transitionId === prior.transitionId &&
            target.roleVersion === prior.pendingRoleVersion && target.role === prior.pendingRole &&
            target.isActive === prior.pendingIsActive && target.roleTransitionStatus === 'completed' &&
            target.claimsOutOfSync !== true;
        if (!stillMatches) {
          throw new HttpsError('failed-precondition', 'Completed operation no longer matches the target profile');
        }
        return {
          operationId, transitionId: prior.transitionId,
          pendingRoleVersion: prior.pendingRoleVersion,
          oldRole: prior.oldRole, oldActive: prior.oldActive,
          newRole: prior.pendingRole, newActive: prior.pendingIsActive,
          changed: false, completed: true,
        };
      }
      if (target.operationId !== operationId || target.transitionId !== prior.transitionId ||
          target.roleTransitionStatus !== 'pending' ||
          target.pendingRoleVersion !== prior.pendingRoleVersion) {
        throw new HttpsError('failed-precondition', 'Operation record and pending profile do not match');
      }
      tx.update(operationRef, {attempts: admin.firestore.FieldValue.increment(1)});
      tx.update(targetRef, {transitionAttemptCount: admin.firestore.FieldValue.increment(1)});
      return {
        operationId, transitionId: prior.transitionId,
        pendingRoleVersion: prior.pendingRoleVersion,
        oldRole: prior.oldRole, oldActive: prior.oldActive,
        newRole: prior.pendingRole, newActive: prior.pendingIsActive,
        changed: true, completed: false,
      };
    }

    if ((target.roleTransitionStatus !== undefined && target.roleTransitionStatus !== 'completed') ||
        target.claimsOutOfSync === true ||
        (target.provisioningStatus !== 'completed' && !isLegacyProfileReady(target))) {
      throw new HttpsError('failed-precondition', 'Target account has an unfinished transition or provisioning');
    }
    if (target.provisioningStatus === 'failed' || target.provisioningStatus === 'claims_pending') {
      throw new HttpsError('failed-precondition', 'Target account is not fully provisioned');
    }

    const ctrl = controlSnap.data();
    if (!ctrl || !Number.isInteger(ctrl.activeAdminCount)) {
      throw new HttpsError('failed-precondition', 'Admin counter is missing or invalid');
    }
    const adminsSnap = await tx.get(db.collection('users')
      .where('role', '==', 'admin').where('isActive', '==', true));
    if (ctrl.activeAdminCount !== adminsSnap.size) {
      throw new HttpsError('failed-precondition', 'Admin counter mismatch; reconcile before retrying');
    }
    const delta = Number(finalRole === 'admin' && finalActive) - Number(oldRole === 'admin' && oldActive);
    if (delta < 0 && ctrl.activeAdminCount + delta < 1) {
      throw new HttpsError('failed-precondition', `Cannot ${operation}: would remove the last active admin`);
    }

    if (oldRole === finalRole && oldActive === finalActive) {
      tx.create(operationRef, {
        targetUid, transitionId, pendingRole: finalRole,
        pendingIsActive: finalActive, pendingRoleVersion: currentVersion,
        status: 'completed', attempts: 0, oldRole, oldActive,
        noChange: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        operationId, transitionId, pendingRoleVersion: currentVersion,
        oldRole, oldActive, newRole: finalRole, newActive: finalActive,
        changed: false, completed: true,
      };
    }

    const pendingRoleVersion = currentVersion + 1;
    const now = admin.firestore.FieldValue.serverTimestamp();
    if (delta !== 0) {
      tx.update(controlRef, {
        activeAdminCount: ctrl.activeAdminCount + delta,
        lastUpdatedMs: Date.now(),
        lastOperation: `${operation}:${operationId}`,
      });
    }
    tx.update(targetRef, {
      ...profileUpdates,
      role: finalRole,
      isActive: finalActive,
      roleVersion: pendingRoleVersion,
      operationId,
      transitionId,
      transitionStartedAt: now,
      transitionAttemptCount: 1,
      pendingRole: finalRole,
      pendingIsActive: finalActive,
      pendingRoleVersion,
      roleTransitionStatus: 'pending',
      provisioningStatus: 'pending',
      claimsOutOfSync: true,
      updatedAt: now,
    });
    tx.create(operationRef, {
      targetUid, transitionId, pendingRole: finalRole,
      pendingIsActive: finalActive, pendingRoleVersion,
      status: 'pending', attempts: 1, oldRole, oldActive,
      createdAt: now,
    } satisfies RoleOperation);
    return {
      operationId, transitionId, pendingRoleVersion,
      oldRole, oldActive, newRole: finalRole, newActive: finalActive,
      changed: true, completed: false,
    };
  });
}

/** Retry Auth synchronization and finalize only the exact committed intent. */
export async function applyRoleTransition(
  db: FirebaseFirestore.Firestore,
  auth: Auth,
  targetUid: string,
  operationId: string,
): Promise<{role: UserRole; isActive: boolean; roleVersion: number; alreadyCompleted: boolean}> {
  validateOperationId(operationId);
  const profileRef = db.collection('users').doc(targetUid);
  const operationRef = db.collection('system').doc('role_operations')
    .collection('operations').doc(operationId);
  const [profileSnap, operationSnap] = await Promise.all([profileRef.get(), operationRef.get()]);
  if (!profileSnap.exists || !operationSnap.exists) throw new HttpsError('not-found', 'Transition record not found');
  const profile = profileSnap.data()!;
  const operation = operationSnap.data() as RoleOperation;
  if (operation.targetUid !== targetUid) throw new HttpsError('permission-denied', 'Operation target mismatch');
  if (operation.status === 'completed') {
    if (profile.operationId !== operationId || profile.transitionId !== operation.transitionId ||
        profile.roleVersion !== operation.pendingRoleVersion ||
        profile.role !== operation.pendingRole || profile.isActive !== operation.pendingIsActive ||
        profile.roleTransitionStatus !== 'completed' || profile.claimsOutOfSync === true) {
      throw new HttpsError('failed-precondition', 'Completed operation no longer matches the target profile');
    }
    return {role: operation.pendingRole, isActive: operation.pendingIsActive,
      roleVersion: operation.pendingRoleVersion, alreadyCompleted: true};
  }
  if (profile.roleTransitionStatus !== 'pending' || profile.operationId !== operationId ||
      profile.transitionId !== operation.transitionId ||
      profile.pendingRoleVersion !== operation.pendingRoleVersion ||
      profile.pendingRole !== operation.pendingRole ||
      profile.pendingIsActive !== operation.pendingIsActive ||
      profile.roleVersion !== operation.pendingRoleVersion ||
      profile.role !== operation.pendingRole || profile.isActive !== operation.pendingIsActive) {
    throw new HttpsError('failed-precondition', 'Transition intent no longer matches its pending profile');
  }

  const completedByConcurrentFinalizer = await db.runTransaction(async (tx) => {
    const [freshProfile, freshOperation] = await Promise.all([
      tx.get(profileRef), tx.get(operationRef),
    ]);
    if (!freshProfile.exists || !freshOperation.exists) throw new HttpsError('not-found', 'Transition record not found');
    const state = freshProfile.data()!;
    const record = freshOperation.data() as RoleOperation;
    if (record.status === 'completed' && record.targetUid === targetUid &&
        state.operationId === operationId && state.transitionId === operation.transitionId &&
        state.roleVersion === operation.pendingRoleVersion && state.role === operation.pendingRole &&
        state.isActive === operation.pendingIsActive &&
        state.roleTransitionStatus === 'completed' && state.claimsOutOfSync !== true) {
      return true;
    }
    if (record.status !== 'pending' || record.targetUid !== targetUid ||
        state.operationId !== operationId || state.transitionId !== record.transitionId ||
        state.roleTransitionStatus !== 'pending' ||
        state.pendingRoleVersion !== record.pendingRoleVersion) {
      throw new HttpsError('failed-precondition', 'Transition changed before Auth synchronization');
    }
    tx.update(profileRef, {transitionAttemptCount: admin.firestore.FieldValue.increment(1)});
    tx.update(operationRef, {attempts: admin.firestore.FieldValue.increment(1)});
    return false;
  });
  if (completedByConcurrentFinalizer) {
    return {role: operation.pendingRole, isActive: operation.pendingIsActive,
      roleVersion: operation.pendingRoleVersion, alreadyCompleted: true};
  }

  await setRoleClaims(auth, targetUid, {
    role: operation.pendingRole,
    isActive: operation.pendingIsActive,
    roleVersion: operation.pendingRoleVersion,
  });
  await auth.updateUser(targetUid, {disabled: !operation.pendingIsActive});

  await db.runTransaction(async (tx) => {
    const [freshProfile, freshOperation] = await Promise.all([
      tx.get(profileRef), tx.get(operationRef),
    ]);
    if (!freshProfile.exists || !freshOperation.exists) throw new HttpsError('not-found', 'Transition record not found');
    const state = freshProfile.data()!;
    const record = freshOperation.data() as RoleOperation;
    if (record.status === 'completed' && record.targetUid === targetUid &&
        record.transitionId === operation.transitionId &&
        state.operationId === operationId && state.transitionId === operation.transitionId &&
        state.roleVersion === operation.pendingRoleVersion &&
        state.role === operation.pendingRole && state.isActive === operation.pendingIsActive) {
      if (state.roleTransitionStatus === 'completed' && state.claimsOutOfSync !== true) return;
    }
    if (record.targetUid !== targetUid || record.transitionId !== operation.transitionId ||
        record.pendingRoleVersion !== operation.pendingRoleVersion ||
        state.operationId !== operationId || state.transitionId !== operation.transitionId ||
        state.pendingRoleVersion !== operation.pendingRoleVersion ||
        state.roleTransitionStatus !== 'pending' || state.role !== operation.pendingRole ||
        state.isActive !== operation.pendingIsActive) {
      throw new HttpsError('failed-precondition', 'Stale finalizer cannot complete this transition');
    }
    tx.update(profileRef, {
      provisioningStatus: 'completed',
      roleTransitionStatus: 'completed',
      claimsOutOfSync: false,
      pendingRole: admin.firestore.FieldValue.delete(),
      pendingIsActive: admin.firestore.FieldValue.delete(),
      pendingRoleVersion: admin.firestore.FieldValue.delete(),
      transitionStartedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(operationRef, {
      status: 'completed',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  if (!operation.pendingIsActive) await auth.revokeRefreshTokens(targetUid);
  return {role: operation.pendingRole, isActive: operation.pendingIsActive,
    roleVersion: operation.pendingRoleVersion, alreadyCompleted: false};
}
