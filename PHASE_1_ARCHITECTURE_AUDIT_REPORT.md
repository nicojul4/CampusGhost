# CampusGhost - Phase 1: Full Project Architecture & Access Control Audit

**Status:** Investigation Complete  
**Date:** 2025-01-XX  
**Audit Scope:** Read-only analysis of existing architecture to prepare for role-based access control implementation (Student/Technician/Admin)

---

## Executive Summary

CampusGhost is a Flutter campus facility reporting application with Firebase backend integration. The project currently implements a **UI-only role system** with no backend authorization or persistence. Students and technicians both see only their own reports due to local-first storage design. The Firestore security rules enforce owner-only read access, but queries lack UID filtering, creating a critical production blocker.

### Critical Findings

1. **No backend authorization**: UserRole is client-side state only (Riverpod NotifierProvider)
2. **No role persistence**: Roles reset to "student" on app restart
3. **Incompatible Firestore queries**: `watchReports()` and `getReports()` will fail with current security rules
4. **No ticket assignment mechanism**: No way to route student reports to technicians
5. **No admin role**: Only student/technician exist; no management layer

---

## 1. Project Structure

### Directory Organization
```
lib/
├── config/             # Routes, Firebase config
├── enums/              # UserRole, ReportStatus (5 enums)
├── models/             # 5 models (user, report, incident, location, notification)
├── providers/          # 9 Riverpod providers
├── repositories/       # 6 repositories (data access layer)
├── screens/            # 9 screens (auth, home, profile, report, technician)
├── services/           # 7 services (Firebase, auth, storage, photo codec)
├── utils/              # Logger, validators
├── validators/         # Input validation
└── widgets/            # Reusable UI components (campus_ui.dart)

test/
├── report_local_crud_test.dart  # 53 passing tests
└── (9 test files total)
```

### Key Files
- **lib/enums/user_role.dart**: Defines `UserRole.student` and `UserRole.technician` only
- **lib/providers/user_role_provider.dart**: Client-side state management (NOT persisted)
- **lib/repositories/report_repository.dart**: Local + Firebase report operations
- **lib/services/firestore_report_service.dart**: Firestore CRUD operations
- **lib/services/local_campus_store.dart**: flutter_secure_storage wrapper
- **firestore.rules**: 69 lines, enforces owner-only read access

---

## 2. Authentication Flow

### Registration & Login
**Files:** `lib/screens/auth/login_screen.dart`, `lib/screens/auth/register_screen.dart`

**Flow:**
1. User registers via `AuthService.register()` or `AuthService.signInWithGoogle()`
2. `AuthRepository` creates Firebase Auth user
3. `UserModel` created with name, email, studentId (empty string), program ("Mahasiswa")
4. **No role assignment occurs during registration**
5. Navigation to dashboard route

**UID Usage:**
- Firebase Auth UID stored in `FirebaseAuth.currentUser.uid`
- Used in:
  - `ReportRepository._currentUserId` (reports)
  - `LocalCampusStore` key: `campus_ghost_reports_{userId}`
  - Firestore rules validation: `request.auth.uid`

**Persistence:**
- Authentication state: Firebase Auth session (persistent)
- User profile: Not stored in Firestore users collection (no write operations found)
- Role: **Not persisted** (resets on app restart)

### AuthGate Protection
**File:** `lib/widgets/auth_gate.dart`

Routes use `ProtectedRoute` wrapper requiring `authStateProvider` to be non-null. No role-based route guards exist.

---

## 3. Role System Architecture

### Current Implementation
**File:** `lib/providers/user_role_provider.dart`

```dart
class UserRoleNotifier extends Notifier<UserRole> {
  @override
  UserRole build() => UserRole.student;  // Always defaults to student

  void setRole(UserRole role) { state = role; }
  void toggleRole() { /* ... */ }
}
```

**Role Storage:**
- **Client-side only**: Riverpod NotifierProvider (in-memory state)
- **No persistence**: Role resets to `UserRole.student` on app restart
- **No Firebase integration**: Not stored in Firestore `users` collection
- **No authorization**: Anyone can call `.setRole()` in client code

**Role Assignment UI:**
- `lib/widgets/campus_ui.dart`: Drawer role switcher (lines 120-160)
- `lib/screens/technician/technician_tickets_screen.dart`: Dialog role switcher (lines 457-489)
- Both call `ref.read(userRoleProvider.notifier).setRole(UserRole.X)`

**Role Usage:**
- `lib/screens/home/home_screen.dart` line 32: Shows "Mahasiswa" or "Teknisi GA" header
- `lib/screens/profile/profile_screen.dart` line 99: Displays role label
- `lib/screens/technician/technician_tickets_screen.dart`: Uses role for UI labels only

**Authorization Check:** ❌ None. Role is never validated against backend.

---

## 4. Report Data Flow

### Student Report Creation Flow
**Path:** UI → Provider → Repository → LocalCampusStore → FirestoreReportService → Firestore

1. **UI**: `CreateReportScreen` → form submission
2. **Provider**: `reportRepositoryProvider` (Riverpod)
3. **Repository**: `ReportRepository.submitReport()` (lines 65-137)
   - Validates IncidentId (Phase 3.1 fix: lines 139-170)
   - Calls `LocalCampusStore.saveReports()` (local-first)
   - Calls `FirestoreReportService.createReport()` (background sync)
4. **Local Storage**: `flutter_secure_storage` key `campus_ghost_reports_{userId}`
5. **Firestore**: Collection `reports` document created

**Report Model:**
```dart
class ReportModel {
  String id;
  String userId;        // Firebase Auth UID
  String locationId;
  String category;
  String description;
  ReportStatus status;  // active, inProgress, resolved
  String? incidentId;   // Optional grouping
  DateTime? createdAt;
  DateTime? updatedAt;
  String? photoUrl;     // Base64-encoded data URI
  double? latitude;
  double? longitude;
  String? locationDetail;
}
```

**Firestore Document Structure:**
- Dual-cased fields: `userId`/`UserId`, `locationId`/`LocationId`, etc.
- Created by: `firestore_report_service.dart` lines 67-92

### Report Retrieval Flow

#### For Students (Current)
**Provider:** `reportRepositoryProvider.watchReportsForUser(userId)`

**Query Path:**
1. `ReportRepository.watchReportsForUser(userId)` (lines 231-241)
2. Returns `LocalCampusStore.watchReports(userId)` (local-only stream)
3. **No Firestore query** for students (local-first design)

#### For Technicians (Current)
**Provider:** `technicianTicketsProvider` (lib/providers/technician_tickets_provider.dart line 8)

**Query Path:**
1. `technicianTicketsProvider` calls `watchReportsForUser(userId)`
2. Same as student flow: **only sees own reports** (local storage for current user)
3. **Critical Issue:** Technicians cannot see other users' reports

**Firestore Queries (Unused by UI):**
- `FirestoreReportService.watchReports()` line 24: `_reportsRef.snapshots()` (no UID filter)
- `FirestoreReportService.getReports()` line 36: `_reportsRef.get()` (no UID filter)
- **Compatibility Issue:** Both queries will fail with Phase 3.1 Firestore rules requiring `resource.data.userId == request.auth.uid`

---

## 5. Technician Workflow Analysis

### Current Technician Features
**Screen:** `lib/screens/technician/technician_tickets_screen.dart`

**Capabilities:**
1. View tickets from `technicianTicketsProvider`
2. Filter by status: "Menunggu", "Sedang Dikerjakan", "Selesai"
3. Update report status:
   - "Mulai Kerjakan" → `ReportStatus.inProgress`
   - "Tandai Selesai" → `ReportStatus.resolved`
   - "Buka Ulang Tiket" → `ReportStatus.active`
4. Trigger notifications via `notificationsProvider`

**Status Update Flow:**
1. `TechnicianAction.startWorking(report)` (technician_tickets_provider.dart line 21)
2. `ReportRepository.updateReport(reportId, status)`
3. `FirestoreReportService.updateReportStatus(reportId, status)` (lines 130-145)
4. Notification added to `NotificationsProvider` (UI-only, not stored)

**Assignment Mechanism:** ❌ None
- No `assignedTo` field in ReportModel
- No admin assignment UI
- No technician selection logic
- Technicians currently see **only their own reports** (not student reports)

### Workflow Gaps
1. **No cross-user access**: Technicians cannot retrieve reports created by students
2. **No assignment logic**: No way to route report from student → technician
3. **No ticket queue**: Cannot see unassigned reports
4. **No ownership transfer**: Cannot change `userId` after creation (Firestore rules block it)

---

## 6. Admin Workflow Analysis

**Status:** ❌ **No admin role exists**

**Search Results:**
- `lib/enums/user_role.dart`: Only `student` and `technician` defined
- No admin-specific screens found
- No admin-specific providers found
- No user management UI found

**Required Admin Features (Not Implemented):**
1. View all reports (regardless of userId)
2. Assign reports to technicians
3. Manage user roles
4. View system-wide analytics
5. Override report status/ownership

---

## 7. Firestore Security Rules Analysis

**File:** `firestore.rules` (69 lines)

### Collection: `reports`
**Lines 27-65:**

#### Read Permission (Line 29-31)
```javascript
allow read: if signedIn() 
  && (resource.data.userId == request.auth.uid 
      || resource.data.UserId == request.auth.uid);
```
**Enforcement:** Owner-only read access (Phase 3.1 hardening)

**Query Compatibility Issue:**
- `watchReports()` queries all reports without UID filter → **WILL FAIL**
- `getReports()` queries all reports without UID filter → **WILL FAIL**
- **Fix Required:** Add `.where('userId', '==', currentUserId)` to queries

#### Create Permission (Line 34-51)
- Validates userId matches authenticated user
- Enforces field whitelist (18 allowed fields)
- Validates description length ≥ 10 characters
- Prevents dual userId/UserId mismatch

#### Update Permission (Line 54-58)
- Owner-only
- Prevents modification of identity fields: `id`, `userId`, `createdAt`, `IncidentId`
- Allows status updates (technician workflow)

#### Delete Permission (Line 61-63)
- Owner-only

### Collection: `users`
**Lines 12-16:**
```javascript
match /users/{userId} {
  allow read: if isOwner(userId);
  allow create, update: if isOwner(userId);
  allow delete: if false;
}
```

**Current Usage:** ❌ None
- No code writes to `users` collection during registration
- No code reads from `users` collection
- **Opportunity:** Store persistent role data here

### Collections: `locations`, `incidents`
- Read: any authenticated user
- Write: disabled (seed data only)

---

## 8. Data Model Recommendations

### Proposed Schema for Role-Based System

#### Firestore Collection: `users`
```json
{
  "uid": "firebase_auth_uid",
  "email": "student@pradita.ac.id",
  "displayName": "Nicolas Julian",
  "role": "student",  // "student" | "technician" | "admin"
  "studentId": "2410101011",
  "program": "Informatika",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-01T00:00:00Z",
  "isActive": true
}
```

**Security Rules:**
```javascript
match /users/{userId} {
  allow read: if request.auth != null;  // All authenticated users can read profiles
  allow create: if request.auth.uid == userId && request.resource.data.role == 'student';  // New users default to student
  allow update: if request.auth.uid == userId  // Self-update allowed (except role)
                && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role', 'uid']);
  // Only admins can update roles (add admin check function)
  allow delete: if false;
}
```

#### Updated `reports` Collection
**Add fields:**
- `assignedTo`: String? (technician UID, null = unassigned)
- `assignedAt`: DateTime?
- `assignedBy`: String? (admin UID)
- `statusHistory`: Array<Map> (audit trail)

**Example Document:**
```json
{
  "id": "report123",
  "userId": "student_uid",
  "locationId": "Gedung 1 - Lantai 3",
  "category": "Wifi",
  "description": "Koneksi terputus",
  "status": "Active",
  "assignedTo": "technician_uid",  // NEW
  "assignedAt": "2025-01-02T10:00:00Z",  // NEW
  "assignedBy": "admin_uid",  // NEW
  "statusHistory": [  // NEW
    {
      "status": "Active",
      "timestamp": "2025-01-01T08:00:00Z",
      "changedBy": "student_uid"
    },
    {
      "status": "InProgress",
      "timestamp": "2025-01-02T11:00:00Z",
      "changedBy": "technician_uid"
    }
  ],
  "createdAt": "2025-01-01T08:00:00Z",
  "updatedAt": "2025-01-02T11:00:00Z"
}
```

**Security Rules Updates:**
```javascript
match /reports/{reportId} {
  function isAdmin() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  }
  
  function isTechnician() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'technician';
  }
  
  // Students see their own reports
  // Technicians see assigned reports
  // Admins see all reports
  allow read: if signedIn() 
    && (resource.data.userId == request.auth.uid  // Owner
        || resource.data.assignedTo == request.auth.uid  // Assigned technician
        || isAdmin());  // Admin access
  
  // Students create reports
  allow create: if signedIn() 
    && request.resource.data.userId == request.auth.uid
    && !request.resource.data.keys().hasAny(['assignedTo', 'assignedBy']);  // Cannot self-assign
  
  // Students update their own unassigned reports
  // Technicians update status of assigned reports
  // Admins can assign and update any report
  allow update: if signedIn() 
    && (
      // Student updates own unassigned report
      (resource.data.userId == request.auth.uid 
       && resource.data.assignedTo == null
       && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['userId', 'assignedTo']))
      // Technician updates assigned report status
      || (isTechnician() 
          && resource.data.assignedTo == request.auth.uid
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'updatedAt', 'statusHistory']))
      // Admin assigns and manages reports
      || isAdmin()
    );
  
  allow delete: if isAdmin();  // Only admins can delete
}
```

---

## 9. Test Coverage Analysis

**Test Files:** 9 files, 53 passing tests (as of Phase 3.1.2)

### Existing Test Coverage
**File:** `test/report_local_crud_test.dart`

**Tests:**
1. LocalCampusStore initialization
2. Create report (local storage)
3. Read reports by userId
4. Update report status
5. Delete report
6. Watch reports stream
7. Multiple users isolation
8. **IncidentId null safety** (tests 8-13, added in Phase 3.1)
   - Null IncidentId handling
   - Empty string IncidentId
   - Type safety validation
   - Array access bounds
   - Missing Timestamp field
   - Mixed data types
9. Photo encoding/decoding (report_photo_codec_test.dart)

### Test Gaps
❌ **No tests for:**
1. Role assignment logic
2. Role persistence
3. Technician query filtering (assigned reports)
4. Admin authorization checks
5. Cross-user access validation
6. Firestore security rules (require Firebase Test SDK)
7. Report assignment workflow
8. Status history tracking

**Firestore Query Tests:** Not possible without Firebase emulator setup

---

## 10. Current vs Required State Comparison

| Feature | Current State | Required for Phase 2 |
|---------|--------------|---------------------|
| **Role Definition** | UI-only enum (student/technician) | Add admin role |
| **Role Persistence** | ❌ Not persisted (resets on restart) | Store in Firestore `users` collection |
| **Role Authorization** | ❌ Client-side only | Backend validation in security rules |
| **User Registration** | Creates Firebase Auth user | Also create `users` doc with role='student' |
| **Role Assignment** | Anyone can call `.setRole()` | Admin-only assignment via Firestore function |
| **Report Query (Student)** | Local storage only (own reports) | Keep current behavior |
| **Report Query (Technician)** | ❌ Same as student (local storage) | Query assigned reports from Firestore |
| **Report Query (Admin)** | ❌ No admin role | Query all reports with filters |
| **Report Assignment** | ❌ No mechanism | Admin assigns report to technician |
| **Firestore Queries** | ❌ Missing UID filter (will fail) | Add `.where()` filter for students |
| **Security Rules** | Owner-only read enforced | Add role-based read permissions |
| **Status Updates** | Owner-only via local storage | Assigned technician can update via Firestore |
| **Notifications** | UI-only (NotificationsProvider) | Optional: Store in Firestore for persistence |

---

## 11. Critical Blockers for Production

### P0 (Blocking)
1. **Firestore Query Incompatibility**
   - **Issue:** `watchReports()` and `getReports()` lack UID filter
   - **Impact:** Will fail with Phase 3.1 security rules
   - **Fix:** Add `.where('userId', '==', currentUserId)` in firestore_report_service.dart

2. **No Role Persistence**
   - **Issue:** Role resets to student on app restart
   - **Impact:** Technicians lose access to tickets after logout
   - **Fix:** Store role in Firestore `users` collection

3. **No Technician Access to Student Reports**
   - **Issue:** `technicianTicketsProvider` uses local storage only
   - **Impact:** Technicians cannot see assigned reports
   - **Fix:** Implement assigned reports query with security rules

### P1 (High Priority)
4. **No Assignment Mechanism**
   - **Issue:** No way to route reports to technicians
   - **Impact:** Manual role switching required (developer workaround)
   - **Fix:** Implement admin assignment UI and Firestore field

5. **No Admin Role**
   - **Issue:** Cannot manage users or assignments
   - **Impact:** No centralized control
   - **Fix:** Add admin role to enum and implement management UI

### P2 (Medium Priority)
6. **No User Profile in Firestore**
   - **Issue:** User metadata not stored in `users` collection
   - **Impact:** Cannot query users by role or status
   - **Fix:** Create user document on registration

7. **No Status History**
   - **Issue:** No audit trail for status changes
   - **Impact:** Cannot track who changed what and when
   - **Fix:** Add statusHistory array to report model

---

## 12. Implementation Recommendations

### Phase 2.1: Foundation (Core Infrastructure)
**Estimated Effort:** 8-12 hours

1. **Add Admin Role**
   - Update `lib/enums/user_role.dart` with `admin` enum value
   - Update UI role switchers

2. **Create User Profile on Registration**
   - Modify `AuthService.register()` to create Firestore `users` doc
   - Default role: `student`
   - Store: uid, email, displayName, role, studentId, program, timestamps

3. **Role Persistence Service**
   - Create `lib/services/user_profile_service.dart`
   - Methods: `getUserRole(uid)`, `updateUserRole(uid, role)` (admin-only)
   - Integrate with `userRoleProvider` initialization

4. **Update Firestore Security Rules**
   - Implement role-based read permissions
   - Add `isAdmin()`, `isTechnician()` helper functions
   - Update `reports` read rule for role-based access

### Phase 2.2: Report Assignment System
**Estimated Effort:** 10-15 hours

1. **Update Report Model**
   - Add `assignedTo`, `assignedAt`, `assignedBy` fields
   - Update Firestore mappings in `firestore_report_service.dart`

2. **Fix Firestore Queries**
   - Add UID filter to student queries
   - Create technician query: `.where('assignedTo', '==', technicianUid)`
   - Create admin query: all reports with optional filters

3. **Admin Assignment UI**
   - Screen: `lib/screens/admin/assign_reports_screen.dart`
   - Features:
     - List unassigned reports
     - List all technicians
     - Assign report to technician button
     - Update `assignedTo` field in Firestore

4. **Update Technician Provider**
   - Change `technicianTicketsProvider` to query assigned reports from Firestore
   - Remove local storage dependency for technicians

### Phase 2.3: Authorization & Validation
**Estimated Effort:** 6-8 hours

1. **Backend Role Validation**
   - Update security rules to enforce role checks
   - Prevent unauthorized status updates
   - Prevent self-assignment

2. **Route Guards**
   - Add role-based route protection in `lib/widgets/auth_gate.dart`
   - Admin-only routes: user management, analytics
   - Technician-only routes: ticket queue

3. **API Repository Refactor**
   - Update `report_api_repository.dart` for role-based queries
   - Add admin endpoints for user management

### Phase 2.4: Testing & Validation
**Estimated Effort:** 4-6 hours

1. **Unit Tests**
   - Role persistence logic
   - Query filtering by role
   - Assignment validation

2. **Integration Tests**
   - End-to-end report assignment flow
   - Cross-user access validation
   - Role switching persistence

3. **Security Rules Tests**
   - Firebase emulator setup
   - Test read/write permissions per role
   - Test unauthorized access attempts

---

## 13. Migration Strategy

### Database Migration (Existing Users)
**Challenge:** Existing Firebase Auth users have no `users` doc

**Solution:**
1. Create migration script (Cloud Function or one-time Flutter task)
2. For each Firebase Auth user:
   - Check if `users/{uid}` exists
   - If not, create with default role='student'
   - Copy displayName, email from Firebase Auth
3. Add app version check: force migration on first launch after update

### Existing Reports Migration
**Challenge:** Reports created before assignment system

**Status:** ✅ No migration needed
- Reports without `assignedTo` field are unassigned (null-safe)
- Can be assigned by admin retroactively

### Local Storage Cleanup
**Challenge:** Technicians have local storage with their own reports

**Status:** ℹ️ Optional cleanup
- Keep local storage for offline support
- Firestore becomes source of truth for assigned reports
- Local storage remains for students (offline-first)

---

## 14. Next Steps

### Immediate Actions (Phase 2 Planning)
1. **User Approval:** Review this audit report with stakeholders
2. **Prioritization:** Confirm P0/P1/P2 blocker priority
3. **Design Review:** Validate proposed data model and security rules
4. **Implementation Plan:** Break down Phase 2 into sub-phases (2.1-2.4)

### Phase 2 Kickoff Requirements
- [ ] Stakeholder approval of data model changes
- [ ] Decision on notification persistence (Firestore vs UI-only)
- [ ] Admin user creation method (manual seeding vs self-promotion)
- [ ] Technician assignment strategy (manual vs automatic)
- [ ] Test environment setup (Firebase emulator)

### Out of Scope (Future Phases)
- Real-time push notifications (FCM integration)
- Advanced analytics dashboard
- Report grouping by IncidentId (Phase 3 feature, separate from access control)
- Multi-tenant support (different campuses)
- Mobile app distribution (Play Store/App Store)

---

## 15. Appendix: Key Code Locations

### Authentication
- Registration: `lib/screens/auth/register_screen.dart`
- Login: `lib/screens/auth/login_screen.dart`
- Auth Service: `lib/services/auth_service.dart`
- Auth Repository: `lib/repositories/auth_repository.dart`

### Role Management
- Role Enum: `lib/enums/user_role.dart` (lines 1-11)
- Role Provider: `lib/providers/user_role_provider.dart` (lines 1-19)
- Role UI Switcher: `lib/widgets/campus_ui.dart` (lines 120-160)

### Report System
- Report Model: `lib/models/report_model.dart`
- Report Repository: `lib/repositories/report_repository.dart`
  - Submit: lines 65-137
  - IncidentId validation: lines 139-170 (Phase 3.1)
  - Update: lines 177-228
  - Watch: lines 231-241
- Firestore Service: `lib/services/firestore_report_service.dart`
  - Watch: line 24
  - Get: line 36
  - Create: lines 56-122
  - Update Status: lines 130-145
- Local Storage: `lib/services/local_campus_store.dart`

### Technician Workflow
- Tickets Screen: `lib/screens/technician/technician_tickets_screen.dart`
- Tickets Provider: `lib/providers/technician_tickets_provider.dart`
- Technician Actions: lines 21-60 (startWorking, resolveTicket, reopenTicket)

### Firestore Rules
- File: `firestore.rules`
- Reports rules: lines 27-65
- Users rules: lines 12-16

### Tests
- Report CRUD: `test/report_local_crud_test.dart` (53 tests)
- IncidentId safety: tests 8-13 (Phase 3.1)

---

## Audit Completion Statement

This Phase 1 audit provides a comprehensive evidence-based analysis of the CampusGhost architecture. All findings are derived from actual code inspection with specific file and line number references. The proposed data model and implementation recommendations are designed to be minimally invasive while addressing all critical blockers for a production role-based access control system.

**Audit Status:** ✅ Complete  
**Ready for Phase 2 Planning:** ✅ Yes  
**Critical Blockers Identified:** 7 (3 P0, 2 P1, 2 P2)

**Auditor Notes:**
- All code paths traced from UI → Repository → Service → Firestore
- Security rules verified against query patterns
- Test coverage mapped to implementation gaps
- No assumptions made; all findings backed by code references
