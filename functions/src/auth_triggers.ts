/**
 * Firestore trigger: users/{userId}  onCreate
 *
 * SECURITY CONTRACT:
 *   This trigger NEVER reads the role field from the Firestore document when
 *   setting Custom Claims.  Any Firestore document may have been written by an
 *   untrusted client; reading its role would create a privilege-escalation path.
 *
 *   The only two safe states when this trigger fires:
 *
 *   A) Custom Claims already contain a trusted role (set by createTechnician
 *      or seed-admin.js before the Firestore document existed).
 *      → Preserve Claims exactly as-is; stamp provisioningStatus='completed'.
 *
 *   B) No Claims exist → public self-registration path.
 *      → ALWAYS assign role='student' regardless of Firestore data.
 *      → Stamp provisioningStatus='completed'.
 *
 * IDEMPOTENCY:
 *   Cloud Functions may invoke this trigger more than once for the same event.
 *   Both branches are safe to re-execute:
 *     A) second run reads existing Claims, finds role set, stamps completed again.
 *     B) second run finds Claims already set to student, stamps completed again.
 */

import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import {CustomClaims} from './types';
import {setRoleClaims} from './custom_claims';

export const onUserProfileCreate = onDocumentCreated(
  'users/{userId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn('onUserProfileCreate: no snapshot data');
      return;
    }

    const uid = event.params.userId;
    logger.info(`onUserProfileCreate: fired for uid=${uid}`);

    const auth = admin.auth();
    const db   = admin.firestore();

    // Backend-managed accounts (for example technicians) write a pending
    // profile before setting claims. The create trigger must not downgrade it
    // to student during that saga window.
    if (snapshot.data().provisioningStatus === 'claims_pending') {
      logger.info(`onUserProfileCreate: uid=${uid} belongs to managed provisioning; skipping`);
      return;
    }

    try {
      // Read current Custom Claims from Auth (trusted source)
      const userRecord = await auth.getUser(uid);
      const existing   = (userRecord.customClaims || {}) as Partial<CustomClaims>;

      if (existing.role) {
        // Path A: trusted role already set — preserve, stamp completed
        const roleVersion = Number.isInteger(existing.roleVersion) ? existing.roleVersion! : 1;
        const isActive = existing.isActive === true;
        logger.info(
          `onUserProfileCreate: uid=${uid} has trusted role=${existing.role}; preserving`,
        );
        if (!['student', 'technician', 'admin'].includes(existing.role) ||
            existing.isActive !== true) {
          throw new Error('Existing trusted role claims are invalid or inactive for profile creation');
        }
        await setRoleClaims(auth, uid, {
          role: existing.role, isActive, roleVersion,
        });
        await db.collection('users').doc(uid).update({
          role: existing.role,
          isActive,
          roleVersion,
          provisioningStatus: 'completed',
          claimsOutOfSync:    false,
          updatedAt:          admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Path B: public self-registration — ALWAYS student
      const roleVersion = 1;
      await setRoleClaims(auth, uid, {role: 'student', isActive: true, roleVersion});
      logger.info(`onUserProfileCreate: uid=${uid} provisioned as student`);

      // Stamp Firestore to reflect the authoritative Claims value
      await db.collection('users').doc(uid).update({
        role:               'student',
        isActive:           true,
        roleVersion,
        provisioningStatus: 'completed',
        claimsOutOfSync:    false,
        updatedAt:          admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      logger.error(`onUserProfileCreate: failed for uid=${uid}`, error);

      // Mark as failed so a reconciliation job can find and retry it.
      try {
        await db.collection('users').doc(uid).update({
          provisioningStatus: 'failed',
          claimsOutOfSync: true,
          updatedAt:          admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (stampErr) {
        logger.error(
          `onUserProfileCreate: could not stamp failed status for uid=${uid}`,
          stampErr,
        );
      }
    }
  },
);
