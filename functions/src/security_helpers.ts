/**
 * Security helpers for CampusGhost Cloud Functions
 */

import {HttpsError} from 'firebase-functions/v2/https';
import {CallableRequest} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {CustomClaims, UserRole} from './types';
import {isLegacyVersionCompatible, profileRoleVersion} from './custom_claims';

/**
 * Require that the caller is authenticated
 */
export function requireAuth(
  request: CallableRequest,
): asserts request is CallableRequest & {auth: NonNullable<CallableRequest['auth']>} {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }
}

/**
 * Require that the caller has a specific role
 */
export function requireRole(
  request: CallableRequest,
  role: UserRole,
): void {
  requireAuth(request);
  
  const userRole = (request.auth.token as unknown as CustomClaims).role;
  
  if (userRole !== role) {
    throw new HttpsError(
      'permission-denied',
      `${role} role required`
    );
  }
}

/**
 * Require that the caller is an admin
 */
export function requireAdmin(
  request: CallableRequest,
): void {
  requireAuth(request);
  
  const claims = request.auth.token as unknown as CustomClaims;
  
  if (claims.role !== 'admin' || !claims.isActive) {
    throw new HttpsError(
      'permission-denied',
      'Active admin access required'
    );
  }
}

/**
 * Check if token has been revoked (stale token protection)
 */
export async function requireFreshToken(
  request: CallableRequest,
): Promise<void> {
  requireAuth(request);
  
  const user = await admin.auth().getUser(request.auth.uid);
  
  // Check if tokens were revoked after this token was issued
  if (user.tokensValidAfterTime) {
    const authTime = new Date((request.auth.token.auth_time as number) * 1000);
    const revocationTime = new Date(user.tokensValidAfterTime);
    
    if (authTime < revocationTime) {
      throw new HttpsError(
        'unauthenticated',
        'Token revoked. Please re-authenticate.'
      );
    }
  }
  
  // Check account disabled
  if (user.disabled) {
    throw new HttpsError(
      'permission-denied',
      'Account disabled'
    );
  }
  
  // Check active status in claims
  const claims = request.auth.token as unknown as CustomClaims;
  if (claims.isActive !== true) {
    throw new HttpsError(
      'permission-denied',
      'Account not active'
    );
  }

  // A token is privileged only while its claims agree with a completed,
  // authoritative profile. This closes the Auth/Firestore saga window.
  const profile = await admin.firestore().collection('users').doc(request.auth.uid).get();
  const data = profile.data();
  if (!data) {
    throw new HttpsError('permission-denied', 'Account profile is incomplete');
  }
  const profileVersion = profileRoleVersion(data);
  const validProfileVersion = profileVersion >= 1;
  const isLegacy = data.provisioningStatus === undefined &&
    data.roleTransitionStatus === undefined && data.claimsOutOfSync !== true &&
    profileVersion === 1 && typeof data.isActive === 'boolean';
  const provisioningComplete = data.provisioningStatus === 'completed' || isLegacy;
  const transitionComplete = data.roleTransitionStatus === 'completed' || isLegacy;
  const versionMatches = claims.roleVersion === profileVersion ||
    isLegacyVersionCompatible(profileVersion, claims.roleVersion);
  if (!provisioningComplete || !transitionComplete ||
      data.claimsOutOfSync === true || data.roleTransitionStatus === 'pending' ||
      data.role !== claims.role || data.isActive !== true || claims.isActive !== data.isActive ||
      !validProfileVersion || !versionMatches) {
    throw new HttpsError('permission-denied', 'Account provisioning or role transition is incomplete');
  }
}

/**
 * Validate email format
 */
export function validateEmail(email: string): void {
  if (!email || typeof email !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'Email is required'
    );
  }
  
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email.trim())) {
    throw new HttpsError(
      'invalid-argument',
      'Invalid email format'
    );
  }
}

/**
 * Validate display name
 */
export function validateDisplayName(displayName: string): void {
  if (!displayName || typeof displayName !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'Display name is required'
    );
  }
  
  if (displayName.trim().length < 2) {
    throw new HttpsError(
      'invalid-argument',
      'Display name must be at least 2 characters'
    );
  }
}

/**
 * Validate password
 */
export function validatePassword(password: string): void {
  if (!password || typeof password !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'Password is required'
    );
  }
  
  if (password.length < 6) {
    throw new HttpsError(
      'invalid-argument',
      'Password must be at least 6 characters'
    );
  }
}

/**
 * Validate role value
 */
export function validateRole(role: string): asserts role is UserRole {
  const validRoles: UserRole[] = ['student', 'technician', 'admin'];
  
  if (!validRoles.includes(role as UserRole)) {
    throw new HttpsError(
      'invalid-argument',
      `Invalid role. Must be one of: ${validRoles.join(', ')}`
    );
  }
}
