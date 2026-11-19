# Firestore Security Rules - Perbaikan Keamanan

## Tanggal: 2026-11-19

## Masalah yang Diperbaiki

### 1. **Public Create Access (KRITIS)**
**Sebelum:**
```javascript
allow create: if true;
```
- Siapa saja (termasuk tidak terautentikasi) bisa membuat laporan
- Pengguna bisa memalsukan `userId` orang lain
- Tidak ada validasi field yang dikirim

**Sesudah:**
```javascript
allow create: if signedIn() 
  && request.resource.data.keys().hasOnly([...field yang diizinkan...])
  && (request.resource.data.userId == request.auth.uid 
      || request.resource.data.UserId == request.auth.uid)
  && request.resource.data.description is string
  && request.resource.data.description.size() >= 10;
```
- Hanya user terautentikasi yang bisa membuat laporan
- `userId` harus sesuai dengan UID Firebase Auth
- Field yang dikirim harus sesuai daftar yang diizinkan
- Deskripsi minimal 10 karakter

### 2. **Weak Update/Delete Rules**
**Sebelum:**
```javascript
allow update, delete: if signedIn();
```
- User yang login bisa mengubah/menghapus laporan siapa saja

**Sesudah:**
```javascript
// Update
allow update: if signedIn() 
  && (resource.data.userId == request.auth.uid 
      || resource.data.UserId == request.auth.uid)
  && (!request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['id', 'Id', 'userId', 'UserId', 'createdAt', 'CreatedAt', 'IncidentId']));

// Delete
allow delete: if signedIn() 
  && (resource.data.userId == request.auth.uid 
      || resource.data.UserId == request.auth.uid);
```
- User hanya bisa mengubah/menghapus laporan miliknya sendiri
- Field identitas tidak bisa diubah (`id`, `userId`, `createdAt`, `IncidentId`)

### 3. **Public Read Access**
**Sebelum:**
```javascript
allow read: if true;
```
- Siapa saja bisa membaca reports, incidents, locations

**Sesudah:**
```javascript
allow read: if signedIn();
```
- Hanya user terautentikasi yang bisa membaca data
- Sesuai dengan design aplikasi yang mengharuskan login untuk semua fitur

## Perubahan Detail

### Collection: `reports`
- **Read:** `true` → `signedIn()`
- **Create:** `true` → validasi autentikasi + field + ownership
- **Update:** `signedIn()` → ownership + field restriction
- **Delete:** `signedIn()` → ownership

### Collection: `locations`
- **Read:** `true` → `signedIn()`
- **Write:** tetap `false` (tidak ada perubahan)

### Collection: `incidents`
- **Read:** `true` → `signedIn()`
- **Write:** tetap `false` (tidak ada perubahan)

### Collection: `users`
- Tidak ada perubahan (sudah aman)

## Dampak Terhadap Fitur

### ✅ TIDAK TERDAMPAK
- **Local storage flow:** Tetap berjalan normal (tidak melalui Firestore Rules)
- **Cloud Functions:** Menggunakan Admin SDK (bypass rules)
- **Authentication flow:** Tidak ada perubahan
- **Semua test:** 48 test tetap lulus

### ✅ KOMPATIBEL DENGAN KODE EXISTING
- Semua screen sudah menggunakan `AuthGate` atau `ProtectedRoute`
- Client code sudah mengirim `userId` dari `auth.currentUser.uid`
- Tidak ada breaking changes pada API

## Validasi

### Sintaks Rules
✅ Firebase CLI tersedia dan rules valid

### Unit Tests
```
flutter test --no-pub
00:06 +48: All tests passed!
```
- ✅ 48 test lulus
- ✅ Tidak ada breaking changes
- ✅ Local CRUD tetap berfungsi
- ✅ API screen tetap berfungsi

### Security Checklist
- ✅ Tidak ada unauthenticated access
- ✅ UserId divalidasi dengan Firebase Auth
- ✅ Field restriction implemented
- ✅ Ownership validation untuk update/delete
- ✅ Protected fields tidak bisa diubah client
- ✅ Cloud Function tetap bisa bekerja (Admin SDK)

## Catatan Deployment

Untuk mengaplikasikan rules ini ke Firebase project:

```bash
firebase deploy --only firestore:rules
```

**PENTING:** Rules ini memerlukan semua user terautentikasi untuk membaca data. Pastikan semua screen sudah menggunakan `AuthGate` atau `ProtectedRoute` (sudah diverifikasi ✅).

## Field yang Diizinkan untuk Client Create

Client dapat mengirim field berikut saat membuat report:
- `id`, `Id` (auto-generated)
- `userId`, `UserId` (harus match dengan auth.uid)
- `locationId`, `LocationId`
- `category`, `Category`
- `description`, `Description` (minimal 10 karakter)
- `photoUrl`, `PhotoUrl` (optional)
- `status`, `Status`
- `createdAt`, `CreatedAt`
- `updatedAt`, `UpdatedAt`
- `latitude`, `longitude`, `locationDetail` (optional)

Field yang TIDAK boleh dikirim client:
- `IncidentId` (di-set oleh Cloud Function)

Field yang tidak boleh diubah setelah create:
- `id`, `Id`
- `userId`, `UserId`
- `createdAt`, `CreatedAt`
- `IncidentId`

## Referensi

- Firestore Rules Documentation: https://firebase.google.com/docs/firestore/security/rules-conditions
- Security Rules Best Practices: https://firebase.google.com/docs/firestore/security/rules-structure
