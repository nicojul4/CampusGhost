# Security Report

- Tanggal audit: 2026-11-03 (UTC)
- Ruang lingkup: tracked source/configuration, seluruh riwayat Git, perubahan branch terhadap `origin/main`, dependency Functions, Firebase rules, dan local API.
- Runtime/tooling: Node.js 22.22.2, npm 11.6.2, Flutter 3.47.6, Dart 3.13.5, Gitleaks (binary tidak melaporkan nomor versi), TruffleHog `dev`.

## Ringkasan

| Tingkat | Jumlah/status |
| --- | --- |
| Critical | 0 terdeteksi. |
| High | 0 tersisa; 1 advisory `body-parser` High telah diperbaiki pada lockfile. |
| Moderate | 8 advisory dependency belum diperbaiki; 1 temuan scanner pada konfigurasi Firebase web lama menunggu verifikasi pembatasan API key. |

`flutter analyze` selesai tanpa isu. Semgrep tidak tersedia di lingkungan ini. Tidak ada temuan secret pada commit perubahan branch (`origin/main..HEAD`: Gitleaks 0).

## Hasil scan

| Tool | Cakupan dan hasil |
| --- | --- |
| `npm audit --json` | Functions dependency tree: 8 Moderate, 0 High, 0 Critical. Exit 1 karena advisory Moderate masih ada. Audit awal menemukan 1 High dan 10 Moderate; perbaikan kompatibel menghapus High dan 2 Moderate. |
| Gitleaks `git --log-opts=--all --redact=100` | 1 kandidat `gcp-api-key` pada konfigurasi Firebase web di commit lama. Nilai tidak disimpan dalam laporan ini. |
| TruffleHog `git ... --no-verification --json --no-update` | 1 deteksi Google API key yang sama, `Verified: false`, pada file/baris yang sama. |
| Gitleaks perubahan branch | `origin/main..HEAD`: tidak ada temuan pada perubahan branch. |
| Flutter analyzer | Tidak ada isu static analysis. Semgrep tidak terpasang. |

Scan working tree penuh di checkout awal juga membaca cache browser Flutter lokal yang diabaikan Git (`.dart_tool/chrome-device/**`) dan menghasilkan 1.316 kandidat pola API key/JWT. Cache tersebut bukan tracked source dan tidak masuk commit. Isi kandidat tidak disalin atau dicatat; pemilik lokal sebaiknya menghapus cache dengan prosedur Flutter bila tidak diperlukan. Scan archive tracked source menghasilkan kembali hanya satu kandidat Firebase yang dijelaskan di bawah.

## Temuan

| Severity | Lokasi | Deskripsi | Status | Tindakan/rekomendasi |
| --- | --- | --- | --- | --- |
| High (sebelum perbaikan) | `functions/package-lock.json` (`body-parser`) | npm audit menemukan versi rentan terhadap DoS pada request terkompresi. | Diperbaiki | Lockfile diperbarui ke `body-parser` 1.20.9 melalui `npm audit fix`; audit ulang: High 0. |
| High (sebelum perbaikan) | `server/server.js:7-14,72-93,129-145,193-203,211` | Demo API sebelumnya listen pada semua interface, mengizinkan semua origin, tidak membatasi body, mengizinkan reset tanpa guard production, dan mencetak objek error mentah. | Diperbaiki | Default bind loopback, allowlist CORS, limit body 1 MiB, reset dibalas 404 pada production, security headers, log error generik. Diverifikasi: allowed origin 200, origin asing 403, reset production 404, body >1 MiB 413. |
| Moderate | `functions/package-lock.json` (Firebase Admin dependency tree) | 8 advisory transitive tersisa, melibatkan `firebase-admin`, `@google-cloud/firestore`, `@google-cloud/storage`, `google-gax`, `gaxios`, `retry-request`, `teeny-request`, dan `uuid`. Fix yang dilaporkan npm memerlukan `firebase-admin` 14.5.0, perubahan major dari rentang saat ini. | Belum diperbaiki | Upgrade major dipisahkan agar kompatibilitas Cloud Functions dapat diuji dengan emulator/integrasi Firebase. Rekomendasi: upgrade dan jalankan pengujian emulator sebelum deploy. |
| Moderate / belum terverifikasi | `lib/config/firebase_options.dart:5` (juga konfigurasi platform lain) dan commit lama `9fd81be6` | Gitleaks dan TruffleHog mendeteksi nilai pada field konfigurasi Firebase web `apiKey`; TruffleHog tidak memverifikasinya. Nilai tidak disalin ke laporan. Konfigurasi client Firebase biasanya berisi identifier publik, tetapi pembatasan key pada Google Cloud tidak dapat diperiksa dari repo. | TIDAK TERVERIFIKASI | Pastikan key dibatasi untuk HTTP referrer dan API yang diperlukan di konsol Google Cloud/Firebase. Rotasi jika ternyata dipakai sebagai credential berprivilege. Tidak ada nilai key yang ditambahkan oleh branch ini. |
| Moderate / keputusan privasi | `firestore.rules:19-42`, `storage.rules` | Setiap pengguna terautentikasi dapat membaca report, incident, dan foto report. Ini mendukung tampilan kondisi kampus bersama, tetapi record memuat `UserId`, deskripsi, dan URL foto. | Belum diverifikasi terhadap kebijakan data | Pastikan deskripsi/foto tidak berisi data sensitif. Evaluasi redaksi atau pembatasan field/record sebelum memakai data nyata. Semantik produk tidak diubah pada handover ini. |
| Moderate / batas penggunaan | `server/server.js:7` | Local JSON API demo tidak memiliki autentikasi. Default sekarang loopback, tetapi operator dapat mengubah `HOST`; CORS bukan mekanisme autentikasi. | Dibatasi untuk local demo | Jangan expose API ke jaringan publik. Tambahkan autentikasi dan otorisasi sebelum penggunaan bersama/hosting. |

## Konfigurasi dan deployment

- `.env.example` hanya berisi nilai contoh lokal dan project ID placeholder; `.env` diabaikan Git.
- API demo memakai loopback default, allowlist browser lokal, security headers, dan payload maksimum 1 MiB.
- Firestore rules membatasi perubahan report ke user terautentikasi dan melarang update/delete report; baca bersama tetap diizinkan.
- Tidak ada Dockerfile atau Firebase Hosting target. Static demo lokal berhasil disajikan; deploy Firebase/staging dan pembatasan key cloud tidak terverifikasi.
- Tidak ada secret yang ditambahkan pada commit baru. Gitleaks branch scan bersih. Riwayat lama masih memiliki satu deteksi konfigurasi client Firebase yang belum dikonfirmasi sebagai credential.
