# Architecture — Campus Ghost 👻

Build a mobile application named **Campus Ghost**.

## Purpose

Help students monitor and report real-time facility conditions on campus. The application collects issue reports from students, groups them into incidents by location and category, and displays a live campus condition map. Dashboard reads reports from Firestore. Data synchronization happens in real-time via Firestore listeners.

## Stack

- Framework: Flutter (Dart)
- Backend: Firebase (**requires Blaze plan** — see "Backend Architecture Decision" below)
- Database: Cloud Firestore
- Authentication: Firebase Auth (Email/Password + Google Sign-In)
- Storage: Firebase Cloud Storage
- **Server logic: Cloud Functions for Firebase (Node.js/TypeScript)** — trusted
  backend for incident grouping, severity scoring, spam/duplicate rejection,
  and auto-resolve (see below). Client never writes to `incidents` directly.
- State Management: Riverpod
- Maps: `flutter_map` + OpenStreetMap tiles (final choice for v1 — no API key/billing required; revisit `google_maps_flutter` only if OSM tile quality becomes an issue post-MVP)
- Minimum Android SDK: 21 (Android 5.0)
- IDE: Android Studio / VS Code

## Code Rules

- Do not add comments unless truly necessary.
- Use PascalCase for all classes, types, enums, models, widgets, and file-level constants.
- Use camelCase for local variables, function names, and parameters.
- Use snake_case for file names and folder names (Dart convention).
- Keep code lines below 120 characters where practical.
- Use a clean and simple folder structure.
- Separate UI, business logic, and data layers.
- Do not put business logic inside widgets.
- All Firestore operations go through repository classes.
- Use Riverpod providers for state management.

---

## Backend Architecture Decision

Earlier drafts of this document kept all incident-grouping, severity, and
auto-resolve logic on the client to avoid the cost of Firebase's Blaze
(pay-as-you-go) plan. Review feedback surfaced three concrete problems with
that approach:

1. **Reliability risk in auto-resolve.** Running the "resolve stale
   incidents" batch job from a random user's phone means it only runs if
   *someone happens to open the app*, and a single Firestore `WriteBatch` is
   capped at 500 writes — an incident with more linked reports than that
   can't be resolved atomically from the client at all.
2. **Naive severity scoring.** Severity based purely on `ReportCount` treats
   5 reports of "toilet out of tissue" as more urgent than 1 report of
   "electrical short circuit" — count alone doesn't capture risk.
3. **Spam is trivial to bypass.** The 5-minute duplicate-report check only
   existed in client code / a Firestore transaction the client itself runs —
   anyone calling the Firestore SDK/REST API directly (skipping the app)
   could flood the database with fake reports, since nothing server-side
   ever validated the request.

**Decision for this version:** move report intake to a **Cloud Function**
that acts as the single trusted writer for `incidents`, using the Admin SDK
(which bypasses Security Rules, so rules alone no longer need to carry the
full burden of validation). This does mean the project must be on the
**Blaze plan** — Cloud Functions require it even though the free monthly
quota is large enough that a single-campus MVP is very unlikely to incur
real cost. If billing is genuinely a hard blocker, the fallback is to keep
the client-side transaction approach from the previous revision, accept its
reliability and spam limitations as known MVP trade-offs, and revisit this
decision before scaling beyond a pilot.

---

## Main Entities

### 1. User

| Field     | Type      | Description            |
| --------- | --------- | ---------------------- |
| Id        | String    | Firebase Auth UID      |
| Name      | String    | Nama pengguna          |
| Email     | String    | Email pengguna         |
| PhotoUrl  | String?   | Foto profil (opsional) |
| CreatedAt | Timestamp | Waktu akun dibuat      |

### 2. Location

| Field     | Type      | Description                                      |
| --------- | --------- | ------------------------------------------------ |
| Id        | String    | Auto-generated Firestore ID                      |
| Name      | String    | Nama lengkap lokasi, contoh: "Gedung 1 Lantai 3" |
| Building  | String    | Nama gedung, contoh: "Gedung 1"                  |
| Floor     | int       | Nomor lantai                                     |
| Latitude  | double    | Koordinat latitude                               |
| Longitude | double    | Koordinat longitude                              |
| CreatedAt | Timestamp | Waktu lokasi dibuat                              |

### 3. Report

| Field       | Type      | Description                                                   |
| ----------- | --------- | ------------------------------------------------------------- |
| Id          | String    | Auto-generated Firestore ID                                   |
| UserId      | String    | ID pengguna yang membuat laporan                              |
| LocationId  | String    | ID lokasi fasilitas                                           |
| Category    | String    | Kategori masalah (enum)                                       |
| Description | String    | Deskripsi masalah                                             |
| PhotoUrl    | String?   | URL foto laporan (opsional)                                   |
| Status      | String    | Status laporan: `Active`, `Resolved`                          |
| IncidentId  | String?   | ID incident terkait (diisi Cloud Function saat report masuk, bukan client) |
| CreatedAt   | Timestamp | Waktu laporan dibuat (server timestamp)                       |
| UpdatedAt   | Timestamp | Waktu laporan terakhir diperbarui                             |

### 4. Incident

| Field           | Type      | Description                                        |
| --------------- | --------- | -------------------------------------------------- |
| Id              | String    | Auto-generated Firestore ID                        |
| LocationId      | String    | ID lokasi                                          |
| Category        | String    | Kategori masalah                                   |
| ReportCount     | int       | Jumlah laporan terkait                             |
| Status          | String    | Status incident: `Active`, `Resolved`              |
| Severity        | String    | Tingkat keparahan: `Normal`, `Warning`, `Critical` |
| FirstReportedAt | Timestamp | Waktu laporan pertama                              |
| LastUpdatedAt   | Timestamp | Waktu terakhir ada laporan baru                    |

> `Severity` bukan fungsi murni dari `ReportCount`. Lihat "Severity Scoring"
> di bawah — setiap `Category` punya bobot urgensi dasar, jadi 1 laporan
> kategori berbahaya (mis. kelistrikan) bisa langsung `Critical` walau baru
> 1 laporan, sementara kategori low-risk (mis. WiFi) butuh laporan lebih
> banyak untuk naik level.


---

## Enums

### ReportCategory

Each category carries a **base urgency weight** used by the severity scoring
logic below — this is what fixes the "5 reports of empty tissue vs. 1 report
of a short circuit" problem raised in review. Weights are a starting point,
tune them with real campus safety input before launch, not engineering
guesswork.

| Category    | Base Urgency Weight | Rationale                          |
| ----------- | -------------------- | ----------------------------------- |
| `Lift`      | 3 (High)              | Trapped-person / fall risk          |
| `Ac`        | 2 (Medium)            | Can involve electrical component, moderate risk |
| `Toilet`    | 1 (Low)               | Hygiene/inconvenience, not safety   |
| `Wifi`      | 1 (Low)               | Inconvenience only                  |
| `Printer`   | 1 (Low)               | Inconvenience only                  |
| `Proyektor` | 1 (Low)               | Inconvenience only                  |
| `Parkir`    | 2 (Medium)            | Can involve safety/security         |
| `Lainnya`   | 1 (Low, default)      | Unclassified — default to low until triaged |

### ReportStatus

```text
Active
Resolved
```

### IncidentStatus

```text
Active
Resolved
```

### FacilitySeverity

Computed from `ReportCount × CategoryUrgencyWeight` (see "Severity Scoring"
section below), NOT from `ReportCount` alone:

```text
Normal      → 🟢 No active incident at this location
Warning     → 🟡 Score 1-2
Critical    → 🔴 Score 3+
```

### Severity Scoring (Cloud Function logic)

```text
score = ReportCount × CategoryUrgencyWeight(incident.Category)

score 1-2  → Severity = "Warning"
score 3+   → Severity = "Critical"
```

Example: a `Lift` incident (weight 3) hits Critical (score 3) after just
**1 report**. A `Wifi` incident (weight 1) needs **3 reports** to reach the
same Critical score. This directly fixes the "toilet tissue vs. short
circuit" mismatch raised in review — high-risk categories escalate faster.

### ActivityStatus (untuk incident)

```text
Active       → Incident masih berlangsung (laporan terakhir < 24 jam)
Stale        → Tidak ada laporan baru > 24 jam
Resolved     → Semua laporan ditandai selesai
```

---

## Firestore Structure

```text
users/
  └── {userId}
        ├── Name          : String
        ├── Email         : String
        ├── PhotoUrl      : String?
        └── CreatedAt     : Timestamp

locations/
  └── {locationId}
        ├── Name          : String
        ├── Building      : String
        ├── Floor         : int
        ├── Latitude      : double
        ├── Longitude     : double
        └── CreatedAt     : Timestamp

reports/
  └── {reportId}
        ├── UserId        : String
        ├── LocationId    : String
        ├── Category      : String
        ├── Description   : String
        ├── PhotoUrl      : String?
        ├── Status        : String
        ├── IncidentId    : String?
        ├── CreatedAt     : Timestamp
        └── UpdatedAt     : Timestamp

incidents/
  └── {incidentId}
        ├── LocationId    : String
        ├── Category      : String
        ├── ReportCount   : int
        ├── Status        : String
        ├── Severity      : String
        ├── FirstReportedAt : Timestamp
        └── LastUpdatedAt   : Timestamp
```

---

## Required Composite Indexes

The incident-lookup query in "Database Rules" filters `incidents` by
`LocationId` + `Category` + `Status`, and orders/filters by `LastUpdatedAt`
(range: last 24 hours). Firestore will reject this combination until a
matching composite index exists — create it up front instead of discovering
it via a runtime error:

```text
Collection: incidents
Fields indexed: LocationId (Asc), Category (Asc), Status (Asc), LastUpdatedAt (Desc)
```

A second index is needed for `userReportsProvider` (reports filtered by
`UserId`, ordered by `CreatedAt` descending):

```text
Collection: reports
Fields indexed: UserId (Asc), CreatedAt (Desc)
```

---

## Firestore Rules

```text
users:
  - Authenticated user can read own profile.
  - Authenticated user can create and update own profile.
  - Users cannot delete their own profile.

locations:
  - All authenticated users can read.
  - Only admin (future) can create, update, and delete.
  - For MVP, locations are pre-seeded.

reports:
  - All authenticated users can read.
  - Authenticated user can create a report with ONLY these client-writable
    fields: `UserId` (must match auth UID), `LocationId`, `Category`,
    `Description`, `PhotoUrl`. The client must NOT set `IncidentId`,
    `Status`, or `CreatedAt` — the rule rejects a create request that
    includes them (they default to `null` / `"Active"` / server timestamp).
  - `IncidentId`, `Status`, and `UpdatedAt` are written ONLY by the Cloud
    Function (via Admin SDK, which bypasses these rules entirely) after it
    validates and processes the report. No client write path can touch them.
  - Reports cannot be deleted (data integrity), and cannot be updated by
    their owner at all — once submitted, only the trusted backend touches it.

incidents:
  - All authenticated users can read.
  - **No client write access at all** — `allow write: if false;` for this
    collection. Every create/update to `incidents` (increment `ReportCount`,
    recompute `Severity`, resolve `Status`) happens exclusively inside the
    Cloud Function, using the Admin SDK, which is not subject to Security
    Rules. This removes the entire class of client-tampering risk (fake
    `ReportCount`, arbitrary `Severity`, early self-resolving incidents)
    that field-level rules could only partially prevent.
```

---

## Firebase Storage Rules

Storage rules were missing from earlier drafts — without them the bucket
falls back to fully open or fully locked depending on initial console setup,
neither of which is correct here.

```text
reports/{reportId}/photo.jpg:
  - Read: any authenticated user (report photos are visible to all, same as
    the report document itself).
  - Write: only the authenticated user whose UID matches the `UserId` on the
    corresponding `reports/{reportId}` Firestore document, enforced via a
    `firestore.get()` check inside the storage rule.
  - Max file size: 5 MB (reject larger uploads at the rule level, not just
    client-side).
  - Allowed content type: image/* only.

users/{userId}/profile.jpg:
  - Read: any authenticated user (profile photos are not sensitive here).
  - Write: only if `request.auth.uid == userId`.
  - Max file size: 5 MB, image/* only.
```

---

## Database Rules

All rules below are enforced **server-side, inside a Cloud Function**
(`onReportCreated`, triggered on `reports/{reportId}` create), using the
Admin SDK. The client only ever writes a raw report with the limited field
set defined in "Firestore Rules" — it cannot bypass any of this by calling
the Firestore API directly, since the trusted logic runs on report
creation regardless of which client (or non-client) created it.

- **Duplicate / spam prevention (server-enforced):** the function checks if
  the same `UserId` already has a report for the same `LocationId` +
  `Category` created within the last **5 minutes**. If so, it deletes the
  just-created report (or marks it rejected) and does not touch any
  incident. Because this check runs in the function, not the client, it
  cannot be bypassed by calling the Firestore SDK/REST API directly — this
  closes the spam gap the client-only check had.
  (Earlier drafts used `UserId + LocationId + Category + CreatedAt` as a
  uniqueness key — that's a no-op, since `CreatedAt` is a high-precision
  timestamp that's effectively always unique. The 5-minute window above is
  the actual rule.)
- Never delete existing report data (the spam-rejection case above is the
  one narrow exception, and only for reports the function itself just
  rejected within the same invocation).
- **Atomicity:** the function looks up or creates the matching incident and
  writes the report's `IncidentId`/`Status` inside a single Firestore
  `runTransaction` on the server. Because the Cloud Function is the only
  writer of `incidents`, there's no client-vs-client race to account for —
  only concurrent function invocations, which the transaction still
  protects against.
- Look up an active incident for the same `LocationId` + `Category` within
  the last 24 hours.
  - If found: increment `ReportCount`, update `LastUpdatedAt`, recompute
    `Severity` (see "Severity Scoring" — `ReportCount × CategoryUrgencyWeight`,
    NOT `ReportCount` alone), set `report.IncidentId` + `report.Status`.
  - If not found: create a new incident (`ReportCount = 1`, `Severity`
    computed the same way, `Status = "Active"`), set `report.IncidentId` +
    `report.Status = "Active"`.
- **Auto-resolve (reliable, server-side):** a **Cloud Scheduled Function**
  runs hourly (independent of whether any user has the app open), finds
  incidents where `LastUpdatedAt < now - 24 hours`, and resolves them. Each
  incident's report batch-update uses Firestore `WriteBatch`, chunked into
  groups of ≤500 (Firestore's per-batch limit) so an incident with many
  linked reports still resolves atomically per chunk instead of silently
  failing past the limit. This replaces the earlier "checked on app open"
  approach, which depended on a random user's device and phone connectivity
  to run consistency-critical work — the scheduled function runs regardless
  of client activity.
- **Report ↔ Incident status relationship:** an individual `Report.Status`
  is never set by the user. It mirrors its parent incident's status: a
  report is `Active` while its `IncidentId` points to an `Active` incident,
  and flips to `Resolved` the moment that incident resolves (as part of the
  same scheduled-function batch above).
- Locations are pre-seeded for MVP. No user-created locations in version 1.

---

## App Features

### 1. Authentication

- Register with email and password.
- Login with email and password.
- Login with Google Sign-In.
- Auto-login if session is still valid.
- Logout.
- Store user profile in Firestore `users` collection after first login.

### 2. Campus Map

- Display a map of campus with markers for each location.
- Each marker shows the current severity:
  - 🟢 Normal (no active incident)
  - 🟡 Warning (score 1-2, see "Severity Scoring")
  - 🔴 Critical (score 3+, see "Severity Scoring" — can trigger from a single report of a high-weight category)
- Tap a marker to navigate to Location Detail.
- Map uses OpenStreetMap via `flutter_map` (free, no API key required).
- Campus coordinates and zoom level are pre-configured.

### 3. Live Campus Status

- List view alternative to the map.
- Show all locations grouped by building.
- Each location shows:
  - Location name
  - Active incident categories with severity badges
  - Total active reports
- Pull-to-refresh to update data.
- Real-time updates via Firestore snapshot listener.

### 4. Location Detail

- Show location information (building, floor).
- List all active incidents at this location.
- Each incident shows:
  - Category icon and name
  - Severity badge (🟢🟡🔴)
  - Report count
  - Time since first reported
  - Time since last updated
- Button: "Laporkan Masalah" to create a new report for this location.

### 5. Incident Detail

- Show incident information:
  - Location name
  - Category
  - Status badge
  - Severity badge
  - Total report count
  - First reported time
  - Last updated time
- List of related reports:
  - Reporter name
  - Description
  - Photo (if available)
  - Time of report
- Button: "Saya Juga Mengalami Ini" → creates a quick report with the same location and category.

### 6. Create Report

- Form fields:
  - Location (dropdown or search, pre-filled if navigated from Location Detail)
  - Category (dropdown with icons)
  - Description (text area, required, min 10 characters)
  - Photo (camera or gallery, optional)
- Validation:
  - Location is required.
  - Category is required.
  - Description is required and minimum 10 characters.
- On submit:
  - Upload photo to Firebase Cloud Storage if provided.
  - Create report document in Firestore with client-writable fields only
    (see "Firestore Rules" — client does NOT set `IncidentId` or `Status`).
  - The `onReportCreated` Cloud Function takes over from here: duplicate
    check, incident lookup/creation, severity scoring, and writing back
    `report.IncidentId` + `report.Status` (see "Database Rules"). The client
    does not perform any of this itself.
  - UI listens for the report document's `IncidentId` field to populate
    (via Firestore snapshot listener) before navigating, so the confirmation
    screen can show the resolved incident state rather than guessing it.
  - Navigate to Report Confirmation screen once `IncidentId` is set (or after
    a short timeout, showing "diproses" state if the function is still running).

### 7. Report Confirmation

- Show success message: "Laporan berhasil dibuat"
- Show report summary:
  - Location
  - Category
  - Description preview
  - Incident status (new or updated existing incident)
- Buttons:
  - "Lihat Incident" → navigate to Incident Detail
  - "Kembali ke Beranda" → navigate to Home

### 8. My Reports (Report History)

- List all reports created by the current user.
- Each report shows:
  - Report ID (short)
  - Category icon and name
  - Location name
  - Status badge (Active / Resolved)
  - Created time
- Sort by most recent first.
- Tap to view report detail.
- Empty state: "Belum ada laporan. Laporkan masalah pertama Anda!"

### 9. Search & Filter

- Search bar to search by location name or building name.
- Filter chips:
  - By category (Wifi, AC, Printer, etc.)
  - By status (Active, Resolved)
  - By severity (Normal, Warning, Critical)
- Results show matching incidents.
- Clear filters button.

---

## Screen List

```text
1.  Splash Screen           → Logo, loading, auth check
2.  Login Screen            → Email/password + Google Sign-In
3.  Register Screen         → Email, password, name
4.  Home Screen             → Campus Map + bottom navigation
5.  Live Status Screen      → List view of campus status
6.  Location Detail Screen  → Facility status at a location
7.  Incident Detail Screen  → Detail of a single incident
8.  Create Report Screen    → Form to submit a new report
9.  Report Confirmation     → Success confirmation
10. My Reports Screen       → Report history
11. Search Screen           → Search and filter incidents
12. Profile Screen          → User profile and logout
```

---

## Navigation

```text
Bottom Navigation Bar (4 tabs):

┌─────────┬──────────┬──────────┬─────────┐
│  Peta   │  Status  │ Laporan  │  Profil │
│  (Map)  │  (Live)  │  (Saya)  │         │
└─────────┴──────────┴──────────┴─────────┘

Tab 1: Peta       → Home Screen (Campus Map)
Tab 2: Status     → Live Status Screen
Tab 3: Laporan    → My Reports Screen
Tab 4: Profil     → Profile Screen

Floating Action Button (FAB):
  → Create Report Screen (accessible from any tab)
```

---

## UI Requirements

- Use Indonesian language for all labels, buttons, messages, and validation.
- Implement a clean, modern mobile UI.
- Use a dark theme as primary with ghost-inspired accent colors.
- Color palette:
  - Primary: Deep purple / dark blue (#1a1a2e or similar)
  - Accent: Ghost white / cyan (#e0e0ff or similar)
  - Severity green: #4caf50
  - Severity yellow/orange: #ff9800
  - Severity red: #f44336
- Use Material Design 3 components.
- Use Google Fonts (Inter or Poppins).
- Use status badge colors:
  - Normal / Active: green
  - Warning / Stale: orange
  - Critical / No Data: red
- Add subtle animations:
  - Page transitions
  - Loading shimmer effects
  - Severity badge pulse animation for Critical status
- Show empty states with illustration and message for all list screens.
- Show loading indicators during Firestore operations.
- Show error snackbar for failed operations.
- Use confirmation dialog before any destructive action.
- Responsive layout for various phone screen sizes.
- Do not add charts in the first version.

---

## Folder Structure

Project root now has two deployable units: the Flutter app (`lib/`) and the
Cloud Functions backend (`functions/`), since business logic moved server-side.

```text
functions/
├── src/
│   ├── index.ts                  (exports all functions)
│   ├── onReportCreated.ts        (incident grouping + severity scoring)
│   ├── resolveStaleIncidents.ts  (scheduled, hourly)
│   ├── severityScoring.ts        (CategoryUrgencyWeight table + formula)
│   └── config.ts
├── package.json
└── tsconfig.json

lib/
├── main.dart
├── app.dart
│
├── config/
│   ├── theme.dart
│   ├── routes.dart
│   ├── constants.dart
│   └── firebase_options.dart
│
├── models/
│   ├── user_model.dart
│   ├── location_model.dart
│   ├── report_model.dart
│   └── incident_model.dart
│
├── enums/
│   ├── report_category.dart
│   ├── report_status.dart
│   ├── incident_status.dart
│   └── facility_severity.dart
│
├── providers/
│   ├── auth_provider.dart
│   ├── location_provider.dart
│   ├── report_provider.dart
│   ├── incident_provider.dart
│   └── user_provider.dart
│
├── repositories/
│   ├── auth_repository.dart
│   ├── location_repository.dart
│   ├── report_repository.dart
│   ├── incident_repository.dart
│   └── storage_repository.dart
│
├── screens/
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── widgets/
│   │       ├── campus_map.dart
│   │       └── map_marker.dart
│   ├── live_status/
│   │   ├── live_status_screen.dart
│   │   └── widgets/
│   │       ├── building_card.dart
│   │       └── facility_status_tile.dart
│   ├── location_detail/
│   │   ├── location_detail_screen.dart
│   │   └── widgets/
│   │       └── incident_card.dart
│   ├── incident_detail/
│   │   ├── incident_detail_screen.dart
│   │   └── widgets/
│   │       └── report_tile.dart
│   ├── report/
│   │   ├── create_report_screen.dart
│   │   ├── report_confirmation_screen.dart
│   │   └── widgets/
│   │       ├── category_selector.dart
│   │       └── photo_picker.dart
│   ├── my_reports/
│   │   ├── my_reports_screen.dart
│   │   └── widgets/
│   │       └── report_history_tile.dart
│   ├── search/
│   │   ├── search_screen.dart
│   │   └── widgets/
│   │       └── filter_chips.dart
│   └── profile/
│       └── profile_screen.dart
│
├── widgets/
│   ├── severity_badge.dart
│   ├── status_badge.dart
│   ├── category_icon.dart
│   ├── loading_shimmer.dart
│   ├── empty_state.dart
│   ├── error_snackbar.dart
│   └── confirm_dialog.dart
│
└── utils/
    ├── date_formatter.dart
    ├── validators.dart
    └── firestore_helpers.dart
```

---

## State Management — Riverpod

### Provider Architecture

```text
UI (Widgets)
    │
    ▼
Providers (Riverpod)
    │
    ├── StateNotifierProvider  → Manage complex state
    ├── StreamProvider         → Real-time Firestore listeners
    └── FutureProvider         → One-time async operations
    │
    ▼
Repositories
    │
    ▼
Firebase Services (Firestore, Auth, Storage)
```

### Key Providers

```text
authStateProvider         → Stream<User?> from Firebase Auth
currentUserProvider       → User profile from Firestore
locationsProvider         → Stream<List<Location>> all locations
locationDetailProvider    → Stream<Location> single location
incidentsProvider         → Stream<List<Incident>> all active incidents
locationIncidentsProvider → Stream<List<Incident>> incidents at a location
incidentDetailProvider    → Stream<Incident> single incident
incidentReportsProvider   → Stream<List<Report>> reports for an incident
userReportsProvider       → Stream<List<Report>> current user reports
searchResultsProvider     → Filtered incidents based on query
```

---

## Incident Grouping Logic (Cloud Function: `onReportCreated`)

This entire flow runs server-side, triggered automatically whenever a
`reports/{reportId}` document is created — by the app or by anyone calling
Firestore directly, since the trigger doesn't care who wrote it. Steps 1-3
run inside a single Firestore `runTransaction` on the server so concurrent
function invocations (e.g. two reports landing at nearly the same instant)
don't lose an increment.

```text
onReportCreated(report):

0. Duplicate/spam check (server-side, cannot be bypassed by calling the
   Firestore API directly): if this UserId already has another report for
   the same LocationId + Category created within the last 5 minutes,
   delete this report and stop — no incident is touched.

1. [inside a transaction] Query for existing incident where:
   - LocationId == report.LocationId
   - Category == report.Category
   - Status == "Active"
   - LastUpdatedAt > (now - 24 hours)

2. If found:
   - Increment ReportCount by exactly 1
   - Update LastUpdatedAt to now
   - weight = CategoryUrgencyWeight(report.Category)  // see "Severity Scoring"
   - score = ReportCount * weight
   - Severity = score >= 3 ? "Critical" : "Warning"
   - Set report.IncidentId = incident.Id
   - Set report.Status = "Active"

3. If not found:
   - weight = CategoryUrgencyWeight(report.Category)
   - Severity = weight >= 3 ? "Critical" : "Warning"   // 1 report already
                                                         // hits Critical for
                                                         // high-weight categories
   - Create new Incident:
     - LocationId = report.LocationId
     - Category = report.Category
     - ReportCount = 1
     - Status = "Active"
     - Severity = Severity (as computed above)
     - FirstReportedAt = now
     - LastUpdatedAt = now
   - Set report.IncidentId = newIncident.Id
   - Set report.Status = "Active"
```

```text
resolveStaleIncidents() — Cloud Scheduled Function, runs hourly:

1. Query incidents where Status == "Active" AND LastUpdatedAt < (now - 24h).
2. For each stale incident:
   - Set incident.Status = "Resolved"
   - Query all reports where IncidentId == incident.Id
   - Update their Status to "Resolved" using WriteBatch, chunked into
     groups of <= 500 (Firestore's per-batch limit), so large incidents
     still resolve atomically per chunk instead of hitting the limit
     mid-operation.
   - Runs independently of any user having the app open, so it can't be
     left stuck the way a client-triggered version could be.
```

---

## Firebase Cloud Storage Structure

```text
reports/
  └── {reportId}/
        └── photo.jpg

users/
  └── {userId}/
        └── profile.jpg
```

- Max photo size: 5 MB.
- Compress image before upload.
- Generate thumbnail if needed (future enhancement).

---

## Error Handling

| Scenario                                                          | Behavior                                                               |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------- |
| No internet connection                                            | Show offline banner. Use Firestore offline persistence.                |
| Firestore read fails                                              | Show error message with retry button.                                  |
| Photo upload fails                                                | Show error snackbar. Allow retry or skip photo.                        |
| Auth session expired                                              | Redirect to Login Screen.                                              |
| Duplicate report (same user, location, category within 5 minutes) — now rejected server-side by the Cloud Function, not just checked client-side | Show warning: "Anda baru saja melaporkan masalah ini." |
| Empty location list                                               | Show empty state: "Belum ada lokasi terdaftar."                        |
| Empty incident list                                               | Show empty state: "Tidak ada masalah yang dilaporkan. Kampus aman! 👻" |

---

## Pre-seeded Data (MVP)

For demonstration, seed the following locations in Firestore:

```text
Building: Gedung 1
  - Gedung 1 Lantai B
  - Gedung 1 Lantai GF
  - Gedung 1 Lantai 1
  - Gedung 1 Lantai 2
  - Gedung 1 Lantai 3

Building: Gedung 2
  - Gedung 2 Lantai B
  - Gedung 2 Lantai GF
  - Gedung 2 Lantai 1
  - Gedung 2 Lantai 2
  - Gedung 2 Lantai 3

Building: Perpustakaan
  - Perpustakaan Gedung 1 Lantai GF

Building: Kantin
  - Kantin (Basement)

Building: Parkiran (Basement)
  - Parkiran Motor
  - Parkiran Mobil
```

Each location should have latitude and longitude coordinates for the campus map.

---

## Deliverables

- Complete Flutter application source code.
- **Cloud Functions source code** (`functions/`): `onReportCreated`,
  `resolveStaleIncidents`, and the severity-scoring module, deployable via
  `firebase deploy --only functions`.
- Firebase configuration files.
- Firestore security rules (client has no direct write access to `incidents`
  — see "Firestore Rules").
- Pre-seeded location data (Firestore seed script or manual setup guide).
- `README.md` with:
  - Installation steps
  - Firebase setup guide, **including enabling the Blaze plan and deploying
    Cloud Functions** (functions won't run on the free Spark plan)
  - How to run the application
  - How to seed data
  - Project structure overview
- Architecture.md (this document).
- Ensure the application builds successfully and Cloud Functions deploy
  without errors.
- All basic features working: authentication, campus map, live status,
  create report (server-processed), incident grouping, report history,
  search and filter.

---

## Out of Scope (Version 1)

- Admin dashboard for campus management.
- Push notifications.
- AI-based incident detection.
- IoT sensor integration.
- SSO campus integration.
- Gamification (badges, points, leaderboard).
- Chat or discussion within incidents.
- Multi-campus support.
- Offline report queue (reports require internet).
