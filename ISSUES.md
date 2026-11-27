# Campus Ghost - Issues & Bug Tracking

**Project:** Campus Ghost v1.0  
**Date Created:** 2024  
**Total Issues:** 12 (6 Bugs + 6 Features)

---

## 🐛 BUG ISSUES

### BUG-001: Login Screen Demo Account Selector Not Working
**Priority:** High  
**Status:** Open  
**Component:** Authentication / UI  
**Affected Version:** v1.0

**Description:**  
Demo account selector buttons pada LoginScreen tidak dapat di-tap dengan benar. Test menunjukkan widget ada tetapi offset-nya tidak hit test dengan benar, menyebabkan user tidak bisa quick login dengan demo accounts.

**Steps to Reproduce:**
1. Buka aplikasi
2. Pada LoginScreen, coba tap tombol "Administrator", "Teknisi GA", atau "Mahasiswa"
3. Widget tidak merespon tap

**Expected Behavior:**  
Tombol demo account harus mengisi email field dan auto-login user dengan role yang sesuai.

**Actual Behavior:**  
Widget off-screen atau obscured oleh widget lain, sehingga tap tidak berfungsi.

**Technical Details:**
```
Error: Offset (776.6, 1136.5) would not hit test on the specified widget
Test: role_login_routing_test.dart line 50
```

**Suggested Fix:**
- Periksa ScrollController dan ensure widget visible di viewport
- Gunakan `tester.ensureVisible()` sebelum tap
- Review layout hierarchy untuk overlap issues

---

### BUG-002: Unused Import Warnings in Multiple Files
**Priority:** Low  
**Status:** Open  
**Component:** Code Quality  
**Affected Version:** v1.0

**Description:**  
Beberapa file memiliki unused imports yang menyebabkan analyzer warnings:
- `lib/screens/splash/splash_screen.dart:6:8` - Unused import: `../../config/routes.dart`
- `test/role_login_routing_test.dart:1:8` - Unused import: `package:campus_ghost/config/routes.dart`
- `test/role_login_routing_test.dart:2:8` - Unused import: `package:campus_ghost/enums/user_role.dart`

**Expected Behavior:**  
No analyzer warnings, clean code with only necessary imports.

**Actual Behavior:**  
3 unused import warnings detected by flutter analyze.

**Suggested Fix:**
Remove unused imports from affected files.

---

### BUG-003: Report Photo Size Limit Not Enforced Consistently
**Priority:** Medium  
**Status:** Open  
**Component:** Report Creation  
**Affected Version:** v1.0

**Description:**  
Dokumentasi menyebutkan batas foto 1 MB per file dan 3 MB total per akun, tetapi tidak ada validasi konsisten di UI. User bisa upload foto besar dan menyebabkan storage issues.

**Expected Behavior:**
- Validasi ukuran foto sebelum upload
- Warning message jika foto terlalu besar
- Compress foto otomatis jika melebihi 1 MB

**Actual Behavior:**  
Tidak ada size enforcement yang jelas di UI layer.

**Impact:**
- Local storage bisa penuh
- Performance degradation dengan foto besar

**Suggested Fix:**
- Tambahkan image compression plugin (image_picker sudah support)
- Validasi di `_pickImage()` method
- Show error dialog jika file terlalu besar

---

### BUG-004: Incident Grouping Logic Runs on Client Side
**Priority:** High  
**Status:** Open  
**Component:** Architecture / Security  
**Affected Version:** v1.0

**Description:**  
README menyebutkan "Agregasi incident dan pencegahan duplikat berjalan di client", yang merupakan security risk. User bisa manipulasi data lokal karena tidak ada server-side validation.

**Security Implications:**
- Data integrity tidak terjamin
- Fake reports bisa dibuat
- Incident count bisa dimanipulasi

**Expected Behavior:**  
Incident grouping dan aggregation harus di server-side (Firebase Cloud Functions).

**Actual Behavior:**  
Client-side logic yang bisa dimanipulasi.

**Suggested Fix:**
- Migrate incident grouping logic ke Cloud Functions
- Add server-side validation untuk reports
- Implement report verification system

**Note:**  
Ini memerlukan Firebase Blaze plan untuk Cloud Functions.

---

### BUG-005: No Offline Mode Support
**Priority:** Medium  
**Status:** Open  
**Component:** Connectivity  
**Affected Version:** v1.0

**Description:**  
Aplikasi tidak memiliki proper offline mode. Ketika user tidak ada koneksi internet:
- Cannot view cached reports
- Cannot create reports offline
- No queue system untuk pending uploads

**Expected Behavior:**
- Cached data tetap bisa diakses offline
- Reports bisa dibuat offline dan di-queue untuk upload
- Proper error messages untuk network failures

**Actual Behavior:**  
App likely crashes atau shows blank screens ketika offline.

**Suggested Fix:**
- Implement connectivity checker
- Add local cache layer dengan sqflite
- Queue system untuk pending operations
- Show offline indicator di UI

---

### BUG-006: GPS Permission Handling Not User-Friendly
**Priority:** Medium  
**Status:** Open  
**Component:** Location Services  
**Affected Version:** v1.0

**Description:**  
Ketika user menolak GPS permission, app menggunakan default coordinates tanpa clear explanation. User bisa bingung kenapa lokasi mereka tidak akurat.

**Expected Behavior:**
- Clear explanation dialog kenapa GPS permission dibutuhkan
- Option untuk retry permission request
- Visual indicator ketika menggunakan default location
- Link ke app settings untuk enable permission

**Actual Behavior:**  
Silent fallback ke default coordinates tanpa user awareness.

**User Impact:**
- Reports dengan lokasi tidak akurat
- User confusion tentang location accuracy

**Suggested Fix:**
- Improve permission request flow
- Add explanation dialog sebelum request permission
- Show warning badge ketika using default location
- Add "Enable GPS" button in report creation screen

---

## ✨ FEATURE REQUESTS

### FEATURE-001: Push Notifications untuk Status Updates
**Priority:** High  
**Type:** Enhancement  
**Status:** Open  
**Component:** Notifications

**Description:**  
User harus bisa receive push notifications ketika:
- Report mereka di-update (in progress, resolved)
- Incident baru muncul di lokasi favorit mereka
- Status fasilitas berubah

**Benefits:**
- Improved user engagement
- Real-time awareness of campus conditions
- Better user experience

**Technical Requirements:**
- Firebase Cloud Messaging (FCM)
- Notification preferences screen
- Background notification handling
- Deep linking ke incident/report detail

**Acceptance Criteria:**
- [ ] User receives notification when their report is updated
- [ ] User can enable/disable notification types
- [ ] Tapping notification opens relevant screen
- [ ] Notification works in background and foreground

**Estimated Effort:** 3-5 days

---

### FEATURE-002: Report History with Statistics
**Priority:** Medium  
**Type:** New Feature  
**Status:** Open  
**Component:** User Profile

**Description:**  
Enhanced report history screen dengan statistics dashboard untuk user:
- Total reports created
- Reports by status (active/resolved)
- Reports by category
- Timeline graph
- Impact score (berapa user lain yang confirm report mereka)

**Mockup Concept:**
```
My Report Statistics
━━━━━━━━━━━━━━━━━━
Total Reports: 27
Active: 3
Resolved: 24

Most Reported:
📶 WiFi (12)
❄️  AC (8)
🖨️  Printer (7)

Impact Score: 156
(156 users confirmed your reports)
```

**Acceptance Criteria:**
- [ ] Statistics dashboard implemented
- [ ] Charts/graphs for visualization
- [ ] Filter by date range
- [ ] Export history as PDF/CSV

**Estimated Effort:** 5-7 days

---

### FEATURE-003: Admin Dashboard untuk Campus Management
**Priority:** High  
**Type:** New Feature  
**Status:** Open  
**Component:** Admin Panel

**Description:**  
Web-based admin dashboard untuk pihak kampus untuk:
- Monitor semua reports real-time
- Assign technicians ke incidents
- Mark incidents as resolved
- View analytics & trends
- Manage locations/facilities
- Moderate false reports

**Key Features:**
1. Real-time incident monitoring
2. Technician assignment system
3. Analytics dashboard
4. Report moderation tools
5. User management
6. Export reports

**Technical Stack:**
- Flutter Web atau React Dashboard
- Firebase Admin SDK
- Cloud Functions untuk backend logic
- Charts/visualization library

**Acceptance Criteria:**
- [ ] Admin can view all reports
- [ ] Admin can assign technicians
- [ ] Dashboard shows real-time statistics
- [ ] Admin can moderate/delete reports
- [ ] Export functionality works

**Estimated Effort:** 10-15 days

---

### FEATURE-004: Photo Gallery and Evidence Comparison
**Priority:** Medium  
**Type:** Enhancement  
**Status:** Open  
**Component:** Reports

**Description:**  
Enhanced photo handling untuk reports:
- Multiple photos per report (not just 1)
- Before/After comparison untuk resolved incidents
- Photo gallery view di incident detail
- Zoom and pinch gestures
- Photo metadata (timestamp, location)

**Benefits:**
- Better evidence documentation
- Visual proof of resolution
- Improved incident understanding

**UI Enhancements:**
```
Report Detail
━━━━━━━━━━━━━━━━━━
[Photo Gallery] (3 photos)
[📷] [📷] [📷]
Tap to view full screen

Resolution Photos:
Before | After
[📷]   | [✓📷]
```

**Acceptance Criteria:**
- [ ] Support up to 5 photos per report
- [ ] Gallery view with swipe navigation
- [ ] Zoom and pan gestures
- [ ] Before/after comparison view
- [ ] Photo compression optimization

**Estimated Effort:** 4-6 days

---

### FEATURE-005: Interactive Campus Map dengan Real-time Heatmap
**Priority:** High  
**Type:** Enhancement  
**Status:** Open  
**Component:** Map/Visualization

**Description:**  
Upgrade static map menjadi interactive map dengan real-time heatmap visualization:
- Google Maps atau Flutter Map integration
- Color-coded heatmap berdasarkan incident density
- Tap on building untuk lihat facility status
- Filter by category on map
- Current location indicator
- Route suggestions untuk avoid problem areas

**Heatmap Concept:**
```
🟢 Green   = No issues
🟡 Yellow  = Minor issues (1-3 reports)
🟠 Orange  = Moderate issues (4-10 reports)
🔴 Red     = Critical issues (10+ reports)
```

**Features:**
1. Real-time map updates
2. Incident markers with clustering
3. Building outline polygons
4. Legend and filter controls
5. Navigation integration

**Technical Requirements:**
- google_maps_flutter or flutter_map
- Firestore real-time listeners
- Custom map markers
- Performance optimization untuk banyak markers

**Acceptance Criteria:**
- [ ] Interactive map implemented
- [ ] Heatmap visualization works
- [ ] Real-time updates without lag
- [ ] Filter controls functional
- [ ] Current location shown

**Estimated Effort:** 7-10 days

---

### FEATURE-006: Social Features - Report Confirmation and Comments
**Priority:** Medium  
**Type:** New Feature  
**Status:** Open  
**Component:** Social/Community

**Description:**  
Add social layer untuk increase report reliability:
- User bisa "confirm" reports (upvote)
- Comment system untuk additional info
- Report credibility score
- User reputation system
- Follow incidents untuk updates

**Features:**
1. **Confirmation System**
   - "I have this problem too" button
   - Confirmation count displayed
   - Increase incident priority based on confirmations

2. **Comments**
   - Add comments to reports
   - Reply to comments
   - Timestamp and user info
   - Moderation untuk spam

3. **Reputation**
   - User trust score
   - Badges untuk active reporters
   - Verified reporter status

**UI Mockup:**
```
Report Detail
━━━━━━━━━━━━━━━━━━
WiFi Not Working
📍 Gedung 1 Lt. 3

✓ 23 confirmations
💬 5 comments

[✓ Confirm This]  [💬 Add Comment]

Comments:
─────────────
👤 User A (2m ago)
   "Same issue here, been down since 9 AM"
   
👤 User B (5m ago)
   "Affecting the whole floor"
```

**Acceptance Criteria:**
- [ ] Confirmation system implemented
- [ ] Comments can be added/viewed
- [ ] Reputation system tracks user contributions
- [ ] Spam prevention in place
- [ ] Notifications for new comments

**Estimated Effort:** 6-8 days

---

## 📋 ISSUE SUMMARY

### By Priority
- **High:** 5 issues (3 bugs, 3 features)
- **Medium:** 5 issues (3 bugs, 2 features)
- **Low:** 1 issue (1 bug)

### By Type
- **Bugs:** 6 issues
- **Features:** 6 issues

### Total Estimated Effort
- **Bugs:** ~5-7 days (mostly architectural fixes)
- **Features:** ~35-50 days total

---

## 🔄 WORKFLOW & BRANCHING STRATEGY

### Branch Structure
```
main (v1.0)              <- Production release
  │
  ├── v1.0_dev           <- Development branch untuk bug fixes
  │    ├── bug/BUG-001
  │    ├── bug/BUG-002
  │    └── ...
  │
  └── v1.1               <- Next release dengan features
       ├── feature/FEATURE-001
       ├── feature/FEATURE-002
       └── ...
```

### Process Flow
1. **Bug Fix:** `bug/BUG-XXX` → `v1.0_dev` → test → merge to `main`
2. **Feature:** `feature/FEATURE-XXX` → `v1.1` → test → merge to `main`

### Testing Requirements
- All PRs must pass 93 unit tests (current baseline)
- New features must include new tests
- Coverage must not decrease

---

## 📸 TESTING & DOCUMENTATION REQUIREMENTS (P11)

### For Each Issue Fixed/Implemented:
1. **Screenshots:**
   - Before state (bug) atau without feature
   - After state (fixed/implemented)
   - Test results showing passed tests

2. **Unit Tests:**
   - Existing tests must pass (93/93 currently)
   - New tests for new features
   - Failed test demonstration untuk show debugging process

3. **Documentation:**
   - Update CHANGELOG.md
   - Update README.md if needed
   - Code comments untuk complex logic

### Branch Status Tracking:
```
v1.0 (main)        : ✅ Release OK - 93 tests passing
v1.0_dev           : 🚧 In Progress - Bug fixes under testing
v1.1               : 📋 Planned - Feature development
```

---

## 🎯 PRIORITY ROADMAP

### Phase 1 (v1.0_dev) - Bug Fixes
**Target:** 2 weeks
- [ ] BUG-001: Login screen tap issue (High)
- [ ] BUG-004: Move incident grouping to server (High)
- [ ] BUG-003: Photo size validation (Medium)
- [ ] BUG-006: GPS permission UX (Medium)
- [ ] BUG-002: Clean unused imports (Low)

### Phase 2 (v1.1) - Core Features
**Target:** 4-6 weeks
- [ ] FEATURE-001: Push notifications (High)
- [ ] FEATURE-005: Interactive map (High)
- [ ] FEATURE-003: Admin dashboard (High)

### Phase 3 (v1.2) - Enhancement Features
**Target:** 4 weeks
- [ ] FEATURE-002: Report statistics (Medium)
- [ ] FEATURE-006: Social features (Medium)
- [ ] FEATURE-004: Photo gallery (Medium)

---

## 📝 NOTES

**Testing Philosophy:**
- Write tests first (TDD) untuk new features
- Maintain green build status
- Document failed tests untuk learning

**Code Quality:**
- Follow Dart style guide
- Use flutter analyze before commit
- Peer review all PRs

**Communication:**
- Update issue status regularly
- Document decisions in issue comments
- Screenshots untuk visual changes

---

**Last Updated:** 2024
**Maintained By:** Campus Ghost Dev Team
