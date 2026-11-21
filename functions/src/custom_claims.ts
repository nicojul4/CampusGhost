import {Auth} from 'firebase-admin/auth';
import {CustomClaims, UserRole} from './types';

export interface RoleClaimState {
  role: UserRole;
  isActive: boolean;
  roleVersion: number;
}

/** The single writer for role claims. Unrelated claim keys are preserved. */
export async function setRoleClaims(
  auth: Auth,
  uid: string,
  state: RoleClaimState,
): Promise<void> {
  const record = await auth.getUser(uid);
  const claims: CustomClaims = {
    ...(record.customClaims || {}),
    role: state.role,
    isActive: state.isActive,
    roleVersion: state.roleVersion,
    lastUpdated: Date.now(),
  };
  await auth.setCustomUserClaims(uid, claims);
}

/** Legacy profiles/tokens used roleVersion=1 implicitly before version claims. */
export function profileRoleVersion(profile: Record<string, unknown>): number {
  const value = profile.roleVersion;
  if (value === undefined) return 1;
  return Number.isInteger(value) && Number(value) >= 1 ? Number(value) : 0;
}

export function isLegacyVersionCompatible(
  profileVersion: number,
  claimVersion: unknown,
): boolean {
  return claimVersion === undefined && profileVersion === 1;
}
