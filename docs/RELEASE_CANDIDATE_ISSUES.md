# Release Candidate Issue & Bug Tracker (GitHub / JIRA Ready)
**Aplikasi:** CampusGhost (Pelaporan & Manajemen Fasilitas Kampus)  
**Tanggal:** 26 November 2026  
**Total Isu:** 11 Isu (8 Bug Nyata Ditemukan + 3 Fitur Baru)

---

## 🐞 DAFTAR BUG (MINIMAL 5, DITEMUKAN 8 BUG NYATA)

### 1. [BUG-001] Firestore Query pada `watchReports` & `getReports` Gagal dengan `permission-denied`
* **Jenis:** Bug
* **Prioritas:** Critical (Blocker)
* **Komponen:** `lib/services/firestore_report_service.dart:24-41`, `firestore.rules:64-66`
* **Deskripsi:**  
  Security Rules Firestore membatasi pembacaan dokumen `reports` dengan syarat:
  `resource.data.userId == request.auth.uid`.  
  Namun pada kode klien, `watchReports()` memanggil `_reportsRef.snapshots()` dan `getReports()` memanggil `_reportsRef.get()` tanpa filter `.where('userId', isEqualTo: auth.currentUser.uid)`.  
  Dalam Firestore, aturan keamanan bukan filter ("rules are not filters"). Permintaan membaca seluruh koleksi ditolak langsung dengan exception `[cloud_firestore/permission-denied]`.
* **Langkah Reproduksi:**
  1. Login ke aplikasi menggunakan akun Firebase yang sah.
  2. Buka dashboard atau riwayat laporan.
  3. Amati log konsol atau status antarmuka.
* **Hasil Aktual:** Muncul `permission-denied`, daftar laporan dari Firestore tidak dapat dimuat.
* **Hasil yang Diharapkan:** Kueri harus menyertakan `.where('userId', isEqualTo: _auth.currentUser!.uid)` untuk pengguna bertipe mahasiswa, atau Security Rules disesuaikan agar role teknisi/mahasiswa dapat membaca laporan aktif.

---

### 2. [BUG-002] `_waitForCustomClaims` Menggunakan Token Cache sehingga Registrasi Mengalami Freeze Hingga 102 Detik
* **Jenis:** Bug
* **Prioritas:** High
* **Komponen:** `lib/services/auth_service.dart:64-88`
* **Deskripsi:**  
  Setelah user mendaftar (`register` atau `signInWithGoogle`), aplikasi menunggu Custom Claims dari Cloud Function melalui metode `_waitForCustomClaims`.  
  Di dalam loop:
  ```dart
  final tokenResult = await user.getIdTokenResult();
  ```
  Pemanggilan dilakukan tanpa argumen `forceRefresh: true` (default `false`). Firebase Auth hanya mengembalikan token cache yang belum memiliki Custom Claims `role: 'student'`.  
  Akibatnya, loop perulangan 10 kali exponential backoff selalu gagal dan memakan waktu total delay:
  `100ms * (2^10 - 1) = 102.3 detik (~1.7 menit)` sebelum loop berakhir dan baru memanggil `user.getIdToken(true)`.
* **Langkah Reproduksi:**
  1. Buka layar registrasi `RegisterScreen`.
  2. Isi form dan tekan tombol "Daftar Akun".
  3. Perhatikan waktu pemrosesan.
* **Hasil Aktual:** Layar loading berputar lebih dari 1.5 menit seolah aplikasi freeze.
* **Hasil yang Diharapkan:** Memanggil `user.getIdTokenResult(true)` di dalam loop agar klaim server terbaru langsung terambil, serta menambahkan batas waktu tunggu maksimum (misal 5 detik).

---

### 3. [BUG-003] Mismatch ID Dokumen Antara Local Storage dan Firestore Menyebabkan Update Status Gagal
* **Jenis:** Bug
* **Prioritas:** High
* **Komponen:** `lib/repositories/report_repository.dart:176, 199, 275`, `lib/services/firestore_report_service.dart:67, 127`
* **Deskripsi:**  
  Ketika `submitReport` dijalankan, repository menghasilkan ID lokal acak (`_newId`) dan menyimpannya di `LocalCampusStore`. Selanjutnya, repository memanggil `FirestoreReportService.createReport()`.  
  Di dalam `createReport()`, service membuat dokumen baru dengan ID acak internal Firestore (`docRef = _reportsRef.doc()`).  
  Ketika pengguna atau teknisi memanggil `updateReport(reportId)`, ID lokal yang dikirimkan tidak cocok dengan ID dokumen di Firestore. Dokumen di Firestore tidak terupdate. Selain itu, `deleteReport` hanya menghapus data di local storage tanpa menghapus dokumen di Firestore.
* **Langkah Reproduksi:**
  1. Buat laporan kendala fasilitas baru.
  2. Buka Profil -> Riwayat Laporan -> Edit Laporan (ubah deskripsi / status).
  3. Cek Firestore console pada dokumen terkait.
* **Hasil Aktual:** Dokumen Firestore tidak terupdate karena ID dokumen berbeda.
* **Hasil yang Diharapkan:** Pembuatan dokumen Firestore menggunakan ID lokal yang sama (`_reportsRef.doc(reportId).set(...)`), dan fungsi delete juga melakukan sinkronisasi penghapusan ke Firestore.

---

### 4. [BUG-004] Modifikasi Status Laporan Ditolak Firestore Security Rules (Client-side Update Forbidden)
* **Jenis:** Bug
* **Prioritas:** High
* **Komponen:** `firestore.rules:125-133`, `lib/services/firestore_report_service.dart:127-135`
* **Deskripsi:**  
  Aturan Firestore secara tegas melarang client memodifikasi `status` / `Status`:
  ```rules
  && !request.resource.data.diff(resource.data).affectedKeys()
       .hasAny(['id', 'userId', 'createdAt', 'incidentId', 'status', 'Status', 'assignedTo'])
  ```
  Namun `FirestoreReportService.updateReportStatus` mencoba langsung melakukan update field `status: status.value` dari aplikasi Flutter. Operasi ini selalu melempar `[cloud_firestore/permission-denied]`.
* **Langkah Reproduksi:**
  1. Buka layar Profil atau Layar Teknisi.
  2. Lakukan perubahan status laporan menjadi Selesai atau Dalam Proses.
* **Hasil Aktual:** Muncul error permission denied di konsol/log, status tidak dapat diperbarui di backend.
* **Hasil yang Diharapkan:** Perubahan status dilakukan melalui Cloud Function berwenang atau aturan Firestore disesuaikan untuk mengizinkan perubahan status oleh role teknisi.

---

### 5. [BUG-005] Panel Tiket Teknisi Hanya Memuat Laporan Pribadi Teknisi Bukan Seluruh Laporan Kampus
* **Jenis:** Bug
* **Prioritas:** High
* **Komponen:** `lib/providers/technician_tickets_provider.dart:9-12`
* **Deskripsi:**  
  Provider `technicianTicketsProvider` diimplementasikan dengan:
  ```dart
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(reportRepositoryProvider).watchReportsForUser(userId);
  ```
  Di mana `userId` adalah UID akun teknisi yang sedang login. Akibatnya, teknisi hanya memantau laporan yang ia laporkan sendiri. Seluruh laporan yang dibuat oleh mahasiswa atau dosen tidak pernah masuk ke antrean tiket teknisi.
* **Langkah Reproduksi:**
  1. Login sebagai mahasiswa A dan kirim laporan kerusakan proyektor.
  2. Logout dan login kembali sebagai teknisi GA.
  3. Buka tab "Tiket GA".
* **Hasil Aktual:** Daftar tiket kosong (0 tiket).
* **Hasil yang Diharapkan:** Teknisi dapat melihat seluruh tiket aktif yang dilaporkan seluruh civitas akademika kampus.

---

### 6. [BUG-006] Pemilih Foto di `EditProfileScreen` Menggunakan `file_selector` yang Bermasalah di Android
* **Jenis:** Bug
* **Prioritas:** Medium
* **Komponen:** `lib/screens/profile/edit_profile_screen.dart:59-66`
* **Deskripsi:**  
  `EditProfileScreen` menggunakan fungsi `openFile(...)` dari library `file_selector` untuk memilih foto profil. Pada perangkat Android, integrasi `file_selector` belum optimal dan sering melempar `PlatformException` atau gagal membuka media store. Di sisi lain, pembuatan laporan sudah menggunakan `image_picker`.
* **Langkah Reproduksi:**
  1. Jalankan aplikasi pada perangkat Android.
  2. Buka menu Profil -> Edit Profil -> Ganti Foto Profil.
* **Hasil Aktual:** Galeri gagal terbuka atau muncul notifikasi "Foto tidak dapat dibaca".
* **Hasil yang Diharapkan:** Menggunakan `image_picker` (sama seperti `CameraPhotoService`) yang telah teruji kompatibel di Android.

---

### 7. [BUG-007] Checkbox 'Ingat Saya' di Halaman Login Tidak Berfungsi (No Persistence Logic)
* **Jenis:** Bug
* **Prioritas:** Low / UX
* **Komponen:** `lib/screens/auth/login_screen.dart:21, 287-301`
* **Deskripsi:**  
  Variabel state `_remember` pada `LoginScreen` dapat dicentang atau dihilangkan centangnya oleh pengguna, namun nilainya tidak pernah dikirimkan atau diproses dalam `_login()` maupun `AuthService`. Firebase Auth secara default akan tetap menyimpan sesi pengguna di storage lokal secara permanen.
* **Langkah Reproduksi:**
  1. Buka layar Login.
  2. Hapus centang "Ingat saya".
  3. Login dan kemudian tutup aplikasi secara paksa (force close).
  4. Buka kembali aplikasi.
* **Hasil Aktual:** Pengguna langsung masuk ke dashboard tanpa diminta login ulang.
* **Hasil yang Diharapkan:** Jika "Ingat saya" tidak dicentang, sesi hanya disimpan untuk sesi aktif (atau keluar saat aplikasi ditutup), atau hilangkan opsi tersebut jika sesi selalu dibuat persisten.

---

### 8. [BUG-008] Dialog 'Pilih Peran Pengguna' Tidak Memiliki Fungsionalitas Pergantian Peran (Dead End UI)
* **Jenis:** Bug
* **Prioritas:** Medium
* **Komponen:** `lib/screens/profile/profile_screen.dart:333-382`, `lib/providers/user_role_provider.dart:83-85`
* **Deskripsi:**  
  Di layar profil terdapat ListTile "Peran Aplikasi" yang membuka dialog `_showRoleDialog`. Di dalam dialog tersebut, opsi peran hanya menampilkan icon centang tetapi tidak memiliki aksi `onTap` apa pun saat diklik, karena fungsi `setRole` di client telah dihapus untuk alasan keamanan backend. Hal ini membingungkan pengguna karena tombol terlihat interaktif namun tidak melakukan apa pun.
* **Langkah Reproduksi:**
  1. Buka Profil -> Pengaturan -> tap "Peran Aplikasi".
  2. Dialog pilihan peran muncul.
  3. Tap pada peran "Teknisi GA & Satpam" atau "Administrator".
* **Hasil Aktual:** Tidak ada respon apa pun, dialog tidak tertutup dan tidak ada notifikasi penjelasan.
* **Hasil yang Diharapkan:** Menampilkan dialog informatif yang menjelaskan bahwa peran diatur oleh Administrator Kampus, atau menyediakan formulir pengajuan peran bagi staf/teknisi.

---

## 🚀 DAFTAR FITUR BARU / ENHANCEMENTS

### 9. [FEAT-001] Offline Sync & Queue untuk Pelaporan Fasilitas saat Blank Spot Kampus
* **Jenis:** Feature Request / Enhancement
* **Prioritas:** High
* **Deskripsi:**  
  Beberapa area kampus seperti basement parkir atau lorong lift tertentu sering mengalami kehilangan sinyal (blank spot). Fitur ini menyediakan antrean sinkronisasi lokal (`sync_queue`). Ketika pengguna submit laporan tanpa koneksi internet, laporan disimpan dalam antrean berstatus `pending_sync`. Saat koneksi pulih, aplikasi secara otomatis mengunggah laporan ke Firestore dan memberitahu pengguna.
* **Kriteria Penerimaan (Acceptance Criteria):**
  1. Pengguna tetap dapat menekan tombol kirim saat offline.
  2. Notifikasi snackbar: "Anda sedang offline. Laporan disimpan dan akan otomatis terkirim saat internet terhubung."
  3. Background listener mendeteksi pemulihan koneksi dan otomatis mengunggah data laporan beserta bukti foto.

---

### 10. [FEAT-002] Push Notification Status Tiket Fasilitas Real-Time via FCM
* **Jenis:** Feature Request / Enhancement
* **Prioritas:** Medium
* **Deskripsi:**  
  Mengintegrasikan Firebase Cloud Messaging (FCM) agar pelapor mendapatkan pemberitahuan instan di notification bar smartphone saat teknisi mulai mengerjakan perbaikan atau saat fasilitas telah selesai diperbaiki.
* **Kriteria Penerimaan (Acceptance Criteria):**
  1. Pelapor menerima push notification saat status tiket berubah menjadi "Sedang Dikerjakan" atau "Selesai".
  2. Mengetuk notifikasi langsung membuka halaman detail kendala fasilitas terkait.
  3. Terdapat opsi toggle notifikasi di menu Pengaturan Profil.

---

### 11. [FEAT-003] Peta Interaktif Denah Kampus dengan Titik Fasilitas Bermasalah
* **Jenis:** Feature Request / Enhancement
* **Prioritas:** Medium
* **Deskripsi:**  
  Menyediakan tampilan peta interaktif denah lantai dan kawasan Pradita University dengan pin warna sesuai status kendala (Merah: Masalah Aktif, Kuning: Sedang Diperbaiki, Hijau: Selesai). Memudahkan mahasiswa menghindari fasilitas yang rusak dan membantu teknisi menemukan titik lokasi secara visual.
* **Kriteria Penerimaan (Acceptance Criteria):**
  1. Visualisasi denah kampus interaktif (zoom & pan).
  2. Pin marker menunjukkan kategori (AC, Lift, Wifi, Proyektor).
  3. Mengetuk pin marker menampilkan bottom sheet ringkasan kendala fasilitas.
