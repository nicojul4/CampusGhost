# Architecture — Campus Ghost 👻

Build a mobile application named **Campus Ghost**.

## Purpose

Help students monitor and report real-time facility conditions on campus. The application collects issue reports from students, groups them into incidents by location and category, and displays a live campus condition map. Dashboard reads reports from Firestore. Data synchronization happens in real-time via Firestore listeners.

## Stack

- Framework: Flutter (Dart)
- Backend: Firebase
- Database: Cloud Firestore
- Authentication: Firebase Auth (Email/Password + Google Sign-In)
- Storage: Firebase Cloud Storage
- State Management: Riverpod
- Maps: flutter_map + OpenStreetMap (or google_maps_flutter)
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
| IncidentId  | String?   | ID incident yang terkait (nullable, diisi saat dikelompokkan) |
| CreatedAt   | Timestamp | Waktu laporan dibuat                                          |
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

---

## Enums

### ReportCategory

```text
Wifi
Ac
Printer
Proyektor
Lift
Parkir
Toilet
Lainnya
```

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

```text
Normal      → 🟢 Tidak ada laporan aktif
Warning     → 🟡 1-2 laporan aktif
Critical    → 🔴 3+ laporan aktif
```

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
  - Authenticated user can create report (UserId must match auth UID).
  - Only the report owner can update their own report.
  - Reports cannot be deleted (data integrity).

incidents:
  - All authenticated users can read.
  - Incidents are created and updated via application logic (Cloud Functions or client-side).
  - Users cannot directly delete incidents.
```

---

## Database Rules

- A Report is unique by combination of `UserId`, `LocationId`, `Category`, and `CreatedAt` (prevent exact duplicate submissions).
- Never delete existing report data.
- When a new report is created, check if an active incident exists for the same `LocationId` + `Category` within the last 24 hours.
- If an active incident exists, increment `ReportCount` and update `LastUpdatedAt`.
- If no active incident exists, create a new incident.
- Update incident `Severity` based on `ReportCount`:
  - 1-2 reports → `Warning`
  - 3+ reports → `Critical`
- An incident is automatically marked `Resolved` if no new reports are added within 24 hours (handled by app logic or scheduled function).
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
  - 🟡 Warning (1-2 reports)
  - 🔴 Critical (3+ reports)
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
  - Create report document in Firestore.
  - Check for existing active incident (same LocationId + Category + within 24 hours).
  - If found, update incident (increment ReportCount, update LastUpdatedAt, recalculate Severity).
  - If not found, create new incident.
  - Navigate to Report Confirmation screen.

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

```text
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

## Incident Grouping Logic (MVP)

```text
When a new report is created:

1. Query Firestore for existing incident where:
   - LocationId == report.LocationId
   - Category == report.Category
   - Status == "Active"
   - LastUpdatedAt > (now - 24 hours)

2. If found:
   - Increment ReportCount
   - Update LastUpdatedAt to now
   - Recalculate Severity:
     - ReportCount 1-2 → "Warning"
     - ReportCount 3+  → "Critical"
   - Set report.IncidentId = incident.Id

3. If not found:
   - Create new Incident:
     - LocationId = report.LocationId
     - Category = report.Category
     - ReportCount = 1
     - Status = "Active"
     - Severity = "Warning"
     - FirstReportedAt = now
     - LastUpdatedAt = now
   - Set report.IncidentId = newIncident.Id

4. Auto-resolve logic (checked on app open or periodic):
   - If incident.LastUpdatedAt < (now - 24 hours):
     - Set incident.Status = "Resolved"
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
| Duplicate report (same user, location, category within 5 minutes) | Show warning: "Anda baru saja melaporkan masalah ini."                 |
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
- Firebase configuration files.
- Firestore security rules.
- Pre-seeded location data (Firestore seed script or manual setup guide).
- `README.md` with:
  - Installation steps
  - Firebase setup guide
  - How to run the application
  - How to seed data
  - Project structure overview
- Architecture.md (this document).
- Ensure the application builds successfully.
- All basic features working: authentication, campus map, live status, create report, incident grouping, report history, search and filter.

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
