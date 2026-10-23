# Laporan Implementasi: API Integration + Vertical Slice (CampusGhost)

Dokumen ini mendokumentasikan implementasi lengkap **API Integration + Vertical Slice** pada aplikasi **CampusGhost**, mencakup analisis, arsitektur berlapis, pengujian unit & widget mock, verifikasi persistensi data, serta checklist reviewer.

---

## 1. Fitur yang Dipilih dan Alasannya

* **Fitur Terpilih:** **Laporan Fasilitas Kampus (*Campus Facility Issue Reports*)**
* **Alasan Pemilihan:**
  1. **Nilai Inti Aplikasi (*Core Value Proposition*):** CampusGhost berfokus pada pelaporan dan pemantauan kondisi riil fasilitas di lingkungan kampus (seperti Wi-Fi bermasalah, AC tidak dingin, proyektor mati, toilet rusak, lift macet, dan parkiran penuh).
  2. **Dua Operasi Inti *Vertical Slice*:**
     - **Tampil Daftar (*GET*):** Menampilkan daftar laporan kondisi fasilitas kampus dari server backend REST API secara *real-time* lengkap dengan status loading, empty, error, retry, dan success.
     - **Simpan Data (*POST*):** Form pelaporan fasilitas baru yang mengirimkan data ke server backend, divalidasi, disimpan secara persisten ke database disk, me-refresh daftar secara otomatis, dan memberikan umpan balik visual (*SnackBar* sukses/gagal).
  3. **Arsitektur Bersih (*Clean Layered Architecture*):** Fitur ini dapat dihubungkan secara modular: `UI` → `State Management` → `Repository` → `API Service` → `Backend REST API`.

---

## 2. Arsitektur Berlapis & Daftar File yang Dibuat/Diubah

### Diagram Arsitektur Aliran Data

```
┌────────────────────────────────────────────────────────┐
│ UI: ApiReportsScreen (_CreateReportFormSheet)          │
└───────────────────────────▲────────────────────────────┘
                            │ ref.watch() / ref.read()
┌───────────────────────────┴────────────────────────────┐
│ State Management: apiReportsNotifierProvider (Riverpod)│
│ State eksplisit: loading, empty, error, success        │
└───────────────────────────▲────────────────────────────┘
                            │ getReports() / createReport()
┌───────────────────────────┴────────────────────────────┐
│ Repository: ReportApiRepository                        │
│ Mapping JSON <-> ReportModel, Exception Handling       │
└───────────────────────────▲────────────────────────────┘
                            │ fetchReports() / createReport()
┌───────────────────────────┴────────────────────────────┐
│ API Service: ReportApiService (Dependency Injection)   │
│ Client http.Client, Timeout 10s, Status Non-2xx check  │
└───────────────────────────▲────────────────────────────┘
                            │ HTTP GET / POST
┌───────────────────────────┴────────────────────────────┐
│ Backend REST API: Node.js Server (server/server.js)     │
│ Database Persisten: server/reports_db.json             │
└────────────────────────────────────────────────────────┘
```

### File yang Dibuat:
1. `server/server.js` — Server backend REST API lokal berbasis Node.js mandiri (*zero external dependencies*), mendukung CORS, validasi payload, dan persistensi file JSON.
2. `lib/exceptions/api_exception.dart` — Definisi hierarki exception khusus: `ApiException`, `NetworkException`, `JsonParsingException`, dan `ValidationException`.
3. `lib/config/api_config.dart` — Konfigurasi terpusat untuk Base URL API (`http://127.0.0.1:3000/api`) dan timeout request (10 detik).
4. `lib/services/report_api_service.dart` — Lapisan HTTP client dengan *Dependency Injection* (`http.Client`), penanganan status non-2xx, koneksi terputus, timeout, dan validasi body respons JSON.
5. `lib/repositories/report_api_repository.dart` — Abstraksi data repository sebagai gerbang tunggal pengubah JSON menjadi entitas model domain dan penerus error.
6. `lib/providers/api_report_provider.dart` — Riverpod State Notifier dengan 4 status eksplisit: `loading`, `empty`, `error`, dan `success`.
7. `lib/screens/report/api_reports_screen.dart` — Antarmuka pengguna (*UI*) vertikal lengkap dengan visualisasi kondisi loading, empty, error + tombol retry, list success, dan form modal bottom sheet untuk submit laporan.
8. `test/report_api_vertical_slice_test.dart` — Unit test suite menggunakan `MockClient` (8 skenario pengujian tanpa akses jaringan nyata).
9. `test/api_reports_screen_widget_test.dart` — Widget test suite untuk memverifikasi ke-5 kondisi UI (loading, empty, error, retry, success, serta aksi submit form).

### File yang Diubah:
1. `pubspec.yaml` — Menambahkan dependency direct `http: ^1.6.0`.
2. `lib/models/report_model.dart` — Menambahkan `ReportModel.fromJson` dengan validasi ketat field wajib & tipe data yang melempar `ValidationException`, `toJson()`, serta kesetaraan `operator ==` dan `hashCode`.
3. `lib/config/routes.dart` — Mendaftarkan route navigasi `AppRoutes.apiReports` (`/api-reports`).
4. `lib/screens/home/home_screen.dart` — Menambahkan banner navigasi "Vertical Slice: Live API Reports" di dashboard utama aplikasi.

---

## 3. Endpoint API yang Digunakan

| Method | Endpoint URL | Fungsi | Status Respons |
|:---:|---|---|:---:|
| `GET` | `http://127.0.0.1:3000/api/reports` | Mengambil seluruh daftar laporan fasilitas kampus | `200 OK` (JSON Array) |
| `POST` | `http://127.0.0.1:3000/api/reports` | Mengirim dan menyimpan data laporan fasilitas baru | `201 Created` / `400 Bad Request` |
| `GET` | `http://127.0.0.1:3000/api/health` | Health check ketersediaan server | `200 OK` |
| `GET` | `http://127.0.0.1:3000/api/reports?simulate_error=500` | Simulasi server error untuk verifikasi kondisi Error & Retry | `500 Internal Server Error` |
| `GET` | `http://127.0.0.1:3000/api/reports?simulate_empty=true` | Simulasi respons database kosong untuk verifikasi Empty State | `200 OK` (`[]`) |

---

## 4. Hasil Unit Test (8 Pengujian, 100% Lulus)

Seluruh pengujian unit dijalankan menggunakan `MockClient` dari `package:http/testing.dart` di folder `test/` (tanpa menyentuh jaringan nyata):

| No | Skenario Pengujian | Komponen Target | Hasil Pengujian | Status |
|:---:|---|---|---|:---:|
| 1 | **Model valid**: `fromJson` dengan data lengkap menghasilkan objek dengan nilai yang tepat | `ReportModel` | Nilai atribut objek cocok presisi dengan payload JSON | **LULUS** |
| 2 | **Model invalid**: data kurang field wajib / tipe salah / format tanggal rusak | `ReportModel` | Berhasil mendeteksi data rusak & melempar `ValidationException` | **LULUS** |
| 3 | **API sukses**: respons status 200 berisi daftar item → repository mengembalikan list model yang benar | `ReportApiService` & `ReportApiRepository` | Mengembalikan `List<ReportModel>` berisi 2 entitas | **LULUS** |
| 4 | **Data kosong**: respons 200 dengan `[]` → repository mengembalikan list kosong (bukan error) | `ReportApiRepository` | Mengembalikan list kosong `[]` bertipe `List<ReportModel>` | **LULUS** |
| 5 | **HTTP gagal**: respons status 404 / 500 → melempar exception yang sesuai | `ReportApiService` & `ReportApiRepository` | Melempar `ApiException` dengan status code 404 dan 500 | **LULUS** |
| 6 | **JSON rusak**: body respons bukan JSON valid (contoh: halaman HTML 502) | `ReportApiService` & `ReportApiRepository` | Berhasil menangani parse error & melempar `JsonParsingException` | **LULUS** |
| 7 | *(Bonus)* **Simpan data (POST) sukses**: mengirim payload JSON dan mengembalikan model baru | `ReportApiRepository` | Status 201 Created dan mengembalikan entitas tersimpan | **LULUS** |
| 8 | *(Bonus)* **Simpan data (POST) gagal**: respons 400 bad request saat validasi server gagal | `ReportApiRepository` | Melempar `ApiException` dengan status code 400 | **LULUS** |

### Output Asli Terminal:
```text
00:00 +0: loading /home/nicolas/CampusGhost/test/report_api_vertical_slice_test.dart
00:00 +0: Vertical Slice Unit Tests — Report API 1. Model valid: fromJson dengan data benar menghasilkan objek dengan nilai yang tepat
00:00 +1: Vertical Slice Unit Tests — Report API 2. Model invalid: data kurang field atau tipe salah menghasilkan ValidationException
00:00 +2: Vertical Slice Unit Tests — Report API 3. API sukses: respons 200 berisi daftar item -> repository mengembalikan list model yang benar
00:00 +3: Vertical Slice Unit Tests — Report API 4. Data kosong: respons 200 dengan [] -> repository mengembalikan list kosong (bukan error)
00:00 +4: Vertical Slice Unit Tests — Report API 5. HTTP gagal: respons 404/500 -> melempar exception ApiException yang sesuai
00:00 +5: Vertical Slice Unit Tests — Report API 6. JSON rusak: body bukan JSON valid -> melempar exception JsonParsingException yang jelas
00:00 +6: Vertical Slice Unit Tests — Report API 7. Simpan data (POST): berhasil mengirim dan mengembalikan objek model baru
00:00 +7: Vertical Slice Unit Tests — Report API 8. Simpan data (POST) gagal: server return 400 -> melempar ApiException
00:00 +8: All tests passed!
```

### Verifikasi 5 Kondisi UI via Widget Test (`test/api_reports_screen_widget_test.dart`):
1. **Kondisi 1 (Loading):** Menampilkan `CircularProgressIndicator` dan teks *"Menghubungkan ke API server..."* saat request sedang berjalan.
2. **Kondisi 2 (Empty):** Menampilkan ikon dokumen, judul *"Belum Ada Laporan"*, dan tombol *"Muat Ulang"* saat backend merespons `[]`.
3. **Kondisi 3 (Error):** Menampilkan ikon cloud off, pesan error ramah pengguna, dan tombol *"Coba Lagi"* saat server merespons 500 / offline.
4. **Kondisi 4 (Retry):** Menekan tombol *"Coba Lagi"* memicu kembali pengambilan request API kedua hingga data berhasil ditampilkan.
5. **Kondisi 5 (Success):** Menampilkan kartu laporan dengan kategori, lokasi, badge status, deskripsi, dan waktu pelaporan.
6. **Aksi Submit Form:** Mengisi form pelaporan, menekan *"Kirim Laporan"*, mengirim POST ke backend, menampilkan SnackBar hijau konfirmasi sukses, dan me-refresh daftar secara otomatis.

> Total pengujian keseluruhan proyek: **29 test passed, 0 failed**.

---

## 5. Bukti Verifikasi Linting, Build, & Persistensi Data

### 1. Analisis Kode Statis (`flutter analyze`)
```text
Analyzing CampusGhost...                                        
No issues found! (ran in 2.3s)
```

### 2. Kompilasi Web (`flutter build web`)
```text
Compiling lib/main.dart for the Web...
✓ Built build/web
```

### 3. Persistensi Data ke Backend & Muat Ulang Setelah Restart
1. Mengirim laporan baru melalui HTTP POST ke endpoint server:
   - Kategori: `"Proyektor"`
   - Lokasi: `"gedung-1-lantai-2"`
   - Deskripsi: `"Proyektor kelas 204 mati total saat presentasi."`
2. Server merespons `201 Created` dan data tersimpan ke `server/reports_db.json`.
3. Mematikan server backend (`kill process`), kemudian menyalakan kembali (`node server/server.js`).
4. Mengambil data dengan `GET http://127.0.0.1:3000/api/reports`. Data laporan yang baru dibuat tetap ada di disk dan berhasil dimuat ulang (`Verified Persistence: true`).

---

## 6. Panduan Menjalankan

### A. Menjalankan Backend API Server
```bash
node server/server.js
```
*Server aktif di `http://localhost:3000` dengan endpoint `/api/reports` dan `/api/health`.*

### B. Menjalankan Unit & Widget Test
```bash
# Menjalankan unit test vertical slice
flutter test test/report_api_vertical_slice_test.dart

# Menjalankan widget test kelima status UI
flutter test test/api_reports_screen_widget_test.dart

# Menjalankan seluruh test suite proyek (29 test)
flutter test
```

### C. Menjalankan Aplikasi Flutter
```bash
# Menjalankan di Google Chrome
flutter run -d chrome

# Atau di Linux Desktop
flutter run -d linux
```
*Pada halaman utama Dashboard, ketuk kartu banner **"Vertical Slice: Live API Reports"** untuk membuka antarmuka vertical slice.*

---

## Checklist Reviewer

- [x] **Sudah ada koneksi ke API**
  - **File Implementasi:** `lib/services/report_api_service.dart`, `lib/repositories/report_api_repository.dart`, dan `server/server.js`.
  - **Bukti:** Pengujian live curl, persistensi JSON disk, dan mock client test membuktikan integrasi HTTP GET & POST berjalan sempurna.
- [x] **Sudah ada unit test**
  - **Jumlah:** 8 unit test pada `test/report_api_vertical_slice_test.dart` + 6 widget test pada `test/api_reports_screen_widget_test.dart` (Total 14 test baru, total seluruh proyek 29 test).
  - **Hasil:** 100% Lulus (`All tests passed!`).
