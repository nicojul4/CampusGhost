# PHASE 2.1.3-B1.2 — SECURITY & CONCURRENCY REMEDIATION DESIGN

## 1. Executive Summary

This design review uses the checked-in CampusGhost source, including the B1 transition implementation. It proposes targeted changes to the existing Firebase Auth, Cloud Functions, Firestore, and Flutter architecture; it does not replace authentication or implement any changes in this phase.

The highest-risk issue is that Firestore CAS does not protect Firebase Auth Custom Claims. A delayed role-claims writer can write stale claims after a newer Firestore transition has completed. A per-UID claims writer protocol is needed, and every privileged read must continue to compare token role, active state, and `roleVersion` against the authoritative completed profile. That version check is the security fence if Auth claims ever become stale.

The second major area is Firestore report access. Current Rules authorize signed-in owners without checking account lifecycle or role, while the Flutter Firestore service reads the whole reports collection. The intended model should authorize active, completed accounts and allow reads by owner, assignee, or Admin. Flutter must issue matching scoped queries because Rules reject a broad query that could return unauthorized records.

The design also adds production-transaction Last Admin Emulator coverage, fences create-trigger behavior from backend transitions, and introduces a durable Technician provisioning journal. Refresh-token revocation becomes a tracked retryable post-transition task instead of best-effort work that may never be retried.

## 2. Root Cause Analysis

| # | Finding and source root cause | Failure or abuse scenario |
| --- | --- | --- |
| 1 | `applyRoleTransition` in `functions/src/role_transitions.ts` writes Auth Claims before its final Firestore transaction CAS. The CAS protects profile finalization only; Auth has no conditional write tied to `transitionId`. | A slow duplicate worker reads transition A, pauses, transition A completes, transition B completes and writes newer Claims, then the delayed A write lands last. A's CAS then fails, but Auth Claims now describe A while Firestore describes B. Version checks deny access, but claims become stale and can cause denial of service or stale privilege presentation. |
| 2 | `setRoleClaims` in `functions/src/custom_claims.ts` performs `getUser` followed by `setCustomUserClaims` without a per-UID lock or writer protocol. The helper preserves keys only from the snapshot it read. | Two independent role/provisioning writers read the same claims map and each replace it. The later write can discard the other writer's role/version or unrelated custom claim. |
| 3 | `requireFreshToken` runs before a callable, but `beginRoleTransition` receives only `actorUid` and checks the current profile role/active/lifecycle state. It does not compare the token `roleVersion` inside the transaction. | An Admin token is accepted at callable entry; another transaction changes that Admin profile before the role transaction commits. The in-transaction profile check helps, but without the token epoch comparison the actor's now-stale credential is not bound to the authorization state that initiated this operation. |
| 4 | `beginRoleTransition` casts `(target.role || 'student') as UserRole` without runtime enum validation. | A malformed or legacy value such as `superadmin`, null-like data, or an unexpected string enters counter-delta logic as if it were a valid role. Counter decisions and intended-state calculations then depend on an invalid role. |
| 5 | `onUserProfileCreate` skips only snapshots with `provisioningStatus === 'claims_pending'`. B1 role transitions and the updated seed write `provisioningStatus: 'pending'`. Other managed metadata is not checked. | A profile created by a backend transition can trigger the student provisioning branch, which writes student Claims/profile state while the Admin transition is pending. The transition worker and trigger can race over both Auth and Firestore. |
| 6 | `applyRoleTransition` calls `revokeRefreshTokens` after finalization for inactive users; `updateUserRole` separately revokes in best-effort code. A retry of an already-completed operation can return before the revoke is retried. | Claims/profile transition succeeds but revocation fails. The operation is recorded complete; a repeated request can short-circuit and never retry revocation. Version checks currently reduce the authorization impact, but the revocation promise and audit state are inconsistent. |
| 7 | `/reports/{reportId}` read Rules in `firestore.rules` check only sign-in and owner identity. They do not check profile active/provisioning state or role. | A deactivated account with an otherwise valid Firebase session can continue reading its own reports. Pending accounts are not denied by Rules. |
| 8 | Report reads have no Technician assignment or Admin-wide role branch. `assignedTo` is explicitly excluded on create and immutable in owner updates; there is no assignment writer found in the reviewed Flutter/Functions source. | Technicians cannot securely query their assigned tickets through these Rules; Admins cannot read reports that belong to other users. Broadening to all signed-in users would expose every report and is not an acceptable workaround. |
| 9 | `functions/test/admin_counter.test.ts` simulates counter decisions. The B1 Auth/Firestore emulator tests exercise operation retry/finalization but do not call production `beginRoleTransition` for last-Admin rejection or concurrent Admin removal. | A simulation may pass while production transaction reads, retries, profile writes, or counter serialization are wrong. The critical invariants currently lack direct integration evidence. |
| 10 | `createTechnician` creates Auth first, then profile, then Claims/finalization. Profile-write rollback failure is only logged; Claims/finalization failures are marked out-of-sync but no provisioning journal or retry/cleanup worker owns the operation. | A failed rollback leaves an Auth-only orphan; Claims or finalization failure leaves a locked account without an idempotent way to recover. Retrying the callable can create a second Auth account or collide on email without knowing which stage completed. |

## 3. Proposed Architecture

### 3.1 Role transition and Custom Claims ordering

Keep the current Firestore operation ledger and per-profile transition markers. Extend the protocol into explicit stages:

1. `beginRoleTransition` validates actor token/profile version and target role at runtime. One Firestore transaction writes the operation record, target pending intent, and counter delta.
2. A per-UID Claims coordinator acquires a durable writer lock for the exact `operationId` and `transitionId`. Only this coordinator may call Auth `setCustomUserClaims`.
3. Before writing Claims, the coordinator re-reads the authoritative operation/profile state. It writes only the state/version still current in Firestore, merging unrelated claims while it owns the lock.
4. It reads the Auth record again after the write and verifies role, active state, and `roleVersion`. It also re-reads Firestore before CAS finalization.
5. CAS finalization completes only the exact pending transition. If the operation became stale, the writer must not finalize it and must enqueue/retry synchronization from the latest authoritative profile state.
6. The account is authorized only when token Claims and completed profile match exactly. The monotonically increasing `roleVersion` is the fencing check; a stale role claim cannot authorize even if Firebase Auth accepted a late write.

Firebase Auth Custom Claims have no compare-and-set. No Firestore transaction can make a Claims write atomic or prevent an already-issued network request from completing late. The lock serializes normal writers; the roleVersion/profile check prevents stale Claims from granting access; post-write verification and a durable repair queue restore the current claims after out-of-order completion. This design accepts temporary denial of service during a stale-claims race, never temporary privilege based on stale Claims.

Do not let worker A trust only the role state captured before a pause. Every worker carries operation ID, transition ID, and expected roleVersion. If any no longer matches Firestore, it exits without using the captured role as authorization input. Keep the lock across the full Auth request and release in `finally`. Recover abandoned locks only after worker timeout plus a safety window; if the old Auth request may still be in flight, the recovery action must write the latest profile version and verify it afterward.

All custom-claim contributors must use this coordinator. Unrelated mutable claims should have one ownership convention (namespaced keys or a canonical backend claims source). A second writer that directly calls Firebase Auth would bypass both serialization and merge guarantees.

### 3.2 Actor and target validation in the production transaction

- Pass the authenticated token snapshot into `beginRoleTransition`: token role, `isActive`, and roleVersion (with the documented legacy v1 exception).
- In the same Firestore transaction that reads actor profile, require actor role `admin`, `isActive === true`, completed lifecycle, no pending/out-of-sync state, and profile roleVersion equal to token roleVersion. Read the actor profile in the transaction so a concurrent demotion/version increment creates a conflict or fails the comparison.
- Validate `target.role` at runtime against `student | technician | admin`. Missing role may default to `student` only for a documented legacy profile shape; any other value fails closed before calculating the Admin delta.
- Require an actual boolean `target.isActive` and a valid positive integer roleVersion or the explicit legacy default. Do not use truthy/fallback casts for privileged fields.
- Preserve operation-ID binding and same-ID retry semantics. Operation retries do not increment roleVersion/counter again; a different operation against a pending target remains rejected.

### 3.3 Trigger and provisioning event ownership

`onUserProfileCreate` should distinguish a client-created Student profile from a backend-managed profile by lifecycle/operation metadata, not by checking a single legacy string. It may provision Student only when the snapshot has no backend operation/transition marker and is in the allowed client-created initial state. It must no-op for any `pending`, `claims_pending`, operationId, transitionId, or provisioning journal record. A managed pending account is completed only by the transition/provisioning coordinator.

On trigger retry, read the current profile and operation record and verify that no newer transition exists before changing Claims or lifecycle fields. For a trusted pre-existing role, normalize through the coordinator and CAS the profile to the same role/version. Never stamp completed solely because the Auth record contains a role claim.

### 3.4 Durable refresh-token revocation

Add a post-transition task state to the operation ledger, such as `revocationStatus: pending | completed`, `revokeRequestedAt`, and `revokedAt`. The Firestore role transition remains authoritative; version/profile checks already reject old tokens. Token revocation is a required, retryable cleanup task, not the only authorization barrier.

After Claims synchronization and profile CAS, invoke `revokeRefreshTokens`. On success, CAS the operation revocation state to completed. On failure, leave it pending and surface/alert the failure. Any repeated callable or scheduled worker must check and retry this task even when the role transition itself is already complete. Repeated revocation is safe. Apply consistently to promotion/demotion, deactivation, and reactivation according to the final session policy.

### 3.5 Report authorization and queries

Create a Rule helper that validates the caller profile against verified token Claims: active, account lifecycle completed, no pending transition/out-of-sync state, matching role and roleVersion. Keep the narrow legacy-v1 compatibility rule only for unchanged legacy profiles/tokens. A profile lookup is needed to deny pending/inactive accounts because a token alone cannot represent a later profile transition.

Read policy:

- Student: own report (`userId == auth.uid`; temporarily also legacy `UserId`).
- Technician: report assigned to that Technician (`assignedTo == auth.uid`; add a legacy alias only if actual deployed data uses one).
- Admin: all reports, only if profile/Claims are active and consistent.
- Everyone else, including inactive, pending, failed, or claims-out-of-sync accounts: no report read.

Rules are not result filters. Flutter must select a role-specific query that proves every possible returned document satisfies the role branch:

- Student: `where('userId', isEqualTo: uid)` and, during dual-case migration only, a separate `where('UserId', isEqualTo: uid)` query merged/deduplicated client-side.
- Technician: `where('assignedTo', isEqualTo: uid)` (plus a separate query only if an audited legacy assignment field exists).
- Admin: unfiltered reports collection query is allowed by the Admin branch.

Do not issue one unfiltered query and filter results in Dart. The current `FirestoreReportService.watchReports()` and `getReports()` read the collection without filters, so they must become role-aware or be replaced by a query service used by the report providers. Add required Firestore indexes for compound role query plus sort/filter fields.

Mutation policy should preserve current functions without broadening privileges: Student report creation remains self-owned and active-only; owners may edit only allowed descriptive fields; Technician may change the existing workflow status only for reports assigned to them and only through an explicit allowed transition set; assignment, incident linkage, immutable identity/timestamps, and Admin-level workflow changes remain backend-controlled. Since reviewed source contains no `assignedTo` writer, establish how reports are assigned before enabling Technician-only read rules. Do not allow a Technician to assign tickets to themselves.

### 3.6 Technician provisioning journal

Add a backend-only `system/provisioning_operations/{operationId}` journal with stage, target UID, normalized email, role, attempt count, timestamps, and error code. Never store password or credential material. Generate operation ID and deterministic Auth UID on the trusted backend so retry after Auth creation but before journal UID update can find the same account. Before reusing an existing Auth UID, verify it belongs to that exact journal operation; never adopt an arbitrary existing email account.

Stages: `requested → auth_created → profile_pending → claims_pending → completed`; failure/cleanup states include `retryable` and `cleanup_pending`. If profile write fails, leave a recoverable journal and retry the same profile write. Delete an orphan only after the journal proves the Auth account was created by that operation and no completed/active profile exists. If delete fails, keep cleanup_pending and retry/alert. The same Claims coordinator and roleVersion protocol apply to Technician provisioning.

## 4. Changes Per File

| File | Planned change |
| --- | --- |
| `functions/src/role_transitions.ts` | Compare actor token version to actor profile inside transaction; validate target role/state; add Claims writer coordination; CAS every transition stage; persist retryable revocation state. |
| `functions/src/custom_claims.ts` | Implement per-UID serialized Claims coordinator, expected transition/version checks, post-write verification, and one merge policy for unrelated claims. Keep it the only direct `setCustomUserClaims` writer. |
| `functions/src/types.ts` | Add actor-version, Claims-lock, revocation-task, and provisioning-journal types/stages. |
| `functions/src/security_helpers.ts` | Keep strict role/isActive/roleVersion/profile matching; centralize legacy compatibility and ensure all privileged callables use it. |
| `functions/src/user_management.ts` | Pass token epoch to transition transaction; expose only safe retry IDs; retry revocation for completed operations; preserve existing Admin features. |
| `functions/src/auth_triggers.ts` | Ignore all backend-managed pending/journal states; process only valid client Student creation; CAS against current operation/version before finalizing. |
| `functions/src/index.ts` | Export scheduled/internal Claims/revocation/provisioning retry workers when implemented. No public Student/Technician recovery bypass. |
| `scripts/seed-admin.js` | Route through serialized claims coordinator and operation ledger; preserve unrelated Claims; record retry/revocation outcome. Keep operator-only bootstrap semantics. |
| `firestore.rules` | Add account-ready helper; enforce Student-owner, Technician-assigned, Admin-all reads; deny inactive/pending/mismatched accounts; keep report identity/workflow fields backend-controlled except explicit assigned-Technician status transitions. |
| `functions/test/role_transitions.test.ts` (new or extend) | Auth + Firestore Emulator tests that call production transaction/finalizer functions for Last Admin and concurrency invariants. |
| `functions/test/firestore_rules.test.ts` | Role-specific read/write matrix, lifecycle denial, query-shape, and field immutability Rules tests. |
| `functions/test/auth_triggers.test.ts` | Trigger/transition/provisioning interleavings and duplicate delivery. |
| `functions/test/provisioning_recovery.test.ts` | Technician journal crash-point retries, duplicate operations, and orphan cleanup. |
| `lib/services/firestore_report_service.dart` | Replace whole-collection Student/Technician reads with role-scoped streams/queries; preserve Admin full-list behavior. |
| `lib/repositories/report_repository.dart` | Route role-scoped queries and merge legacy casing results without broad reads. |
| `lib/providers/report_provider.dart` | Select the appropriate query by verified app role and UID; invalidate on role/session changes. |
| `lib/providers/technician_tickets_provider.dart` | Query assigned tickets, not the signed-in user's own reports. |
| `lib/screens/technician/technician_tickets_screen.dart` and workflow service | Preserve start/resolve/reopen behavior through the approved assigned-Technician mutation path. |
| `firestore.indexes.json` | Add indexes required by assignment/owner filters and ordering. |

Flutter changes are limited to report query/mutation compatibility; Auth architecture and unrelated screens remain intact.

## 5. Security Rules Matrix

`accountReady()` means: signed-in token role is supported, token `isActive == true`, token roleVersion matches the user's Firestore profile, the profile is active, provisioning is completed, role transition is completed, and Claims are not out-of-sync. The documented legacy v1 exception applies only when all relevant fields are absent in the expected legacy shape. Missing/malformed/pending fields deny access.

| Caller state | Read own reports | Read assigned reports | Read all reports | Create report | Change workflow status |
| --- | --- | --- | --- | --- | --- |
| Active completed Student | Yes, owner match | No | No | Yes, with owner UID fixed to auth UID | No |
| Active completed Technician | No by default unless also owner by policy | Yes, `assignedTo == auth.uid` | No | No unless an existing product flow requires it | Yes only for own assignment and allowed status transitions |
| Active completed Admin | Yes | Yes | Yes | Keep through existing trusted workflow; no broad new client write | Prefer callable/backend workflow; no unrestricted direct edits |
| Inactive account | No | No | No | No | No |
| Pending provisioning/transition or claims mismatch | No | No | No | No | No |
| Student/Technician with stale roleVersion token | No | No | No | No | No |

Admin's “all reports” grant is read access by default. It does not silently grant direct mutation of status, assignment, incident IDs, identity, or timestamps. Existing report owner editing remains limited to descriptive fields. Assigned Technician status changes preserve current ticket actions but must not allow self-assignment or changes to owner/assignment/incident identity.

Query contract:

- Student client queries must include equality on `userId`; legacy `UserId` data is fetched with a separate constrained query until migration completes.
- Technician client queries must include equality on backend-written `assignedTo`.
- Admin client queries may read the collection without an owner/assignment predicate.
- A Student/Technician unfiltered collection query must fail in Rules tests even if the client intends to filter afterward.
- Each query's `orderBy`, status filters, and role predicate must be supported by indexes and must remain provable to Rules. Do not rely on `limit()` or client-side filtering as authorization.

## 6. Concurrency and Recovery Strategy

### Claims writer ordering

1. A Claims writer claims a per-UID lock with operation ID, transition ID, expected roleVersion, owner token, and lock generation.
2. It verifies Firestore still contains that exact pending or completed desired state before calling Auth.
3. It merges unrelated claims while it exclusively owns the writer slot, writing role/isActive/roleVersion as a complete tuple.
4. It verifies the returned Auth record and re-reads Firestore. If the profile moved, it leaves the newer transition pending and queues synchronization from current Firestore state.
5. It releases the lock only after the Auth request is known complete. Expired-lock takeover waits beyond the maximum function execution window and records a new generation. A late old write is still possible because Auth has no CAS; token/profile version equality denies it, and a latest-state repair task corrects it.

The system must not claim that Firestore CAS alone prevents an old Auth write. The safety property is: stale claims cannot pass backend or Firestore authorization; serialization reduces races; reconciliation repairs stale Claims. This is the strongest practical guarantee available without replacing Firebase Auth.

### Revocation retry

Persist token revocation as an operation-ledger task. Retry from the same Admin callable or internal scheduler even after role transition status is completed. Keep all old tokens fenced by roleVersion/profile checks regardless of revoke success. Test Auth errors and repeated revoke attempts.

### Last Admin invariants

All Admin membership changes must use the production `beginRoleTransition` transaction and shared `system/role_control`. The transaction reads current actor, target, control, and active Admin query; compares actor token version; validates target role; checks the counter against actual profiles; computes delta; and commits counter, profile pending intent, and operation record atomically. No other client or Admin SDK writer may change Admin membership outside this pathway except audited seed/bootstrap/reconciliation.

## 7. Migration and Backward Compatibility

1. Keep legacy roleVersion 1 acceptance temporarily. Profiles without version and matching legacy claims are interpreted as v1; malformed versions deny. Do not reset existing roleVersion.
2. Backfill/observe profile version and lifecycle fields using a dry-run report first. Avoid changing Claims on all accounts in one unbounded batch.
3. Dual-case report identity remains readable through separate constrained queries for `userId` and `UserId`; new writes must set canonical `userId` (and optionally mirror `UserId` only while old clients require it).
4. Confirm actual assignment field casing/data before enabling Technician Rules. New assignment writes use canonical `assignedTo`; migrate old assignment data with a reviewed one-time plan if any exists.
5. Existing tokens without roleVersion remain valid only for unchanged v1 profiles. First role transition moves the profile and new Claims to v2; old tokens then fail closed and require refresh/sign-in.
6. Claim lock/journal records are backend-only. Firestore Rules must explicitly deny nested system subcollections. No credentials, passwords, or service account material enter these records.
7. Deploy order must avoid locking all clients: deploy compatible Functions/Rules with legacy branch, then role-scoped Flutter queries, then perform measured data/Claims migration, then remove legacy casing/version exceptions only after telemetry confirms no remaining use.

## 8. Detailed Test Plan

All transaction/concurrency claims below require Auth + Firestore Emulator integration tests that import and invoke the production transition/finalizer module. A simulator or hand-calculated delta test is supplementary only.

### Custom Claims races and role transition

- Delay an old finalizer between profile read and Auth write; complete a newer transition; let the old write finish last. Assert the old operation cannot finalize, the stale token/version is denied, and repair restores latest Auth Claims.
- Run two `setRoleClaims` writers for one UID with different role versions and unrelated claim patches. Assert serialization preserves unrelated keys and final Auth Claims match newest completed profile.
- Simulate lock owner crash, lock timeout, takeover, and late writer; prove stale version never authorizes and repair completes.
- Actor token roleVersion stale while profile is current Admin; `beginRoleTransition` must reject inside the transaction.
- Actor profile changes concurrently with begin transaction; exactly the valid epoch can commit.
- Invalid/missing target roles and malformed active/version fields fail before any counter write.
- Retry same operation ID after each transaction/Auth/finalization failure point; counter and roleVersion change once.

### Production Last Admin and concurrency

- Single active Admin demotion rejected; single active Admin deactivation rejected.
- With two Admins, simultaneous demotions/deactivation: only one removal commits and count/profile query remains one.
- Concurrent student/technician promotions, reactivation, demotion, and deactivation interleavings yield exact counter equality with active Admin profiles.
- Counter absent initializes once; malformed/mismatched counter blocks operations; no preliminary read is the only guard.
- Exercise actor self-demotion, stale actor version, pending target, duplicate operation ID and target mismatch.
- Assert transaction rollback leaves Auth claims untouched when Firestore transaction rejects.

### Trigger, revocation, and Technician journal

- Create-trigger delivery during `provisioningStatus=pending`, `claims_pending`, transition ID, or provisioning journal: trigger does not set Student Claims or finalize managed profile.
- Duplicate trigger delivery for a genuine Student profile is idempotent and preserves unrelated Claims.
- Inject Auth claim failure, Auth update failure, finalization failure, revocation failure, and retry each stage; pending tasks remain durable and no stale Claims authorize.
- Technician Auth created/profile failed; retry uses same operation UID and does not duplicate account.
- Claims succeeded/final profile failed; journal retries safely.
- Rollback delete failure leaves cleanup task; repeated cleanup only deletes the UID proven to belong to that operation.
- No password appears in journal data.

### Rules and Flutter query behavior

- Student owner query succeeds; unfiltered Student query fails; other student's reports fail.
- Technician assigned query succeeds; unfiltered Technician query fails; unassigned and other-tech reports fail.
- Admin unfiltered query succeeds only with active completed matching role/version profile.
- Inactive, pending provisioning, pending role transition, claims mismatch, stale roleVersion, malformed profile, and disabled account are denied.
- Legacy `UserId` and canonical `userId` constrained queries each work during migration and deduplicate client results.
- Client cannot self-assign, change assignment, owner IDs, status outside allowed assigned-Tech transitions, incident IDs, immutable timestamps, or system journal records.
- Flutter repository/provider tests assert the generated query contains the required equality constraint for each role; no client-side post-filter is treated as security.
- Test required indexes in emulator/deployment validation and verify current technician start/resolve/reopen flow remains available for assigned tickets.

## 9. Implementation Phases

1. **B1.2a — Transition validation:** actor token epoch in transaction, runtime role validation, and clear legacy profile policy.
2. **B1.2b — Claims serialization:** per-UID writer coordination, operation/version fencing, post-write verification, and stale-claim repair task; keep profile version as authorization fence.
3. **B1.2c — Retryable side effects:** durable refresh-token revocation status and retry path, including already-completed operations.
4. **B1.2d — Trigger isolation:** lifecycle/operation-aware onCreate handling and transition/provisioning CAS.
5. **B1.2e — Report Rules:** account-ready helper and role read matrix, with deny-by-default field/workflow writes.
6. **B1.2f — Flutter query alignment:** role-aware report query service/providers, legacy casing merge, assignment source confirmation, and ticket workflow preservation.
7. **B1.2g — Technician journal:** deterministic idempotent provisioning, durable recovery and orphan cleanup worker.
8. **B1.2h — Emulator verification:** production transaction Last Admin suite, Auth/Claims race injections, full Rules/query matrix, Flutter repository tests, then full build/test and rollout rehearsal.

No implementation, deployment, seed execution, or Firebase production access was performed for this design review.

## 10. Risks and Decisions to Confirm

1. **Assignment ownership:** reviewed source has no clear backend writer for `assignedTo`. Confirm which existing Admin workflow assigns tickets, or approve adding a narrow Admin callable. Do not enable Technician assigned reads until assignments have a trusted source.
2. **Technician status writes:** confirm allowed transitions (for example Active → In Progress → Resolved and Reopened) and whether Firestore Rules or a callable should enforce them. A callable is easier to audit; Rules can preserve direct client behavior with a narrow changed-key/state matrix.
3. **Admin report permissions:** confirm whether Admin is read-all only or may directly edit/delete reports. Recommended default is read-all with sensitive mutations remaining backend-only.
4. **Claims lock availability:** a non-expiring lock is safest against overlapping Auth writes but can require operator recovery after a crash; expiring leases improve availability but cannot absolutely stop a late Auth request. Confirm acceptable recovery delay and alerting.
5. **Unrelated claims ownership:** identify any external service or console process that writes custom claims. All writers must use the same protocol or declare a non-overlapping namespace and merge policy.
6. **Legacy field migration:** confirm how long dual `UserId` casing must remain supported and whether production reports actually contain legacy assignee fields. No production data was accessed to answer this.
7. **Session revocation policy:** decide whether role promotion/reactivation should revoke all refresh tokens or rely on roleVersion and require a fresh sign-in only for selected transitions.
8. **Scheduled worker runtime:** confirm Cloud Functions scheduler/Cloud Tasks availability, retry budget, monitoring destination, and IAM role before selecting a concrete recovery trigger.
9. **Last Admin bootstrap:** define audited break-glass steps for a corrupted counter or no healthy Admin, separate from callable recovery. The path must not accept a client-supplied Admin role.

## Recommended implementation order

Start with B1.2a, B1.2b, and B1.2c so server authorization remains fenced while claims synchronization and retries are hardened. Then isolate the profile trigger, confirm the Technician assignment source, and implement Rules together with role-scoped Flutter queries. Add the Technician provisioning journal after the same Claims coordinator is stable. Finish with Emulator tests against the production transaction functions and Rules matrix before any deployment planning.
