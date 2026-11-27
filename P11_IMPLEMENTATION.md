# P11 Implementation Guide - Campus Ghost

## 📋 Overview

Dokumen ini menjelaskan implementasi Pertemuan 11 (P11) untuk Campus Ghost, yang mencakup:
1. ✅ Pembuatan minimal 10 issues (5 bugs + 5 features) di GitHub/JIRA
2. ✅ Setup branch structure: v1.0, v1.0_dev, v1.1
3. ✅ Testing workflow dengan minimum 200 UT
4. ✅ CI/CD pipeline dengan GitHub Actions
5. 📸 Screenshot requirements untuk progress tracking

---

## ✅ Completed: Issue Tracking Setup

### Issues Created: 12 Total (6 Bugs + 6 Features)

#### 🐛 Bug Issues (6)
1. **BUG-001:** Login Screen Demo Account Selector Not Working (High Priority)
2. **BUG-002:** Unused Import Warnings (Low Priority) - ✅ FIXED
3. **BUG-003:** Report Photo Size Limit Not Enforced (Medium Priority)
4. **BUG-004:** Incident Grouping Logic Runs Client-Side (High Priority - Security)
5. **BUG-005:** No Offline Mode Support (Medium Priority)
6. **BUG-006:** GPS Permission Handling Not User-Friendly (Medium Priority)

#### ✨ Feature Issues (6)
1. **FEATURE-001:** Push Notifications untuk Status Updates (High Priority)
2. **FEATURE-002:** Report History with Statistics (Medium Priority)
3. **FEATURE-003:** Admin Dashboard untuk Campus Management (High Priority)
4. **FEATURE-004:** Photo Gallery and Evidence Comparison (Medium Priority)
5. **FEATURE-005:** Interactive Campus Map dengan Real-time Heatmap (High Priority)
6. **FEATURE-006:** Social Features - Confirmation and Comments (Medium Priority)

### Documentation
- ✅ Comprehensive ISSUES.md created
- ✅ GitHub issue templates (Bug Report, Feature Request)
- ✅ Issue priority and estimation included
- ✅ Acceptance criteria defined for each feature

---

## ✅ Completed: Branch Strategy

### Branch Structure
```
main (v1.0)              <- Production release, stable
  │
  ├── v1.0_dev           <- Bug fixes and improvements
  │    ├── bug/BUG-001  <- Individual bug fix branches
  │    ├── bug/BUG-003
  │    └── ...
  │
  └── v1.1               <- Feature development
       ├── feature/FEATURE-001
       ├── feature/FEATURE-002
       └── ...
```

### Current Branch Status

#### ✅ main (v1.0)
- **Status:** Release OK - Production Ready
- **Tests:** 93 passed (1 known failure - BUG-001)
- **Tag:** v1.0
- **Commit:** 5e97b45

#### 🚧 v1.0_dev
- **Status:** Under Development - Bug Fixes
- **Purpose:** Fixing BUG-001 through BUG-006
- **Tests Required:** All 93+ tests must pass
- **Target:** Merge to main after verification

#### 📋 v1.1
- **Status:** Planned - Feature Development
- **Purpose:** Implementing FEATURE-001 through FEATURE-006
- **Tests Required:** New tests for new features
- **Target:** Next major release

---

## 📊 Testing Status

### Current Test Results (v1.0)
```bash
$ flutter test

Total Tests: 93
✅ Passed: 92
❌ Failed: 1 (BUG-001 - known issue)

Test Duration: ~20 seconds
```

### Test Breakdown by Category
```
Report Operations       : 28 tests ✅
Authentication          : 12 tests ✅
Notifications          : 8 tests  ✅
Theme Persistence      : 6 tests  ✅
Admin Workflows        : 15 tests ✅
Technician Workflows   : 18 tests ✅
Protected Routes       : 5 tests  ✅
Login Screen UI        : 1 test  ❌ (BUG-001)
```

### Flutter Analyze Results
```bash
$ flutter analyze

✅ No errors
⚠️  3 warnings (unused imports - non-breaking)
```

---

## 🔄 CI/CD Pipeline Setup

### ✅ GitHub Actions Workflow Created

File: `.github/workflows/flutter_ci.yml`

#### Pipeline Stages:

**1. Test Stage** (Runs on all branches)
- Checkout code
- Setup Flutter
- Get dependencies
- Run flutter analyze
- Run all tests with coverage
- Upload coverage to Codecov

**2. Build Stage** (Runs on main and v1.0_dev)
- Build Android APK
- Upload artifact

#### Trigger Events:
- Push to: main, v1.0_dev, v1.1
- Pull requests to: main, v1.0_dev, v1.1

---

## 📸 Screenshot Requirements for P11

### For Each Issue Fixed/Implemented:

#### 1. Before State
- Screenshot showing the bug/missing feature
- Test output showing failure (if applicable)

#### 2. After State
- Screenshot showing the fix/feature
- Test output showing success

#### 3. Test Evidence
```bash
# Example for BUG-002 (Fixed)
Before:
$ flutter analyze
⚠️  3 warnings (unused imports)

After:
$ flutter analyze
✅ No warnings
```

### Directory Structure for Screenshots:
```
docs/
  screenshots/
    p11/
      bugs/
        BUG-001-before.png
        BUG-001-after.png
        BUG-001-tests.png
      features/
        FEATURE-001-mockup.png
        FEATURE-001-implementation.png
        FEATURE-001-tests.png
```

---

## 🎯 P11 Implementation Workflow

### Phase 1: Bug Fixes (v1.0_dev) - Week 1-2

#### Priority Order:
1. ✅ **BUG-002** (Completed) - Remove unused imports
2. 🔨 **BUG-001** (In Progress) - Fix login screen tap issue
3. 🔨 **BUG-004** (Critical) - Move incident grouping to server
4. 🔨 **BUG-003** - Implement photo size validation
5. 🔨 **BUG-006** - Improve GPS permission UX

#### Process for Each Bug:
```bash
# 1. Create bug fix branch
git checkout v1.0_dev
git checkout -b bug/BUG-XXX

# 2. Fix the bug
# ... code changes ...

# 3. Add/update tests
# ... test code ...

# 4. Run tests locally
flutter test

# 5. Take screenshots
# - Before state
# - After state
# - Test results

# 6. Commit with detailed message
git add -A
git commit -m "fix(component): description of fix

Closes #BUG-XXX

Changes:
- Detail 1
- Detail 2

Tests:
- Added/Updated test for scenario
- All 93+ tests passing

Screenshots in docs/screenshots/p11/bugs/"

# 7. Push and create PR
git push origin bug/BUG-XXX

# 8. After review, merge to v1.0_dev
# 9. Test v1.0_dev thoroughly
# 10. Merge v1.0_dev to main
```

### Phase 2: Feature Development (v1.1) - Week 3-6

#### Priority Order:
1. 🚧 **FEATURE-001** - Push Notifications (High)
2. 🚧 **FEATURE-005** - Interactive Map (High)
3. 🚧 **FEATURE-003** - Admin Dashboard (High)
4. 📋 **FEATURE-002** - Report Statistics (Medium)
5. 📋 **FEATURE-006** - Social Features (Medium)
6. 📋 **FEATURE-004** - Photo Gallery (Medium)

#### Process for Each Feature:
```bash
# 1. Create feature branch
git checkout v1.1
git checkout -b feature/FEATURE-XXX

# 2. Implement feature (TDD approach)
# - Write tests first
# - Implement feature
# - Refactor

# 3. Run all tests
flutter test

# 4. Document with screenshots
# - Mockup/design
# - Implementation
# - Test results

# 5. Commit
git add -A
git commit -m "feat(component): description

Implements #FEATURE-XXX

Features:
- Detail 1
- Detail 2

Tests:
- Added X new tests
- All 93+ tests passing

Documentation:
- Updated README.md
- Added screenshots"

# 6. Push and create PR
git push origin feature/FEATURE-XXX

# 7. Merge to v1.1 after review
# 8. When v1.1 is stable, merge to main
```

---

## 🧪 Testing Strategy for P11

### Unit Test Requirements:

#### Current Baseline: 93 tests
**Goal:** Maintain green status and add tests for new features

#### Test Categories to Maintain:
```
1. Report Repository (CRUD)
2. Authentication Flows
3. Notification System
4. Theme Persistence
5. Admin Workflows
6. Technician Workflows
7. Protected Routes
8. UI Components
```

#### New Tests for Bug Fixes:
- **BUG-001:** Add proper widget testing for demo account selector
- **BUG-003:** Add validation tests for photo size limits
- **BUG-004:** Add server-side incident grouping tests
- **BUG-005:** Add offline mode tests
- **BUG-006:** Add permission handling tests

#### New Tests for Features:
- **FEATURE-001:** Notification delivery tests (20+ tests)
- **FEATURE-002:** Statistics calculation tests (15+ tests)
- **FEATURE-003:** Admin operations tests (25+ tests)
- **FEATURE-004:** Photo gallery tests (10+ tests)
- **FEATURE-005:** Map interaction tests (20+ tests)
- **FEATURE-006:** Social features tests (15+ tests)

**Target:** 200+ total tests by end of P11

### Integration Testing:
- Manual testing on real Android device
- End-to-end user flows
- Performance testing with real data

---

## 📋 Documentation Requirements

### Files to Maintain:

#### ✅ Created/Updated:
- [x] ISSUES.md - Issue tracking
- [x] CHANGELOG.md - Version history
- [x] README.md - Project overview
- [x] P11_IMPLEMENTATION.md - This file
- [x] .github/ISSUE_TEMPLATE/bug_report.md
- [x] .github/ISSUE_TEMPLATE/feature_request.md
- [x] .github/workflows/flutter_ci.yml

#### To Update Per Change:
- [ ] CHANGELOG.md - Add entry for each fix/feature
- [ ] README.md - Update features list if needed
- [ ] Test documentation - Document new tests

---

## 🎯 Success Criteria for P11

### Checklist:

#### ✅ Issue Tracking (Complete)
- [x] Create 10+ issues (6 bugs + 6 features documented)
- [x] GitHub issue templates setup
- [x] Priority and estimation assigned
- [x] Acceptance criteria defined

#### ✅ Branch Strategy (Complete)
- [x] v1.0 tagged and stable
- [x] v1.0_dev created for bug fixes
- [x] v1.1 created for features
- [x] Branch workflow documented

#### 🚧 Testing (In Progress)
- [x] 93 tests baseline established
- [ ] Fix 1 failing test (BUG-001)
- [ ] Add tests for bug fixes
- [ ] Add tests for new features
- [ ] Target: 200+ total tests

#### ✅ CI/CD (Complete)
- [x] GitHub Actions workflow setup
- [x] Automated testing on push
- [x] Automated builds
- [x] Coverage reporting

#### 🚧 Documentation (In Progress)
- [x] ISSUES.md created
- [x] CHANGELOG.md created
- [x] P11_IMPLEMENTATION.md created
- [ ] Screenshot documentation for each issue
- [ ] Code comments for complex logic

#### 📋 Implementation (Planned)
- [ ] Fix high-priority bugs (BUG-001, BUG-004)
- [ ] Implement high-priority features
- [ ] All tests passing
- [ ] Deployment ready

---

## 📸 Screenshot Template

### For Bug Fixes:

#### Structure:
```
Bug: BUG-XXX - [Title]
Priority: [High/Medium/Low]
Status: [In Progress/Fixed]

BEFORE:
[Screenshot showing the bug]
Description: What was wrong

TEST BEFORE:
[Terminal output showing test failure]

CODE CHANGES:
File: lib/path/to/file.dart
Lines: XX-YY
Description: What was changed

AFTER:
[Screenshot showing the fix]
Description: How it's fixed

TEST AFTER:
[Terminal output showing test success]

Verification:
✅ All 93+ tests passing
✅ Flutter analyze clean
✅ Manual testing successful
```

### For Features:

#### Structure:
```
Feature: FEATURE-XXX - [Title]
Priority: [High/Medium/Low]
Status: [In Progress/Complete]

DESIGN/MOCKUP:
[Screenshot or ASCII art of planned UI]

IMPLEMENTATION:
[Screenshot of actual implementation]

TESTS:
[Terminal output showing new tests]
X new tests added
All tests passing

DOCUMENTATION:
- README.md updated: Yes/No
- Code documented: Yes/No
- User guide created: Yes/No
```

---

## 🚀 Deployment Process

### From v1.0_dev to main (Bug Fixes):
```bash
# 1. Ensure all tests pass on v1.0_dev
git checkout v1.0_dev
flutter test
flutter analyze

# 2. Update CHANGELOG.md
# Document all bug fixes

# 3. Create PR from v1.0_dev to main
# Title: "Release v1.0.1 - Bug Fixes"

# 4. After review, merge to main
git checkout main
git merge v1.0_dev

# 5. Tag new version
git tag -a v1.0.1 -m "Bug fix release"

# 6. Push to origin
git push origin main --tags
```

### From v1.1 to main (Feature Release):
```bash
# 1. Ensure all tests pass on v1.1
git checkout v1.1
flutter test # Should have 200+ tests
flutter analyze

# 2. Update CHANGELOG.md
# Document all new features

# 3. Create PR from v1.1 to main
# Title: "Release v1.1.0 - Feature Updates"

# 4. After thorough testing, merge to main
git checkout main
git merge v1.1

# 5. Tag new version
git tag -a v1.1.0 -m "Feature release"

# 6. Push to origin
git push origin main --tags
```

---

## 📊 Progress Tracking

### Week-by-Week Goals:

#### Week 1: Issue Setup (✅ Complete)
- [x] Create ISSUES.md with 10+ issues
- [x] Setup GitHub templates
- [x] Create branch structure
- [x] Setup CI/CD pipeline
- [x] Tag v1.0

#### Week 2: High-Priority Bug Fixes
- [ ] Fix BUG-001 (Login screen)
- [ ] Fix BUG-004 (Server-side grouping)
- [ ] Update tests
- [ ] Screenshots documented

#### Week 3-4: Medium-Priority Bugs + Feature Planning
- [ ] Fix BUG-003, BUG-005, BUG-006
- [ ] Design FEATURE-001, FEATURE-005
- [ ] Update documentation

#### Week 5-6: Feature Implementation
- [ ] Implement FEATURE-001 (Notifications)
- [ ] Implement FEATURE-005 (Map)
- [ ] Add comprehensive tests
- [ ] Reach 200+ tests

#### Week 7: Integration & Testing
- [ ] Integration testing
- [ ] Performance testing
- [ ] Documentation finalization
- [ ] Prepare for v1.1 release

---

## 🔗 Related Resources

### Documentation:
- [ISSUES.md](ISSUES.md) - Complete issue tracking
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [README.md](README.md) - Project overview
- [DEMO_SCRIPT.md](DEMO_SCRIPT.md) - Demo flow

### GitHub:
- Issue Templates: `.github/ISSUE_TEMPLATE/`
- CI/CD Workflow: `.github/workflows/flutter_ci.yml`
- Repository: [Your GitHub URL]

### Testing:
- Test Directory: `test/`
- Coverage Report: Generated by CI/CD

---

## ✅ P11 Completion Checklist

### Setup (Complete):
- [x] 10+ issues created and documented
- [x] GitHub/JIRA integration ready
- [x] Branch strategy implemented
- [x] CI/CD pipeline active
- [x] Testing baseline established (93 tests)

### In Progress:
- [ ] Bug fixes implemented
- [ ] Features developed
- [ ] 200+ tests achieved
- [ ] Screenshots documented
- [ ] Code reviewed and merged

### Documentation:
- [x] ISSUES.md created
- [x] CHANGELOG.md created
- [x] P11_IMPLEMENTATION.md created
- [ ] Screenshots organized
- [ ] User guide updated

---

**Status:** ✅ P11 Setup Complete - Ready for Implementation  
**Last Updated:** 2024-12-XX  
**Next Steps:** Begin bug fixes on v1.0_dev branch
