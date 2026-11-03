# Verification Log

Tanggal: 2026-11-03. Semua waktu berikut UTC. Verifikasi akhir dilakukan dari clone baru `/tmp/campusghost-handover-reviewed`, pada commit security fix `e46576b`, setelah clone sebelumnya dibuang dari alur. `git status` bersih sebelum install; tidak ada `node_modules`, `.dart_tool`, `build`, `vendor`, virtualenv, atau `.env` di clone. Hanya template `.env.example` yang tracked.

## Fresh clone, install, run, build, test, deploy

| Langkah | Perintah | Hasil / exit code | Waktu (UTC) | Catatan |
| --- | --- | --- | --- | --- |
| Clone bersih | `git clone --no-hardlinks --branch chore/handover-verification /home/nicolas/CampusGhost /tmp/campusghost-handover-reviewed` | PASS, 0 | 2026-11-03 03:01 | Clone lokal dari branch kerja; status awal bersih dan tidak membawa cache/dependency lama. |
| Install Flutter | `flutter pub get` | PASS, 0; `Got dependencies!` | 03:01:53 | 45 package memiliki versi baru yang tidak kompatibel dengan batas versi saat ini; lockfile tetap dipakai. |
| Install Functions | `npm ci` (working directory `functions/`) | PASS, 0; 253 package dipasang | 03:02:02 | npm menampilkan warning konfigurasi global dan deprecation dependency; tidak menggagalkan install. |
| Start API demo | `node server.js` (working directory `server/`) | Start PASS; health kemudian 200; dihentikan setelah cek | 03:02:10–03:03:24 | Bind default `127.0.0.1:3000`. Sesi dihentikan dengan Ctrl-C. |
| Start app | `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1` | PASS; Flutter menyatakan app disajikan pada `http://127.0.0.1:8080`; proses dihentikan dengan `q` | 03:02:19–03:03:24 | Startup pertama memerlukan sekitar 51 detik compile debug web. |
| HTTP app dan API | `curl --fail --silent --show-error --output /dev/null --write-out ...` ke `/` dan `/api/health`; request ketiga memakai origin asing | App 200 (1.585 byte), API health 200 (37 byte), origin asing 403 | 03:03:24 | Lolos dengan origin `http://127.0.0.1:8080`; origin tidak diizinkan ditolak. |
| Production build Flutter | `flutter build web --release` | PASS, 0; `Built build/web` | 03:03:52–03:05:19 | Build memberi warning kompatibilitas Wasm dari `flutter_secure_storage_web`; build web normal tetap dihasilkan. |
| Unit/widget tests | `flutter test --reporter expanded` | PASS: 30; FAIL: 0; SKIP: 0; runner: `All tests passed!`; exit 0 | 03:05:36–03:06:04 | Semua test yang ada dijalankan. Tidak ada test dihapus atau dilewati. |
| Static analysis | `flutter analyze` | PASS, 0; `No issues found!` | 03:06:09–03:06:13 | Flutter 3.47.6 / Dart 3.13.5. |
| Build Functions | `npm run build` (working directory `functions/`) | PASS, 0; TypeScript `tsc` selesai | 03:06:22–03:06:27 | Tidak ada test script Functions di `functions/package.json`. |
| Deploy demo lokal | `python3 -m http.server 18081 --bind 127.0.0.1 --directory build/web` | Start PASS; index 200 (1.585 byte), `main.dart.js` 200 (3.281.017 byte); server dihentikan dengan Ctrl-C | 03:06:33–03:06:45 | Static web release berhasil diakses di `http://127.0.0.1:18081`. Bukan deploy cloud. |

## Pemeriksaan tambahan dan percobaan yang gagal

| Langkah | Perintah | Hasil / exit code | Waktu (UTC) | Catatan |
| --- | --- | --- | --- | --- |
| Flutter SDK awal | `flutter --version` pada sandbox terbatas | FAIL, 1; SDK cache mendapat `Read-only file system` | 2026-11-03 | Diulang dengan izin tulis cache SDK; versi Flutter 3.47.6 / Dart 3.13.5 berhasil dibaca. |
| Audit registry awal | `npm audit --json` pada sandbox terbatas | FAIL, 1; DNS `EAI_AGAIN registry.npmjs.org` | 2026-11-03 | Diulang dengan akses registry; audit berjalan dan melaporkan advisories yang tercantum di Security Report. |
| Bind API awal | `node server.js` pada sandbox terbatas | FAIL, 1; `listen EPERM` | 2026-11-03 | Akses loopback diizinkan untuk retry; server lalu bind di loopback dan health check lulus. |
| Run app awal | `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1` | FAIL, 1; `Address already in use` | 2026-11-03 | Proses verifikasi sebelumnya masih menempati port. Proses tersebut dihentikan; rangkaian diulang dari clone bersih. |
| Deploy port awal | `python3 -m http.server 8081 --bind 127.0.0.1 --directory build/web` | FAIL, 1; port 8081 sudah dipakai | 2026-11-03 | Tidak menghentikan proses lain. Port kosong 18081 dipilih, lalu seluruh rangkaian A diulang dari clone bersih dan berhasil. |
| Proteksi API | Request lokal ke server production mode: health, reset, origin asing, payload 1 MiB + 1 byte | 200 + security headers; reset 404; origin asing 403; payload besar 413 | 2026-11-03 | Nilai request tidak disimpan; hanya status dan header aman yang dicatat. |

## Audit dan secret scanning

| Langkah | Perintah | Hasil / exit code | Waktu (UTC) | Catatan |
| --- | --- | --- | --- | --- |
| Dependency audit | `npm audit --json` | Exit 1 karena 8 Moderate; High 0; Critical 0 | 2026-11-03 | Registry dapat diakses saat retry. Rincian dan rekomendasi ada di [SECURITY_REPORT.md](SECURITY_REPORT.md). |
| Riwayat secret | `gitleaks git --log-opts=--all --redact=100 ...` | Exit 1; 17 commit dipindai, 1 kandidat historis | 2026-11-03 | Kandidat ada di Firebase client options lama; nilainya tidak dicatat. |
| Secret branch baru | `gitleaks git --log-opts=origin/main..HEAD --redact=100 ...` | PASS, 0; tidak ada leak | 2026-11-03 | Saat scan dilakukan branch memiliki 1 commit baru. Ulangi setelah commit dokumentasi sebelum merge. |
| Scan TruffleHog | `trufflehog git ... --no-verification --json --no-update` | Exit 0; 1 temuan, belum terverifikasi | 2026-11-03 | Detector menunjuk field konfigurasi Firebase web yang sama; output mentah tidak disimpan. |
| Source-only scan | `git archive HEAD` lalu `gitleaks dir --max-target-megabytes=10 --redact=100 ...` | Exit 1; 1 kandidat | 2026-11-03 | Hanya file tracked; kandidat sama dengan konfigurasi client Firebase lama. |

## Batas verifikasi

- **TIDAK TERVERIFIKASI:** Firebase Auth sign-up/login, baca/tulis cloud Firebase, dan pembatasan API key di konsol Google Cloud memerlukan proyek/akses yang tidak tersedia pada verifikasi lokal.
- **TIDAK TERVERIFIKASI:** Deploy Firebase/staging dan CI; tidak ada target Firebase Hosting, Dockerfile, atau workflow CI yang tracked. Demo release lokal melalui HTTP berhasil.
- Security scan direktori checkout awal menemukan banyak kandidat pada cache browser Flutter lokal yang diabaikan Git; rincian aman dan statusnya dijelaskan di [SECURITY_REPORT.md](SECURITY_REPORT.md).

## Replay README dari clone baru

Instruksi build/run/test/deploy README diikuti lagi dari clone lokal baru pada commit `a023e1f`, dengan hasil berikut. Clone ini tidak membawa cache atau dependency lama.

| Langkah | Perintah | Hasil / exit code | Waktu (UTC) | Catatan |
| --- | --- | --- | --- | --- |
| Clone perintah README | `git clone https://github.com/nicojul4/CampusGhost.git` | PASS, 0 | 2026-11-03 03:40 | Clone default remote berhasil anonim. Pada saat itu remote belum memuat branch handover. |
| Clone kode handover | `git clone --no-hardlinks --branch chore/handover-verification /home/nicolas/CampusGhost /tmp/campusghost-readme-final` | PASS, 0 | 2026-11-03 03:40 | Clone lokal branch; tidak ada cache/dependency. |
| Install README | `flutter pub get`, lalu `npm ci` dari `functions/` | PASS, 0 untuk keduanya | 03:40–03:41 | Dependency berhasil dibuat dari clone bersih. |
| Run README | `node server.js` dari `server/`; `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1` | PASS; app dan API start | 03:41–03:42 | Proses dihentikan setelah cek. |
| Cek HTTP README | Dua perintah `curl` README ke app dan API health | PASS; HTTP 200 (1.585 byte) dan HTTP 200 (37 byte) | 03:42 | Origin allowlisted. |
| Analyze/test README | `flutter analyze`; `flutter test --reporter expanded` | PASS; analyze 0 issue; tests PASS 30, FAIL 0, SKIP 0 | 03:43 | Semua test dijalankan. |
| Build README | `flutter build web --release`; `npm run build` dari `functions/` | PASS, 0 untuk keduanya | 03:44–03:46 | Warning Wasm sama seperti build awal; release web dan Functions build berhasil. |
| Deploy README | `python3 -m http.server 18081 --bind 127.0.0.1 --directory build/web`, lalu curl README | PASS; HTTP 200 (1.585 byte) | 03:46 | Deploy lokal release dapat diakses. |
| Push / PR | `git push -u origin chore/handover-verification` | TIDAK TERVERIFIKASI; exit 128, Git meminta username HTTPS tanpa perangkat input | 2026-11-03 | Remote branch clone juga gagal karena branch belum ada di remote. `gh` CLI tidak tersedia; PR belum dibuat. |
