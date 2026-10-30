# Demo Campus Ghost (5–7 menit)

## Persiapan

- Jalankan aplikasi di perangkat Android dengan Firebase Authentication Email/Password aktif.
- Siapkan satu akun demo (jangan menyimpan password demo di repository) dan koneksi internet untuk autentikasi.
- Izinkan kamera dan lokasi untuk skenario utama. Siapkan akun kedua atau hapus laporan lama agar empty state mudah diperlihatkan.
- Data laporan disimpan lokal per akun di perangkat; dashboard menyebutkan batasan ini.

## Urutan demo (sekitar 6 menit)

1. **Autentikasi dan loading (45 detik).** Buka aplikasi, tunjukkan pemeriksaan sesi, lalu daftar atau login. Coba satu password salah untuk melihat pesan kredensial gagal; tekan masuk lagi dengan akun benar. Tutup/buka aplikasi untuk menunjukkan sesi Firebase dipulihkan.
2. **Dashboard, navigasi, dan empty state (45 detik).** Tunjukkan peta kondisi ilustratif, statistik, filter kategori, detail incident, dan bottom navigation Profil. Pada akun tanpa laporan, profil menampilkan empty state riwayat. Gunakan tombol Buat Laporan untuk kembali ke alur utama.
3. **Form dan validasi (60 detik).** Tekan simpan sebelum mengisi untuk melihat validasi kategori/deskripsi. Pilih lokasi, kategori Printer, masukkan deskripsi singkat untuk melihat validasi panjang minimum, lalu isi deskripsi valid. Foto wajib untuk kategori ini.
4. **Izin lokasi dan GPS (60 detik).** Tekan Ambil Koordinat GPS. Pada dialog sistem, tolak sekali: aplikasi menjelaskan izin dan menawarkan Coba Minta Ulang. Coba lagi lalu izinkan; koordinat tampil di form. Untuk uji penolakan permanen, reset izin aplikasi/deny berulang, ulangi permintaan, dan tunjukkan Buka Pengaturan serta opsi koordinat default. Matikan GPS untuk menampilkan pilihan pengaturan atau titik default. Izin GPS opsional untuk menyimpan laporan.
5. **Kamera, galeri, dan pembatalan (60 detik).** Ambil foto fasilitas via kamera, lihat preview, lalu ganti atau hapus foto. Buka kamera/galeri dan batalkan: form tetap terbuka tanpa crash atau perubahan foto. Tolak izin kamera untuk melihat penjelasan, Coba Lagi, dan Buka Pengaturan. Galeri juga dapat dipakai sebagai alternatif.
6. **Simpan dan detail (45 detik).** Simpan laporan. Tunjukkan indikator saat menyimpan, konfirmasi sukses, laporan muncul di riwayat, serta detail foto dan koordinat bila dipilih. Tutup paksa/buka lagi untuk menunjukkan persistensi lokal.
7. **Edit, hapus, logout (60 detik).** Dari Profil, edit deskripsi/status lalu simpan. Hapus dan pilih Batal untuk memastikan data tetap ada; ulangi dan konfirmasi Hapus untuk melihat empty state. Logout, coba buka route privat lewat `/dashboard` (kembali ke login), lalu login kembali.

## Skenario error tambahan

- Matikan koneksi saat login untuk melihat pesan gagal dan coba ulang setelah jaringan pulih.
- Matikan koneksi saat layar **Live API Reports** dibuka (jika backend demo tersedia) untuk melihat error dan tombol Coba Lagi. Vertical slice API ini terpisah dari CRUD laporan lokal.
- Untuk kegagalan penyimpanan lokal, gunakan perangkat dengan ruang penyimpanan rendah atau injeksi error storage pada test; UI menampilkan pesan gagal menyimpan.

Dialog izin dan GPS memerlukan perangkat/emulator dengan dukungan lokasi/kamera. Skenario di atas adalah langkah demo manual; status eksekusi perangkat dicatat pada `REVIEW_REPORT.md`.
