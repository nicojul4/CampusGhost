# Phase 2.1.3A Remediation Report

## Scope and source findings

Inspected the current implementations of `runAdminCounterTransaction`, all its call sites, `completeRoleTransition`, `updateUserRole`, `deactivateUser`, `reactivateUser`, and `scripts/seed-admin.js` before changes.

- `runAdminCounterTransaction` already accepted desired role and active state, read the target and `system/role_control`, computed the counter delta in the transaction, and marked the target transition pending. All three callers still used an older five-argument interface and supplied preliminary-read-derived values. TypeScript consequently failed with three argument-count errors.
- `completeRoleTransition` was implemented but unused, causing the `noUnusedLocals` build error. Because it was unused, successful role calls did not have a completion path to clear the pending marker.
- The call sites performed preliminary reads and could calculate stale roles and deltas before entering the transaction.
- The prior seed script changed Auth Claims and the profile before counter reconciliation, and then overwrote the counter with a post-hoc query. This did not serialize the profile transition with concurrent role changes.
- `firestore_rules.test.ts` had a root-level `beforeEach` that called `this.skip()` when the emulator was absent. That skipped unrelated in-process counter tests too, making the previous suite report every test as pending.

## Files changed

- `functions/src/user_management.ts`
- `functions/src/index.ts`
- `scripts/seed-admin.js`
- `functions/test/firestore_rules.test.ts`

## Implementation

### Build recovery and role transitions

Updated all three transaction call sites to pass desired role/active state and let the transaction derive old values and counter delta from current Firestore state. The same transaction reads the caller profile, target profile, active-admin query, and control document. It rejects an ineligible caller, mismatched stored counter, unfinished target provisioning/transition, and any transition that would reduce active administrators below one. The control document is updated for every counter-changing transition, serializing concurrent admin promotions, demotions, deactivations, and reactivations.

After the Firestore transaction commits, Auth Claims and account disabled state are updated from the pending target state. `completeRoleTransition` then clears pending markers. While that saga is incomplete, `requireFreshToken` rejects the profile because its transition is pending or Claims are out of sync. This prevents a newly promoted role from authorizing calls before the saga completes and prevents old claims from authorizing a demoted/deactivated role.

Added and exported `reconcileRoleTransition`, an admin callable that retries the Auth and finalization steps for a committed pending transition. It does not repeat the counter transaction, so retries do not double-increment or double-decrement. Auth Claims are set to the intended role/state before the Firestore profile is marked completed.

### Seed script

The seed operation now calculates actual active Admin profiles inside the same Firestore transaction that marks the target pending and updates `system/role_control`. It refuses to proceed if an existing counter is malformed or differs from the actual profile count. A missing control document is initialized using the observed count plus the target's actual transition delta. The Auth update runs only after the transaction. If Auth or finalization fails, the target remains pending and inaccessible; rerunning the script can resume the matching pending Admin transition without applying the count delta again.

Precondition: register the intended account in Firebase Auth first and run the script from the repository root in an environment with the project service account file configured locally. If `system/role_control` exists but does not match active Admin profiles, resolve that mismatch explicitly before seeding. Run `node scripts/seed-admin.js <admin-email>`; the script is not deployed and was not executed against Firebase in this work.

### Test isolation

Changed the Firestore Rules test hooks so an unavailable emulator skips only the emulator-backed rules suite, rather than every test in the Mocha process.

## Verification results

- `npm run build` (from `functions/`): **passed**.
- `npm test` (from `functions/`): **19 passing, 0 failing, 63 pending**.
- `node --check scripts/seed-admin.js`: **passed**.
- Last Admin Protection is **not verified against production transaction logic** by the passing unit tests. `admin_counter.test.ts` exercises local simulation logic only.
- Emulator-backed Firestore Rules, Auth, concurrency, and callable integration tests were pending. `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` were not set, and no emulator-backed verification was performed.
- `git diff --check` reported trailing whitespace in unrelated existing edits under Flutter files. Those modules were not changed for this task.

## Remaining risks and deployment prerequisites

- The in-process tests do not exercise Firestore transaction retry/serialization behavior. Run Auth + Firestore Emulator integration tests, including two simultaneous Admin demotions, before treating Last Admin protection as verified.
- If a transition is interrupted, an active Admin must call `reconcileRoleTransition` for the affected account after the relevant Firebase service failure is resolved. This function must be deployed with the rest of the Functions release; it was not deployed here.
- Existing `system/role_control` mismatches intentionally stop role changes and seed runs. Reconcile stored count against active Admin profiles using an operator-controlled procedure before retrying.
- Deploy the updated Cloud Functions and Firestore Rules only after emulator-backed verification and review of the existing project state. No Firebase Functions or Rules were deployed as part of this work.
