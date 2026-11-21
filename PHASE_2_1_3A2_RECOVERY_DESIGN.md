# Phase 2.1.3-A.2 — Role Transition & Recovery Design

## 1. Temuan berdasarkan kode aktual

Audit membaca `functions/src/user_management.ts`, `functions/src/security_helpers.ts`, `functions/src/types.ts`, `functions/src/auth_triggers.ts`, `functions/src/index.ts`, serta `scripts/seed-admin.js`. Tidak ada kode yang diubah untuk tahap desain ini.

### Role transition dan counter

- `ensureRoleControl` membuat `system/role_control` secara transaksional dari query profil Admin aktif saat dokumen belum ada. Ia tidak merekonsiliasi counter yang sudah ada; pemeriksaan mismatch dilakukan oleh `runAdminCounterTransaction` untuk perubahan yang bukan no-op.
- `runAdminCounterTransaction` membaca kontrol, target, dan aktor di transaksi. Ia menghitung Admin aktif aktual, menolak mismatch counter, menghitung delta dari role/status terkini, menolak pengurangan menjadi nol, lalu menulis counter dan profil pending secara atomik.
- Untuk perubahan counter, transaksi menulis `role_control`, sehingga concurrent promotion/demotion/deactivation/reactivation yang melalui fungsi ini bersaing pada dokumen kontrol dan Firestore dapat mengulang transaksi konflik. Untuk delta nol, kontrol tidak ditulis; dokumen aktor dan target tetap dibaca, sementara perubahan role yang memengaruhi hitungan selalu memiliki delta bukan nol.
- Tidak semua perubahan Admin tertangkap oleh mekanisme ini jika ada writer Admin SDK lain, operasi manual, atau seed lama di luar jalur ini. Mismatch kemudian menghentikan perubahan ber-counter, tetapi perbaikan tidak otomatis.
- Setelah commit, profil memuat role/status tujuan serta `roleTransitionStatus: pending` dan `claimsOutOfSync: true`. Counter dan profil sudah berubah bersama sebelum Auth diperbarui.
- `applyPendingRoleTransition` membaca pending profile, menulis Custom Claims (dengan mempertahankan field klaim lain), mengubah `disabled`, lalu memanggil `completeRoleTransition`. Ia tidak mengunci atau memverifikasi versi/ID transisi sebelum finalisasi.
- `completeRoleTransition` menandai provisioning selesai dan menghapus marker pending secara unconditional. Tidak ada compare-and-set terhadap ID transisi atau `roleVersion`; stale recovery dapat memfinalisasi record yang telah berubah bila ada writer lain yang melewati invariant pending.
- `reconcileRoleTransition` memerlukan `requireFreshToken` dan `requireAdmin` dari aktor. Karena helper fresh menolak profil pending/tidak sinkron, target tidak dapat memulihkan dirinya. Jika tidak ada Admin lain yang lolos fresh authorization, tidak ada pemanggil callable yang dapat memulihkan transisi.
- Admin yang menginisiasi operasi divalidasi kembali dari profil di transaksi. Custom Claims dan profile dipakai sebagai batas akses melalui `requireFreshToken`, tetapi `roleVersion` belum menjadi bagian klaim atau syarat otorisasi.
- Self-demotion dan self-deactivation ditolak pada callable masing-masing. Last Admin guard untuk target tetap berada pada transaksi, bukan hanya preliminary read.

### Custom Claims dan token

- `requireFreshToken` memeriksa pencabutan token, status disabled Auth, `isActive` pada token, lalu mensyaratkan profil ada, provisioning `completed`, tidak out-of-sync/pending, role sama dengan token, dan profile aktif.
- Helper tidak membandingkan versi role. Perubahan role yang kembali ke nilai lama (ABA) mengandalkan refresh-token revocation, bukan epoch yang diverifikasi pada setiap privileged call.
- `applyPendingRoleTransition` menggabungkan `record.customClaims` dengan role/isActive baru. Sebaliknya, `createTechnician` dan `seed-admin.js` menulis object tiga claim secara langsung; claim lain yang tidak terkait dapat terhapus.
- `roleVersion` meningkat pada role transition dan seed, tetapi tidak ditulis ke Custom Claims dan tidak dibaca `requireFreshToken`. Field itu saat ini belum menambah perlindungan stale-token.
- Selama status pending/out-of-sync tersimpan benar, Claims yang lebih berhak tidak memberi akses melalui callable yang menggunakan `requireFreshToken`. Jaminan ini tidak otomatis mencakup fungsi yang tidak memanggil helper tersebut atau client yang memakai klaim langsung untuk tampilan/UX.

### Seed Admin

- Seed menghitung profil Admin aktif dalam transaksi bersama update profil dan counter. Dokumen kontrol ditulis sekalipun delta nol, sehingga seed bersaing dengan role transition yang memakai dokumen kontrol.
- Counter yang ada harus sama dengan query aktual; jika tidak, seed berhenti. Dokumen yang hilang dibuat dengan jumlah aktual ditambah delta target. Ini menghindari overwrite diam-diam, tetapi prosedur rekonsiliasi mismatch masih manual.
- Seed menandai profil Admin pending sebelum menulis Auth Claims. Jika Auth/finalization gagal, rerun menerima pending state yang cocok sebagai recoverable dan delta dihitung nol karena profil sudah menunjukkan Admin aktif. Counter tidak naik dua kali.
- Dua seed bersamaan terhadap target yang sama dapat sama-sama menerima pending state yang cocok; keduanya menaikkan `roleVersion` dan menjalankan Claims/finalization, tetapi tidak menggunakan transition ID atau CAS. Klaim yang ditulis seed juga mengganti seluruh klaim lain.
- Seed lokal memakai service account (syarat operasi yang disebutkan di header script), bukan callable. Tidak ada kontrol runtime di aplikasi yang dapat membatasi siapa yang memiliki kredensial tersebut. Kredensial tidak diakses selama audit ini.

### Technician provisioning

- `createTechnician` membuat Auth user, kemudian profile `claims_pending`, lalu menulis klaim `technician`, kemudian mengubah profile ke `completed`.
- Jika create profile gagal, fungsi mencoba `deleteUser`. Jika rollback itu juga gagal, ia hanya menulis log `ORPHANED_AUTH_ACCOUNT`; tidak ada journal persisten atau reconciler yang mencari akun tersebut.
- Jika Claims gagal setelah profile dibuat, profile ditandai `claimsOutOfSync`, sehingga helper fresh menolak akun; tidak ada endpoint/job yang menyelesaikan provisioning secara otomatis.
- Jika Claims berhasil tetapi update final profile gagal, catch menjalankan `markClaimsOutOfSync`. Profile tetap tidak dapat digunakan lewat privileged callable, tetapi recovery belum disediakan. Pemanggilan profile-create trigger mengabaikan status `claims_pending`; trigger itu bukan reconciler.
- Trigger mahasiswa dapat menandai provisioning `failed`, tetapi tidak ada mekanisme retry terjadwal/eksplisit yang ditinjau pada file ini. Permintaan register Flutter yang gagal menulis profile juga tidak memiliki journal backend untuk menghubungkan Auth user yatim ke retry server-side.

## 2. Root cause

| Area | Root cause |
| --- | --- |
| Single-admin recovery | Satu-satunya recovery callable memakai otorisasi yang sengaja menolak profil pending; pemulihan bergantung pada Admin sehat lain. |
| Finalization race | Pending record tidak memiliki transition ID/expected version; finalizer menghapus pending tanpa transaksi compare-and-set. |
| Claim integrity | Penulis Claims tidak memakai satu helper; seed/teknisi mengganti seluruh claims map, sedangkan role transition menggabungkannya. |
| Stale token/ABA | `roleVersion` hanya ada di Firestore dan tidak ikut dibandingkan pada authorization. |
| Technician orphan | Auth creation terjadi sebelum ada provisioning journal yang dapat di-query; kegagalan rollback hanya dicatat. |
| Technician recovery | Tidak ada reconciler idempotent untuk state `claims_pending`, `claimsOutOfSync`, `failed`, atau Auth orphan. |
| Counter repair | Perbedaan counter sengaja menghentikan transaksi, tetapi jalur rekonsiliasi operator yang tercatat/audited belum tersedia. |

## 3. Skenario kegagalan dan dampaknya

1. **Transaksi Firestore gagal sebelum commit:** Auth belum disentuh; tidak ada transition yang harus dilanjutkan.
2. **Transaksi commit, Auth Claims gagal:** profile+counter sudah mencerminkan intent dan profile tetap pending; target ditolak. Admin sehat lain dapat memanggil recovery saat ini.
3. **Claims berhasil, account disable/enable gagal:** profile tetap pending; target ditolak. Recovery mengulang write Claims dan disabled state.
4. **Claims dan disabled berhasil, finalisasi Firestore gagal:** profile masih pending; target ditolak meski token baru mungkin membawa role tujuan. Recovery harus mengulang idempotently.
5. **Satu-satunya Admin tidak dapat lolos fresh authorization:** callable recovery terkunci. Jalur aman harus memakai backend service identity, bukan memberi pengecualian bagi Student/Technician.
6. **Auth teknisi dibuat, profile gagal, delete gagal:** Auth user tidak punya journal profile dan hanya ada log. Tidak ada cleanup/recovery terotomasi.
7. **Profile teknisi dibuat, Claims gagal:** pending/inconsistent profile seharusnya menolak akses; tanpa reconciler, akun tertahan.
8. **Claims teknisi berhasil, finalisasi gagal:** profile tetap pending/out-of-sync; retry aman secara konseptual tetapi belum tersedia. Trigger create tidak akan memperbaiki profile `claims_pending`.
9. **Seed Auth berhasil tetapi finalisasi gagal:** profile pending tetap mengunci akses. Rerun saat ini dapat melanjutkan count tanpa delta ganda, tetapi mengganti claims lain dan dapat beradu finalisasi dengan seed lain.
10. **Counter tidak cocok dengan profile:** perubahan role berhenti; seed juga berhenti bila dokumen counter ada. Ini fail-closed, tetapi perlu prosedur rekonsiliasi terkontrol.

## 4. Rancangan solusi

### A. Satu model transition untuk Admin dan Technician

Gunakan field backend-only yang konsisten pada profile:

- `provisioningStatus`: `pending`, `completed`, `failed`.
- `roleTransitionStatus`: `pending`, `completed`.
- `transitionId`: UUID unik per intent.
- `transitionStartedAt` dan `transitionAttemptCount` untuk operasi/monitoring.
- `pendingRole`, `pendingIsActive`, `pendingRoleVersion` sebagai state tujuan yang ditetapkan backend.
- `roleVersion` sebagai epoch otoritatif, dinaikkan tepat sekali pada transaksi intent.

Fungsi awal melakukan satu transaksi Firestore: validasi counter aktual dan profil, hitung delta, tulis target state pending/version/ID, dan update counter. Counter dan profil tetap atomik. Retry pada operation ID yang sama mengembalikan transition yang ada tanpa mengulang delta. Request baru terhadap target pending ditolak.

Finalizer membaca pending record, memverifikasi ID dan versi, menggabungkan claims yang tidak terkait, lalu menulis `{role, isActive, roleVersion}`. Setelah Auth mengonfirmasi write dan disabled state sesuai, finalisasi Firestore berjalan dalam transaksi dengan precondition bahwa ID/versi/status masih persis sama. Finalisasi tidak mengubah counter.

### B. Recovery Admin tanpa membuka privilege ke client

Jangan menambahkan pengecualian di `requireFreshToken`, `requireAdmin`, atau endpoint pemulihan untuk role Student/Technician.

1. Pertahankan callable Admin untuk kasus normal saat masih ada Admin lain yang sehat. Ia wajib menjalankan `requireFreshToken`/`requireAdmin` dan hanya boleh menyelesaikan `transitionId` yang cocok.
2. Tambahkan scheduled/internal reconciler dengan service account Cloud Functions. Ia query pending transition yang melewati lease/timeout, validasi bentuk dan versi transition backend, lalu menjalankan finalizer idempotent. Callable tidak diekspos sebagai public recovery bypass.
3. Untuk kasus tidak dapat diputuskan otomatis (counter mismatch, record rusak, Auth user tidak ditemukan, atau desired state bertentangan), reconciler menahan status dan mengeluarkan log/metric operasional tanpa menaikkan role. Operator memerlukan proses break-glass yang dibatasi IAM dan diaudit untuk memperbaiki data; tidak ada endpoint berbasis klaim Student/Technician.
4. Saat Claims berhasil namun finalisasi gagal, scheduler mengulang write dengan ID/versi yang sama lalu CAS finalization. Saat transaksi Firestore gagal, tidak ada pending record dan Auth belum disentuh. Token Admin lama yang dicabut/invalid tidak menghambat scheduler; pemanggil callable manusia perlu login ulang dan tetap harus Admin sehat.
5. Reconciler hanya mempercayai pending intent backend-only. Field ini harus dilarang dari client Rules (sudah ada larangan umum untuk beberapa field; perubahan Rules tidak menjadi bagian pekerjaan ini tanpa audit terpisah). Ia tidak boleh menebak role dari Auth Claims.

Scheduled reconciler adalah pemilik recovery jika Admin tunggal tertahan. Batas kepercayaannya adalah service account fungsi + dokumen intent yang hanya dapat ditulis Admin SDK. Scheduler tidak boleh punya callable parameter yang membolehkan peminta memilih role atau isActive.

### C. Technician provisioning dan orphan cleanup

Gunakan journal `system/provisioning/{operationId}` yang hanya backend dapat tulis, berisi jenis akun, email ternormalisasi, state, UID (setelah diketahui), transition ID, dan timestamp. Jangan menyimpan password.

1. Buat journal `requested` terlebih dahulu; buat Auth user dengan UID yang dihasilkan backend dari operation ID (atau strategi idempotent lain yang menjamin satu intent tidak membuat akun ganda).
2. Segera catat UID dan state `auth_created`; tulis profile `pending` serta roleVersion/transitionId; baru tulis Custom Claims dengan helper merge; finalisasi profile+journal secara CAS.
3. Retry operation ID yang sama melanjutkan stage terakhir dan tidak membuat Auth user/profile kedua.
4. Jika profile gagal, journal/UID tetap menunjuk akun Auth. Reconciler dapat mengulang profile write atau menandai cleanup tertunda. Penghapusan Auth hanya dilakukan setelah memastikan tidak ada profile aktif/role tepercaya dan intent memang gagal/expired; catat hasil delete. Jika delete gagal, retry dan alert melalui journal.
5. Jika crash tepat setelah create Auth sebelum UID tercatat, UID deterministik dari operation ID menghilangkan lookup ambigu. Validasi bahwa format UID memenuhi batas Firebase Auth.
6. Trigger `onUserProfileCreate` tetap tidak menetapkan role dari profile yang tidak tepercaya. Untuk profile managed `pending`, trigger no-op; journal reconciler mengurus completion. Student tetap memperoleh role student hanya lewat jalur self-registration tepercaya.

### D. Custom Claims dan roleVersion

- Buat satu helper backend untuk merge Claims: baca claims saat ini, pertahankan key unrelated, timpa hanya role fields, `roleVersion`, dan metadata waktu. Validasi role/isActive dari intent server-side.
- Cantumkan `roleVersion` di token Claims dan profile. `requireFreshToken` mensyaratkan Claims role, active, dan version sama dengan profile completed. Version mismatch berarti tolak sampai refresh/recovery selesai.
- Tingkatkan version hanya dalam transaksi yang membuat intent. Recovery memakai version pending yang sama; tidak menaikkannya ulang.
- Jangan memakai `roleVersion` sebagai pengganti status pending. Keduanya harus diperiksa.
- Pertahankan `claimsOutOfSync`/pending sebagai deny condition. Pastikan setiap privileged callable memanggil pemeriksaan freshness sebelum otorisasi role. Auditi callable yang bukan user-management dalam tahap implementasi.
- Auth Custom Claims tidak menyediakan compare-and-set. Serialisasi semua penulis role untuk UID yang sama melalui pending transition; jangan izinkan seed, provisioning, scheduler, atau callable menulis Claims di luar helper/finalizer.

### E. Seed Admin

- Pertahankan transaksi bersama `role_control` dan hitung aktual dari profil aktif. Existing valid count hanya boleh berubah dengan delta transisi target yang dikunci transaksi; mismatch harus gagal dan menghasilkan instruksi rekonsiliasi, bukan overwrite.
- Tambahkan transition ID/operation ID deterministik atau input operation ID agar retry melanjutkan transition yang sama tanpa menaikkan version/counter kembali.
- Jika target sudah pending untuk seed operation yang sama, lanjutkan finalizer; jika pending dengan intent berbeda, berhenti.
- Gunakan helper Claims merge dan roleVersion sama dengan profile. Seed tidak boleh mengubah email/profile yang tidak perlu atau mem-bypass Last Admin invariant.
- Dua seed dan seed vs callable harus bersaing pada control doc dan target transition record; conflict/retry Firestore kemudian mengamati state baru. Jalankan tool hanya dari lingkungan operator dengan IAM terbatas dan audit log.
- Counter repair eksplisit dipisah dari seed: dry-run menampilkan actual/stored/mismatch; apply mensyaratkan operator break-glass, transaksi mengunci control doc dan menulis nilai hasil query; catat actor, alasan, dan sebelum/sesudah. Jangan otomatis memperbaiki mismatch saat seed berjalan.

## 5. File yang akan diubah saat implementasi

- `functions/src/user_management.ts`: transaction API, operation/transition IDs, CAS finalizer, shared Claims helper use, callable recovery guard, Technician saga integration.
- `functions/src/security_helpers.ts`: enforce `roleVersion` and completed/pending consistency for all privileged callables; maintain fail-closed checks.
- `functions/src/types.ts`: transition/journal types and Claims `roleVersion`.
- `functions/src/auth_triggers.ts`: ensure managed provisioning is safely recognized; avoid claiming completion without matching journal/claims version.
- `functions/src/index.ts`: export only the scheduled/internal reconciler and any protected Admin callable required by the design.
- `scripts/seed-admin.js`: operation-ID retry, transactional intent, merge Claims, explicit mismatch stop, audit output and documented operator preconditions.
- `functions/test/*`: emulator-backed Auth/Firestore role-transition, provisioning, recovery, concurrency and counter tests; pure tests for deterministic transition calculations only as supplementary coverage.
- Firebase Functions configuration/dependencies may need a scheduler trigger package/runtime config if not already present. Confirm current project SDK before choosing scheduled API.

No Firestore Rules change is proposed in this design because the report is a plan, not an implementation. Before coding, verify client Rules deny writes to every newly introduced journal/transition field.

## 6. Risiko regresi

- `roleVersion` Claims rollout makes existing tokens incompatible until refresh; introduce a migration path or accept a short forced reauthentication window, while keeping pending users denied.
- UID derived from operation ID must satisfy Firebase Auth UID limits and avoid collisions; operation IDs must be unguessable and unique.
- Scheduled retries can loop on persistent Auth/Firestore errors; use bounded backoff, attempt counters, alerts, and a terminal manual-review state without clearing pending.
- Profile query count and control doc are a serialization bottleneck. Keep transaction reads/writes bounded and test Firestore transaction/query limits under realistic account volume.
- Mismatch fail-closed behavior can block administration until operator reconciliation. Document and audit the break-glass process before rollout.
- Claims merge reads/writes are not atomic with Firestore or other independent claims writers. Restrict writers and serialize per UID; preserve unrelated claim ownership conventions.
- The existing Auth trigger and scheduled reconciler could race unless both enforce transition ID/version and the trigger ignores backend-managed journal states.
- Existing profiles may lack `roleVersion`, transition status, or provisioning status; migration defaults must not accidentally treat malformed privileged accounts as completed.

## 7. Required test cases

Tests below must run against Auth + Firestore Emulator for integration claims. A pure counter simulation is not evidence for transaction/concurrency behavior.

1. Last active Admin demotion and deactivation rejected; two Admins allow exactly one concurrent removal, leaving count one.
2. Concurrent student/technician promotions count once each; concurrent reactivation and promotion preserve exact profile count.
3. Counter missing initializes from actual profiles; valid count is preserved/reconciled by delta; malformed/mismatched count blocks all role changes and seed.
4. Firestore transaction abort leaves Auth Claims unchanged; counter/profile never partially commit.
5. Auth Claims failure leaves profile pending and all privileged callable access denied; retry completes without another counter delta.
6. Claims succeed/finalization fails: target remains denied; retry CAS finalizes once; stale transition ID/version cannot clear newer pending state.
7. Sole-Admin pending state is completed only by service-identity scheduler; unauthenticated, Student, and Technician callers cannot invoke recovery or choose elevated desired role.
8. Old token role/version mismatch rejected after role change, including role ABA; refreshed token accepted only after profile is completed and claims match.
9. Unrelated Claims survive role update, seed, Technician provisioning, and reconciliation.
10. Technician failure at Auth creation, profile write, Claims write, finalization, and Auth delete; each retry is idempotent and no orphan can gain access.
11. Two concurrent seed runs for same UID and different UIDs; seed vs role update/deactivation; counter does not double increment and Claims remain merged.
12. Trigger duplicate delivery and trigger/reconciler races leave managed Technician claims and profile role/version consistent.
13. Student attempts to write pending/journal/version fields remain denied by Rules tests.
14. Malformed pending record or missing Auth UID enters manual-review/fail-closed path without granting role.

## 8. Recommended implementation order

1. Add transition/journal types and specify backward-compatible handling for existing profiles/tokens.
2. Implement shared Claims merge/version helper and update `requireFreshToken` to compare complete profile state and roleVersion.
3. Refactor Admin transaction to persist transition ID/expected version and make counter changes idempotent per operation ID.
4. Implement CAS finalization and callable recovery for healthy Admin callers.
5. Add service-identity scheduled recovery for pending role transitions, with bounded retries and manual-review alerts; test sole-Admin recovery first.
6. Convert Technician provisioning to the same transition/journal lifecycle, then add retry/cleanup reconciliation for orphan states.
7. Refactor seed to use the shared operation/finalization path and Claims merge; keep counter mismatch repair as a separate audited operator action.
8. Add/extend Rules tests for every backend-only journal field without broadening Admin/Technician permissions.
9. Run TypeScript build, unit tests, Auth + Firestore Emulator integration tests, concurrency tests, and a dry-run against a non-production fixture. Review deployment/migration ordering; only then plan deployment separately.

## Verification status

This deliverable is an audit/design document only. No code was changed, no tests were run, no Firebase deployment occurred, no seed script was executed, and no credentials or service account files were accessed.
