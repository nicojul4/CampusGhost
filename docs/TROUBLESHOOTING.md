# Troubleshooting

Contoh log di bawah berasal dari verifikasi atau merupakan gejala umum stack ini. Contoh disanitasi; jangan mengganti placeholder dengan data akun saat mengirim laporan.

| Gejala/log tersanitasi | Penyebab | Perbaikan | Pencegahan |
| --- | --- | --- | --- |
| `Read-only file system` saat Flutter menulis cache SDK. | SDK berada di lokasi yang tidak dapat ditulis oleh user/proses. | Gunakan instalasi Flutter pada direktori milik user yang writable, lalu jalankan `flutter doctor -v` dan ulangi `flutter pub get`. | Jangan letakkan cache SDK pada mount read-only; pastikan pemilik direktori SDK sesuai user. |
| `getaddrinfo EAI_AGAIN registry.npmjs.org` saat `npm audit`. | DNS atau akses registry tidak tersedia dari lingkungan proses. | Pulihkan DNS/jaringan, lalu ulangi `npm audit --json`. Untuk install, ulangi `npm ci` setelah registry dapat dijangkau. | Pastikan proxy/DNS perusahaan mengizinkan registry npm; jangan menyalin token registry ke log. |
| `listen EPERM ... 127.0.0.1:3000`. | Sandbox atau kebijakan lokal menolak pembukaan socket. | Jalankan proses pada lingkungan yang mengizinkan loopback; pastikan `HOST=127.0.0.1`, lalu ulangi `node server.js`. | Batasi izin yang dibutuhkan dan bind hanya ke loopback untuk demo lokal. |
| `Address already in use ... 127.0.0.1:8080` atau port deploy. | Port telah dipakai proses lain. | Pilih port kosong, misalnya `flutter run -d web-server --web-port 8082 --web-hostname 127.0.0.1`; sesuaikan `CORS_ORIGINS` bila origin app berubah. | Periksa port sebelum start dan hentikan hanya proses yang memang milik sesi sendiri. |
| `403 Origin tidak diizinkan` dari API. | Origin browser tidak ada di allowlist CORS API. | Start API dengan nilai yang sesuai, misalnya `CORS_ORIGINS=http://127.0.0.1:8080 node server.js` dari direktori `server`. | Pertahankan allowlist sempit; jangan menggunakan wildcard untuk API lokal. |
| `413 Ukuran request melebihi batas.` | JSON request lebih besar dari batas 1 MiB. | Kompresi/perkecil payload atau foto sebelum mengirim; batas API tidak dinaikkan otomatis. | Resize foto di client dan kirim metadata minimum. |
| Flutter web build menampilkan `dart:html unsupported` dari `flutter_secure_storage_web` pada pemeriksaan Wasm. | Dependency web tersebut belum kompatibel dengan target Wasm. | Build web normal tetap berhasil pada verifikasi ini. Jika proyek beralih ke Wasm, upgrade/ganti dependency web dan verifikasi kembali sebelum mengaktifkan target itu. | Catat kompatibilitas plugin sebelum mengubah target compiler Flutter Web. |

## Log aman

### Boleh dicatat

- Waktu UTC, nama tool/versi, command tanpa credential, exit code, status HTTP, jumlah test, dan ringkasan error yang sudah dinormalisasi.
- Route tanpa query sensitif, kategori error, durasi, dan request/correlation ID acak yang tidak mengandung UID.
- Contoh data fiktif yang jelas ditandai sebagai contoh.

### Jangan dicatat

- Password, token sesi/bearer, cookie, API key, service-account JSON, private key, atau isi file `.env`.
- Email, nama lengkap, UID Firebase, alamat/IP publik, nomor telepon, atau pengenal perangkat.
- Deskripsi laporan asli, URL foto, lokasi presisi pengguna, payload request mentah, dan response autentikasi.

### Memeriksa log

1. Jangan menyalin log mentah ke issue, chat, atau dokumen handover. Buat salinan kerja lokal yang aksesnya terbatas.
2. Redaksi nilai sensitif menjadi `[REDACTED]` sebelum berbagi; pertahankan nama field hanya bila perlu.
3. Jalankan scanner dengan redaksi penuh, misalnya `gitleaks git --log-opts=--all --redact=100`, dan jangan memakai output yang menampilkan nilai temuan.
4. Untuk TruffleHog, gunakan output JSON hanya melalui pemroses lokal yang membuang `Raw`/`RawV2`; jangan mencetak objek hasil mentah.
5. Periksa staging dan diff Git dengan `git status --short` dan `git diff --cached --check` sebelum commit. Jangan men-stage `.env`, log, cache browser, atau database demo yang berisi data nyata.
