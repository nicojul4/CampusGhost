# Pertemuan 5 — Local Data & Persistence CampusGhost

Dokumen ini berisi panduan implementasi, posisi kode, dan skenario demonstrasi fitur **Local Data & Persistence** untuk reviewer pada proyek CampusGhost.

---

## 1. Ringkasan Implementasi Fitur

- **Fitur Vertikal:** Pelaporan Fasilitas Kampus (*Report Facility Issue*).
- **Alur Vertikal (FE $\rightarrow$ Local Storage):**
  `Form UI (CreateReportScreen)` $\rightarrow$ `State/Notifier (Riverpod)` $\rightarrow$ `Repository (ReportRepository)` $\rightarrow$ `Local Storage Engine (LocalCampusStore / FlutterSecureStorage)`.
- **Penyimpanan Lokal:** Menggunakan paket `flutter_secure_storage` yang menyimpan data terenkripsi pada perangkat (KeyStore di Android, Keychain di iOS, Web Crypto / LocalStorage di Web).
- **Status Pengujian:** 15/15 automated tests lulus (`All tests passed!`).

---

## 2. Posisi Kode untuk Reviewer

Struktur kode terbagi secara vertikal dari UI, State, Repository, hingga Local Storage Engine:

| Kriteria Tugas | Letak File & Posisi Baris | Keterangan |
| :--- | :--- | :--- |
| **Local Storage Engine** | [`lib/services/local_campus_store.dart`](../lib/services/local_campus_store.dart) | Wrapper `FlutterSecureStorage` untuk operasi I/O data mentah JSON laporan (`campus_ghost_reports_$userId`) dan foto profil. |
| **Data Model** | [`lib/models/report_model.dart`](../lib/models/report_model.dart) | Entity `ReportModel` berisi atribut: `id`, `userId`, `locationId`, `category`, `description`, `status`, `photoUrl`, `incidentId`, `createdAt`, `updatedAt`. |
| **CRUD: Create** | Form: [`lib/screens/report/create_report_screen.dart`](../lib/screens/report/create_report_screen.dart)<br>Logika: [`lib/repositories/report_repository.dart`](../lib/repositories/report_repository.dart#L90-L155) | Fungsi `submitReport()` melakukan validasi input, enkripsi/kompresi foto opsional, dan persistensi record laporan ke storage lokal. |
| **CRUD: Read** | Tampilan: [`lib/screens/profile/profile_screen.dart`](../lib/screens/profile/profile_screen.dart#L204-L258)<br>Stream: [`lib/providers/report_provider.dart`](../lib/providers/report_provider.dart#L27-L30) | Provider `userReportsProvider` memantau stream `watchReports()` untuk merender *Riwayat Laporan Saya* dan metrik *Ringkasan Kontribusi* secara reaktif. |
| **CRUD: Update** | Dialog: [`lib/screens/profile/profile_screen.dart`](../lib/screens/profile/profile_screen.dart#L384-L519)<br>Logika: [`lib/repositories/report_repository.dart`](../lib/repositories/report_repository.dart#L157-L184) | Komponen `_EditReportDialog` & fungsi `updateReport()` memperbarui deskripsi kendala dan status laporan (*Aktif* / *Selesai*), lalu menyimpan perubahannya kembali ke storage lokal. |
| **CRUD: Delete** | Dialog: [`lib/screens/profile/profile_screen.dart`](../lib/screens/profile/profile_screen.dart#L58-L102)<br>Logika: [`lib/repositories/report_repository.dart`](../lib/repositories/report_repository.dart#L186-L192) | Dialog konfirmasi hapus & fungsi `deleteReport()` menghapus record laporan secara permanen dari storage lokal. |
| **Persistence Test** | [`test/report_local_crud_test.dart`](../test/report_local_crud_test.dart#L224-L266) | Test case nomor 5 menguji penutupan sesi/instansiasi ulang storage untuk membuktikan data tetap persisten setelah aplikasi ditutup/dibuka kembali. |

---

## 3. Skema Data Lokal (Data Model & Storage)

Data disimpan dalam format JSON string terenkripsi dengan kunci:
`campus_ghost_reports_<USER_ID>`

Struktur JSON tiap record laporan:
```json
{
  "Id": "1729040000000_a1b2c3d4e5f6789012",
  "UserId": "user_uid_atau_guest_user",
  "LocationId": "gedung-1-lt3",
  "Category": "Wifi",
  "Description": "Koneksi Wi-Fi di lantai 3 Gedung 1 terputus-putus.",
  "Status": "Active",
  "IncidentId": "1729040000000_a1b2c3d4e5f6789012",
  "PhotoUrl": "data:image/jpeg;base64,...",
  "CreatedAt": "2026-10-16T01:15:00.000Z",
  "UpdatedAt": "2026-10-16T01:15:00.000Z"
}
```

---

## 4. Panduan Skenario Demo untuk Reviewer

Ikuti langkah-langkah berikut saat mendemokan aplikasi di hadapan reviewer:

### A. Menjalankan Aplikasi
Jalankan aplikasi di browser Chrome atau Linux Desktop:
```bash
flutter run -d chrome
# atau
flutter run -d linux
```

---

### B. Alur Demo Interaktif (CRUD & Persistence Test)

1. **Create (Menambahkan Data):**
   - Di halaman utama / beranda, klik tombol **"Buat Laporan"** (ikon tambah).
   - Pilih kategori fasilitas, misalnya **"Wifi"**.
   - Pilih lokasi kampus (misalnya: *Gedung 1 - Lt 3*).
   - Tulis deskripsi kendala (minimal 10 karakter, contoh: `"Koneksi Wi-Fi putus-putus di lantai 3"`).
   - Klik **"Kirim Laporan Fasilitas"**.

2. **Read (Membaca & Menampilkan Data):**
   - Pindah ke menu **Profil** di navigasi bawah (ikon orang).
   - Tunjukkan kepada reviewer bahwa laporan baru langsung muncul di bagian **"Riwayat Laporan Saya"** dan counter pada **"Ringkasan Kontribusi"** bertambah.

3. **Update (Memperbarui Data):**
   - Pada kartu laporan di halaman Profil, klik tombol **titik tiga (`⋮`)** di pojok kanan atas kartu.
   - Pilih menu **"Edit laporan"**.
   - Ubah teks deskripsi atau alihkan status menjadi **"Selesai"**.
   - Klik **"Simpan"**.
   - Tunjukkan bahwa badge status langsung berganti menjadi hijau (*Selesai*).

4. **Persistence Test (Kunci Pembuktian Pertemuan 5):**
   - Tekan tombol **Refresh browser (`F5` / `Ctrl+R`)** jika di Chrome, atau tutup aplikasi (`q` di terminal) lalu jalankan kembali (`flutter run`).
   - Masuk kembali ke tab **Profil**.
   - **Tunjukkan kepada reviewer bahwa data laporan yang sudah di-update tadi masih tersimpan utuh dan tidak hilang**.

5. **Delete (Menghapus Data):**
   - Klik kembali tombol **titik tiga (`⋮`)** pada kartu laporan.
   - Pilih menu **"Hapus laporan"**.
   - Pada dialog konfirmasi *"Hapus Laporan?"*, klik tombol **"Hapus"**.
   - Laporan langsung terhapus dari daftar layar.
   - Lakukan refresh browser sekali lagi untuk membuktikan bahwa data telah terhapus secara permanen dari storage lokal.

---

### C. Pengujian Otomatis (Automated Test Execution)

Untuk membuktikan seluruh persyaratan rubrik (Create, Read, Update, Delete, Persistence, Error Handling, Guest Mode) telah teruji secara sistematis:

Jalankan perintah pengujian:
```bash
flutter test
```

**Hasil Pengujian:**
```text
00:00 +0: /test/report_local_crud_test.dart: 1. CREATE: Berhasil menambahkan data laporan ke local storage
00:00 +1: /test/report_local_crud_test.dart: 2. READ: Berhasil membaca data laporan dari local storage ke UI model
00:00 +2: /test/report_local_crud_test.dart: 3. UPDATE: Berhasil memperbarui deskripsi dan status laporan di local storage
00:00 +3: /test/report_local_crud_test.dart: 3b. UPDATE Validation: Menolak deskripsi kurang dari 10 karakter
00:00 +4: /test/report_local_crud_test.dart: 4. DELETE: Berhasil menghapus laporan dari local storage
00:00 +5: /test/report_local_crud_test.dart: 4b. DELETE Error: Melempar StateError jika reportId tidak ditemukan
00:00 +6: /test/report_local_crud_test.dart: 5. PERSISTENCE: Data tetap tersedia setelah aplikasi dibuka kembali / instansiasi baru
00:00 +7: /test/report_local_crud_test.dart: 6. ERROR HANDLING: Data kosong atau rusak ditangani secara wajar tanpa crash
00:00 +8: /test/report_local_crud_test.dart: 7. GUEST MODE: Berhasil CRUD saat unauthenticated menggunakan fallback guest_user
00:03 +15: All tests passed!
```
