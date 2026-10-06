# Pertemuan 4 — State management CampusGhost

## Dua fitur

1. **Buat laporan fasilitas:** validasi kategori, lokasi, deskripsi (minimal 10 karakter), dan foto wajib selain kategori WiFi. `ReportSubmissionNotifier` mengelola proses kirim. Saat request berlangsung, tombol kirim dan pemilih foto nonaktif agar tidak terjadi double tap.
2. **Riwayat laporan saya:** `userReportsProvider` memuat data laporan sebagai stream Riverpod. Profil menampilkan ringkasan dan riwayat, termasuk kondisi loading, data, kosong, error, serta tombol coba lagi.

## Posisi kode

- UI formulir dan tampilan state lokasi: `lib/screens/report/create_report_screen.dart`
- Provider stream riwayat dan notifier submit: `lib/providers/report_provider.dart`
- Akses dan penyimpanan data: `lib/repositories/report_repository.dart`
- UI ringkasan dan riwayat: `lib/screens/profile/profile_screen.dart`
- Widget test: `test/report_submission_screen_test.dart`

## Alur proses

1. Layar mengamati `locationsProvider` dan `reportSubmissionProvider`.
2. Flutter menampilkan loading, error dengan retry, empty state, atau form sesuai keadaan lokasi.
3. Validator form memeriksa input; aturan foto kategori juga dicek sebelum submit.
4. `ReportSubmissionNotifier.submit()` mengubah state menjadi `AsyncLoading`, kemudian memanggil `ReportRepository.submitReport()`.
5. Tombol membaca `isLoading` sehingga terkunci sampai repository berhasil atau melempar error. Setelah selesai, UI menampilkan hasil, dan stream riwayat memperbarui data.

## Pengujian dan bukti

Widget test mencakup loading lokasi, form berhasil dimuat, lokasi kosong, error, dan validasi deskripsi. Jalankan `flutter test test/report_submission_screen_test.dart`.

Untuk bukti visual presentasi, jalankan aplikasi dan ambil screenshot di folder `docs/screenshots/`:

- `laporan-form.png` — form laporan siap diisi.
- `laporan-validasi.png` — pesan validasi setelah submit tanpa deskripsi yang valid.
- `laporan-loading.png` — tombol bertuliskan “Mengirim...” saat request tertahan.
- `riwayat-laporan.png` — ringkasan dan riwayat laporan pada profil.

## Prompt AI yang digunakan

> Terapkan state management Riverpod untuk proses pengiriman laporan fasilitas di proyek Flutter CampusGhost. Pisahkan widget, notifier, dan repository; validasi input form; cegah double tap dengan menonaktifkan tombol saat submit; sediakan loading, data, empty, error dengan retry; tambahkan widget test untuk state utama serta dokumentasi posisi kode dan alur.

## Pemeriksaan dan perbaikan manual

- Menjaga aturan bisnis foto: foto wajib kecuali kategori WiFi.
- Memastikan validasi foto dan batas ukuran tetap dikerjakan repository/layar sebelum data disimpan.
- Memeriksa bahwa status loading notifier menjadi satu sumber bagi tombol submit dan pemilih foto.
- Menambahkan retry lokasi dan riwayat melalui `ref.invalidate`.
- Memastikan status duplikat dan pemrosesan laporan tetap ditampilkan sesuai hasil repository.
