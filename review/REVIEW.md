# Review UI/UX MVP CampusGhost

Review dilakukan pada 3 November 2026. Stack proyek adalah Flutter/Dart, dengan Flutter Web sebagai target yang dapat dijalankan di lingkungan ini. Styling menggunakan Material 3 dan `ThemeData`; test runner yang tersedia adalah `flutter_test`. `flutter analyze` berhasil tanpa temuan.

## Ringkasan empat item

| Item | Status | Temuan | Perbaikan yang dilakukan dalam review | File yang diubah |
|---|---|---|---|---|
| 01 Layout adaptif | FAIL (verifikasi parsial) | Layar login tampil pada 1440×900 dan 360×640 tanpa scroll horizontal yang terlihat. Ukuran 390×844 dan 768×1024 belum diuji, dan layar lain tidak dapat dibuka tanpa sesi akun. | Tidak ada perubahan kode. Screenshot perbandingan desktop/mobile dibuat. | `review/REVIEW.md`, empat PNG di `review/screenshots/` |
| 02 Keyboard-safe UI | FAIL | Form login memakai `SingleChildScrollView`, dan form API memakai scroll view serta padding `viewInsets`. Pada simulasi ruang viewport 360×400 dengan input email fokus, input terlihat tetapi tombol submit tidak terlihat. Keyboard native Android tidak dapat diuji karena emulator tidak tersedia. | Tidak ada perubahan kode. Screenshot menunjukkan input fokus pada viewport yang diperkecil, bukan keyboard OS sungguhan. | `review/REVIEW.md`, `review/screenshots/02-keyboard-aktif-input-terlihat.png` |
| 03 Accessibility dasar | FAIL (parsial) | Label login/daftar/edit profil dan tooltip ikon terlihat dalam kode kerja saat ini; fokus keyboard pada field login terlihat jelas. Belum ada hasil audit axe/Lighthouse, pengukuran kontras otomatis, atau audit lengkap semua layar. | Tidak ada perubahan kode. Bukti fokus dan label diambil dari aplikasi berjalan. | `review/REVIEW.md`, `review/screenshots/03-accessibility-fokus-label-kontras.png` |
| 04 Feedback aksi | FAIL (parsial) | Banyak alur sudah punya loading/disabled, pesan error, retry, atau empty state: login/daftar, pengiriman laporan, pemuatan API, logout, edit profil, dan pemuatan lokasi. Berhasil autentikasi, simpan, hapus, dan refresh tidak dapat diuji tanpa akun/sesi dan data yang dapat digunakan. Error validasi lokal pada login berhasil terlihat. | Tidak ada perubahan kode. Screenshot merekam feedback error validasi; tidak mengklaim sukses/loading end-to-end. | `review/REVIEW.md`, `review/screenshots/04-feedback-loading-sukses-error.png` |

## Layar dan kontrol yang ditemukan

- Login dan pendaftaran: email/NIM, kata sandi, ingat perangkat, tampil/sembunyikan kata sandi, bantuan akun, navigasi daftar/masuk, submit.
- Beranda: navigasi profil dan laporan API, notifikasi, refresh lokasi, pemilihan lokasi/marker, mulai laporan, buka detail.
- Buat laporan: kategori, lokasi, GPS, deskripsi, pilih/ambil foto, hapus foto, kirim, kembali.
- Detail insiden: kembali, buka alur laporan, kirim laporan cepat Wi-Fi; daftar laporan terkait.
- Laporan API: muat ulang, opsi simulasi data/error/kosong, buka/tutup formulir, kategori, lokasi, deskripsi, submit, retry.
- Profil: edit/hapus laporan, muat ulang laporan, edit profil, pilih/hapus foto profil, ubah nama, simpan, keluar.

## Bukti screenshot

- [01 Layout desktop dan mobile](screenshots/01-layout-besar-vs-kecil.png)
- [02 Input fokus pada viewport kecil (simulasi keyboard dengan resize)](screenshots/02-keyboard-aktif-input-terlihat.png)
- [03 Fokus, label, dan kontras visual](screenshots/03-accessibility-fokus-label-kontras.png)
- [04 Error validasi aksi submit](screenshots/04-feedback-loading-sukses-error.png)

## Sisa masalah dan rekomendasi

- Uji empat ukuran viewport yang diminta pada semua layar setelah ada sesi pengguna uji. Tambahkan layout ringkas saat keyboard muncul dan pastikan aksi utama tetap dapat dicapai pada viewport pendek.
- Jalankan uji keyboard native pada Android/iOS, termasuk fokus otomatis/scroll ke input aktif, perpindahan fokus, dan penutupan keyboard.
- Jalankan axe/Lighthouse pada build web dan audit seluruh nama aksesibel, urutan heading/fokus, target sentuh, serta rasio kontras WCAG AA. Flutter Web memakai semantics tree; pengujian manual di browser perlu mengaktifkannya.
- Siapkan akun Firebase uji dan data lokal yang aman untuk menguji state loading, sukses, error, retry, empty, simpan, hapus, serta navigasi end-to-end.
- Ada tujuh file kode yang sudah memiliki perubahan lokal sebelum review dimulai: `lib/screens/auth/login_screen.dart`, `lib/screens/auth/register_screen.dart`, `lib/screens/incident_detail/incident_detail_screen.dart`, `lib/screens/profile/profile_screen.dart`, `lib/screens/report/api_reports_screen.dart`, `lib/screens/report/create_report_screen.dart`, dan `lib/widgets/campus_ui.dart`. Perubahan itu tidak dibuat atau di-commit oleh review ini; status working tree tetap perlu ditinjau pemiliknya sebelum pemisahan commit item 02/03/04.

## Batas verifikasi

Aplikasi berjalan pada Flutter Web di Chrome headless. Perangkat yang terdeteksi adalah Linux, Chrome, dan web-server; Android emulator tidak tersedia. Firebase telah dikonfigurasi, tetapi tidak ada akun demo yang disediakan. Screenshot 02 mensimulasikan area yang menyusut dengan mengubah tinggi viewport; screenshot tersebut bukan bukti keyboard sistem operasi. Tidak ada audit otomatis aksesibilitas yang dijalankan. Karena batas ini, status FAIL/parsial di atas tidak boleh dianggap sebagai validasi lengkap.
