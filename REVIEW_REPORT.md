# Review Report — Campus Ghost MVP

## Audit dan cakupan

Proyek yang diaudit adalah aplikasi Flutter/Dart yang sudah memiliki layar auth, dashboard, formulir laporan, detail incident, profil, provider Riverpod, repository, Firebase Auth, secure storage, GPS, kamera, serta layar REST API. CRUD lokal dan foto tersimpan dengan namespace UID. Audit menemukan route privat bisa dipanggil langsung lewat named route tanpa melewati `AuthGate`; seluruh route privat sekarang dibungkus `ProtectedRoute`.

Penyimpanan laporan prototipe menggunakan secure storage lokal per UID, bukan Firestore bersama. Karena itu, autentikasi membatasi pengalaman per akun pada perangkat, tetapi data laporan belum tersinkron antar perangkat/pengguna. Peta kampus bersifat ilustratif.

## Implementasi advanced feature

| Fitur | File dan baris | Hubungan ke alur utama | Skenario / hasil verifikasi |
|---|---|---|---|
| Autentikasi | `lib/services/auth_service.dart:7-41`, `lib/widgets/auth_gate.dart:9-49`, `lib/config/routes.dart:17-27` | Register/login memakai Firebase Auth; `AuthGate` memulihkan sesi; named route privat memakai `ProtectedRoute`; Profil melakukan logout. Data laporan memakai UID. | `test/protected_route_test.dart` membuktikan route dashboard menampilkan login ketika sesi kosong. Skenario Firebase sukses, kredensial salah, serta auto-login perlu dijalankan pada Firebase/perangkat yang disiapkan. |
| Lokasi GPS | `lib/screens/report/create_report_screen.dart:95-264`, `lib/services/location_service.dart:40-169`, `lib/repositories/report_repository.dart:90-160` | Tombol lokasi pada form meminta izin, menampilkan koordinat, dan meneruskan nilai ke repository; detail report menyimpan latitude/longitude dan label area. | Kode menangani granted, ditolak sekali, ditolak permanen, layanan GPS mati, fallback default, dan error. Uji izin aktual belum dijalankan karena memerlukan perangkat/emulator Android. |
| Kamera/foto | `lib/services/camera_photo_service.dart:33-95`, `lib/screens/report/create_report_screen.dart:266-390`, `lib/repositories/report_repository.dart:90-160` | Form membuka kamera/galeri, preview dapat diubah/dihapus; payload gambar divalidasi dan disimpan bersama laporan. Foto wajib kecuali kategori Wi-Fi. | Kode menangani batal tanpa perubahan, format/ukuran tidak valid, error, dan izin kamera ditolak dengan retry/pengaturan. Kamera/galeri fisik belum diuji di perangkat. |

## Bukti pemeriksaan

- `flutter analyze` — **lulus**, “No issues found”.
- `flutter test` — **lulus**, 30 test.
- `flutter build apk --debug` — **tidak dapat dijalankan**: lingkungan tidak memiliki Android SDK (`No Android SDK found`). Ini keterbatasan toolchain, bukan error kompilasi yang teramati.
- Test lama yang gagal pada label UI/teks fixture diselaraskan di `test/report_submission_screen_test.dart` dan `test/report_api_vertical_slice_test.dart`, lalu suite penuh lulus.
- Manual skenario Firebase, permission prompt, kamera, dan GPS **belum dijalankan** di perangkat; jangan anggap hasil runtime perangkat sudah terverifikasi hanya dari analisis kode.

## Checklist

| Item | Status (Lulus/Gagal) | Bukti (file:baris / hasil uji) |
|---|---|---|
| Navigasi lengkap | Lulus | `lib/config/routes.dart:17-27`, `lib/widgets/auth_gate.dart:13-49`; route privat memakai `ProtectedRoute`. |
| Form + validasi | Lulus | `lib/screens/report/create_report_screen.dart:394-414`, `:650-900`; `flutter test` mencakup form dan validasi. |
| CRUD + persistensi | Lulus | `lib/repositories/report_repository.dart:90-218`, `lib/services/local_campus_store.dart:22-83`; test CRUD/persistensi lokal lulus dalam suite. |
| Autentikasi | Lulus | `lib/services/auth_service.dart:7-41`, `lib/widgets/auth_gate.dart:13-49`; integrasi Firebase ada, skenario akun live belum dijalankan. |
| Lokasi | Lulus | `lib/screens/report/create_report_screen.dart:95-264`, `lib/services/location_service.dart:40-169`; status izin ditangani di kode; uji perangkat belum dijalankan. |
| Kamera | Lulus | `lib/services/camera_photo_service.dart:33-95`, `lib/screens/report/create_report_screen.dart:341-390`; pembatalan/error/izin ditangani di kode; uji perangkat belum dijalankan. |
| Loading state | Lulus | `lib/widgets/auth_gate.dart:20-22`, form submit dan GPS; test API memeriksa loading; suite lulus. |
| Empty state | Lulus | Dashboard dan Profil memiliki empty state; `test/profile_report_crud_widget_test.dart` memeriksa empty state setelah hapus. |
| Error state | Lulus | Form, auth, foto, GPS, dan API memiliki penanganan pesan/retry; test API loading/error/retry lulus. |
| Penanganan izin | Lulus | GPS: `lib/screens/report/create_report_screen.dart:102-260`; kamera: `:341-390`; prompt sistem aktual belum diuji pada perangkat. |
| Penanganan pembatalan | Lulus | Foto batal: `lib/screens/report/create_report_screen.dart:344-346`; form belum tersimpan dan hapus dibatalkan ditangani dialog; test CRUD memeriksa dialog hapus. |

## Batas verifikasi tersisa

Untuk menyelesaikan review pada perangkat demo, siapkan Android SDK dan Firebase project aktif, lalu ikuti `DEMO_SCRIPT.md`. Fokus verifikasi manual: kredensial Firebase sukses/gagal, auto-login, izin lokasi dan kamera ditolak/permanen, GPS mati, foto dibatalkan, dan pengambilan foto berhasil. Build APK belum mendapat hasil karena SDK tidak tersedia di lingkungan audit ini.
