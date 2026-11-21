/**
 * Shared type definitions for CampusGhost Cloud Functions
 */

export type UserRole = 'student' | 'technician' | 'admin';

export interface CustomClaims {
  role:        UserRole;
  isActive:    boolean;
  /** Added with the transition foundation; omitted only by legacy tokens. */
  roleVersion: number;
  lastUpdated: number;
  [claim: string]: unknown;
}

export interface UserProfile {
  uid:                string;
  email:              string;
  displayName:        string;
  studentId:          string | null;
  program:            string | null;
  photoUrl:           string | null;
  role:               UserRole;
  isActive:           boolean;
  createdAt:          FirebaseFirestore.Timestamp;
  updatedAt:          FirebaseFirestore.Timestamp;
  lastLoginAt:        FirebaseFirestore.Timestamp | null;
  deactivatedAt:      FirebaseFirestore.Timestamp | null;
  deactivatedBy:      string | null;
  roleVersion:        number;
  /**
   * Lifecycle:
   *   'claims_pending' — profile exists, Custom Claims not yet written
   *   'completed'      — profile and Claims are in sync
   *   'failed'         — provisioning failed; requires reconciliation
   */
  provisioningStatus: 'pending' | 'claims_pending' | 'completed' | 'failed';
  /**
   * Set to true when a Firestore role change succeeded but the subsequent
   * setCustomUserClaims call failed.  A reconciliation job should query
   * claimsOutOfSync == true and retry the Claims write.
   */
  claimsOutOfSync?:   boolean;
  intendedRole?:      string;
  intendedActive?:    boolean;
  roleTransitionStatus?: 'pending' | 'completed';
  pendingRole?:       UserRole;
  pendingIsActive?:   boolean;
  operationId?:       string;
  transitionId?:      string;
  transitionStartedAt?: FirebaseFirestore.Timestamp;
  transitionAttemptCount?: number;
  pendingRoleVersion?: number;
}

export interface RoleOperation {
  targetUid: string;
  transitionId: string;
  pendingRole: UserRole;
  pendingIsActive: boolean;
  pendingRoleVersion: number;
  status: 'pending' | 'completed';
  attempts: number;
  oldRole: UserRole;
  oldActive: boolean;
  createdAt: FirebaseFirestore.Timestamp;
  completedAt?: FirebaseFirestore.Timestamp;
}

export interface RoleControlState {
  activeAdminCount: number;
  lastUpdatedMs:    number;
  lastOperation:    string;
}
