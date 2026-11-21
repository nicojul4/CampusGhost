import { initializeApp } from 'firebase-admin/app';

initializeApp();

// Existing functions
export { onReportCreated } from './on_report_created';
export { resolveStaleIncidents } from './resolve_stale_incidents';

// Phase 2.1: User management and authentication
export { onUserProfileCreate } from './auth_triggers';
export {
  createTechnician,
  updateUserRole,
  reconcileRoleTransition,
  deactivateUser,
  reactivateUser,
} from './user_management';
