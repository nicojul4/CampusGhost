# Campus Ghost 👻

> **Campus Ghost — Real-time map of campus problems and conditions**

## Ide Project

**Campus Ghost** adalah aplikasi mobile yang membantu mahasiswa melihat dan melaporkan **kondisi nyata fasilitas kampus secara real-time**, seperti Wi-Fi bermasalah, printer rusak, AC tidak nyaman, parkiran penuh, proyektor bermasalah, lift rusak, atau fasilitas lain yang sedang mengalami gangguan.

Konsep utamanya bukan menggantikan Google Maps, tetapi menjadi **"live condition map" untuk lingkungan kampus**.

> **Ide utama:** _"Apa yang sedang terjadi di kampus sekarang?"_

Aplikasi mengubah laporan mahasiswa menjadi informasi kondisi fasilitas yang mudah dipahami. Beberapa laporan yang berada pada lokasi dan masalah yang sama dapat dikelompokkan menjadi satu **incident** sehingga pengguna tidak perlu melihat banyak laporan yang sebenarnya membahas masalah yang sama.

---

# 1. Deskripsi Masalah

Di lingkungan kampus, masalah fasilitas sering terjadi tetapi informasi mengenai masalah tersebut tidak selalu tersebar dengan cepat.

Contohnya:

- Wi-Fi di lantai tertentu tidak dapat digunakan.
- Printer kampus sedang rusak.
- AC ruang kelas terlalu panas atau terlalu dingin.
- Parkiran sedang penuh.
- Proyektor kelas tidak berfungsi.
- Lift sedang tidak dapat digunakan.
- Toilet atau fasilitas umum sedang mengalami masalah.

Saat ini mahasiswa sering mengetahui masalah tersebut setelah datang langsung ke lokasi atau setelah bertanya kepada teman.

Hal tersebut menimbulkan masalah seperti:

1. Mahasiswa membuang waktu karena datang ke lokasi yang fasilitasnya sedang bermasalah.
2. Laporan masalah dapat berulang karena mahasiswa tidak mengetahui bahwa masalah tersebut sudah dilaporkan.
3. Informasi mengenai kondisi fasilitas tidak tersaji dalam satu tempat.
4. Pihak kampus berpotensi kesulitan melihat masalah fasilitas berdasarkan lokasi dan jumlah laporan.

### Solusi

Campus Ghost menyediakan **peta kondisi kampus secara real-time**.

Mahasiswa dapat:

`Lihat kondisi → Temukan masalah → Baca detail → Laporkan masalah`

Contoh:

```text
GEDUNG 1

Wi-Fi       🟡 Ada Gangguan
Parking     🔴 Penuh
Lift        🟢 Normal
AC          🟡 Bermasalah
Printer     🔴 Rusak
```

Apabila beberapa mahasiswa melaporkan masalah yang sama di lokasi yang sama, sistem dapat mengelompokkannya menjadi satu incident.

Contoh:

```text
INCIDENT DETECTED

Wi-Fi Gedung 1 Lantai 3

27 laporan
Status: Sedang terjadi
Terakhir diperbarui: 09:12
```

---

# 2. Profil Target Pengguna

## Target Utama — Mahasiswa

Mahasiswa merupakan pengguna utama Campus Ghost karena mereka paling sering berpindah lokasi di lingkungan kampus dan berinteraksi langsung dengan fasilitas kampus.

### Karakteristik

- Mahasiswa aktif.
- Sering menggunakan smartphone saat berada di kampus.
- Membutuhkan informasi fasilitas sebelum atau ketika berada di suatu lokasi.
- Ingin melaporkan masalah fasilitas dengan cepat.
- Membutuhkan informasi yang sederhana dan mudah dipahami.

### Contoh Persona

**Nama:** Nicolas  
**Status:** Mahasiswa  
**Situasi:** Akan mengerjakan tugas di kampus.

Nicolas ingin menggunakan Wi-Fi di lantai 3 Gedung 1. Sebelum menuju lantai tersebut, Nicolas membuka Campus Ghost.

Aplikasi menunjukkan:

```text
Wi-Fi Gedung 1 Lantai 3
🔴 Gangguan
27 laporan
```

Nicolas kemudian dapat memilih lokasi lain sehingga tidak membuang waktu.

---

## Target Sekunder — Pengelola Kampus

Dalam pengembangan berikutnya, data agregat Campus Ghost dapat membantu pihak kampus melihat:

- fasilitas yang sering bermasalah,
- lokasi dengan jumlah laporan tinggi,
- jenis masalah yang paling sering terjadi,
- incident yang belum selesai.

Untuk versi tugas 12 pertemuan, pengguna utama tetap **mahasiswa**.

---

# 3. Manfaat Aplikasi

## Bagi Mahasiswa

### Menghemat waktu

Mahasiswa dapat mengetahui kondisi fasilitas sebelum menuju lokasi.

### Mendapatkan informasi secara terpusat

Informasi mengenai gangguan fasilitas tidak perlu dicari melalui banyak grup chat.

### Mempermudah pelaporan

Mahasiswa dapat membuat laporan langsung dari smartphone.

### Meningkatkan kesadaran kondisi kampus

Pengguna dapat melihat masalah yang sedang terjadi di sekitar mereka.

## Bagi Kampus

Dalam pengembangan lebih lanjut, Campus Ghost dapat menjadi sumber data mengenai pola gangguan fasilitas berdasarkan:

```text
Lokasi
↓
Jenis masalah
↓
Jumlah laporan
↓
Frekuensi
↓
Prioritas penanganan
```

---

# 4. Daftar Fitur Inti

Fitur dipilih dengan mempertimbangkan bahwa project harus **realistis diselesaikan dalam 12 pertemuan**.

## 4.1 Campus Map

Menampilkan peta sederhana area kampus dengan lokasi fasilitas atau gedung.

```text
┌──────────────────────────┐
│       CAMPUS MAP         │
│                          │
│   🟢 Gedung 1            │
│                          │
│       🟡 Parking         │
│                          │
│   🔴 Gedung 2            │
│                          │
└──────────────────────────┘
```

## 4.2 Report Issue

Mahasiswa dapat membuat laporan masalah.

Data minimal:

```text
Lokasi
Kategori masalah
Deskripsi
Foto (opsional)
Waktu laporan
```

Kategori:

- Wi-Fi
- AC
- Printer
- Proyektor
- Lift
- Parkir
- Toilet
- Lainnya

## 4.3 Live Campus Status

Menampilkan kondisi fasilitas berdasarkan laporan terbaru.

```text
Gedung 1

Wi-Fi       🔴
AC          🟡
Printer     🔴
Lift        🟢
```

Status:

- 🟢 Normal
- 🟡 Ada gangguan
- 🔴 Bermasalah

## 4.4 Incident Grouping

Laporan dengan kategori dan lokasi yang sama dapat dikelompokkan.

```text
User A → Wi-Fi → Gedung 1 Lantai 3
User B → Wi-Fi → Gedung 1 Lantai 3
User C → Wi-Fi → Gedung 1 Lantai 3
```

Menjadi:

```text
Wi-Fi Gedung 1 Lantai 3

3 laporan
Status: Sedang bermasalah
```

Untuk MVP, pengelompokan menggunakan aturan sederhana berdasarkan:

`lokasi + kategori + rentang waktu`

Tidak perlu menggunakan AI.

## 4.5 Incident Detail

Pengguna dapat melihat detail sebuah incident.

```text
Wi-Fi Gedung 1 Lantai 3

Status
🔴 Sedang Bermasalah

Laporan
27

Terakhir diperbarui
09:12

Laporan terbaru:
"Wi-Fi tidak dapat terhubung."
```

## 4.6 Report Confirmation

Setelah pengguna mengirim laporan:

```text
✓ Laporan berhasil dibuat

Terima kasih telah membantu
memperbarui kondisi kampus.
```

## 4.7 Search & Filter

Pengguna dapat mencari atau menyaring masalah berdasarkan:

- Gedung
- Kategori
- Status

## 4.8 User Report History

Pengguna dapat melihat laporan yang pernah dibuat.

```text
My Reports

#001
Wi-Fi
Gedung 1 Lt. 3
Active

#002
Printer
Gedung 2 Lt. 1
Resolved
```

---

# 5. Fitur yang Tidak Dikerjakan

Agar project tetap realistis untuk **12 pertemuan**, fitur berikut sengaja tidak dimasukkan ke versi awal.

### 5.1 AI Automatic Incident Detection

Tidak membuat AI yang otomatis memahami dan mengelompokkan semua laporan.

Incident grouping pada MVP menggunakan aturan sederhana.

### 5.2 Integrasi Sistem Kampus

Tidak mengintegrasikan Campus Ghost dengan:

- sistem akademik,
- database fasilitas kampus,
- sistem maintenance,
- SSO kampus.

### 5.3 IoT Sensor

Tidak menggunakan sensor IoT untuk mendeteksi:

- suhu,
- kualitas udara,
- okupansi ruangan,
- kondisi jaringan secara otomatis.

Data MVP berasal dari laporan pengguna.

### 5.4 Real-time Push Notification Kompleks

Notifikasi massal dan sistem alert yang kompleks tidak menjadi fitur utama MVP.

### 5.5 Admin Dashboard

Dashboard khusus pihak kampus tidak dibuat pada versi tugas awal.

### 5.6 Sistem Pengaduan Resmi

Campus Ghost bukan pengganti sistem pengaduan resmi kampus.

Aplikasi berfungsi sebagai **platform informasi kondisi dan crowdsourced reporting**.

### 5.7 Gamification

Leaderboard, badge, reward, dan sistem poin tidak menjadi prioritas MVP.

---

# 6. Kriteria Aplikasi Dinyatakan Berhasil

Campus Ghost dinyatakan berhasil apabila pengguna dapat menyelesaikan alur utama berikut:

```text
Buka aplikasi
      ↓
Melihat peta / kondisi kampus
      ↓
Memilih lokasi
      ↓
Melihat incident
      ↓
Membuat laporan masalah
      ↓
Laporan tersimpan
      ↓
Incident diperbarui
      ↓
Pengguna lain dapat melihat perubahan
```

## Kriteria Fungsional

Aplikasi berhasil apabila:

- Pengguna dapat melihat lokasi atau fasilitas kampus.
- Pengguna dapat melihat status fasilitas.
- Pengguna dapat membuat laporan masalah.
- Data laporan tersimpan dengan benar.
- Pengguna dapat melihat detail laporan/incident.
- Laporan dengan lokasi dan kategori yang sama dapat dikelompokkan menggunakan aturan MVP.
- Pengguna dapat melihat riwayat laporan mereka.
- Pengguna dapat melakukan pencarian/filter.
- Aplikasi dapat berjalan dengan baik pada smartphone Android target.

## Kriteria Pengalaman Pengguna

Aplikasi dianggap berhasil apabila pengguna baru dapat:

> **Membuka aplikasi → menemukan masalah di suatu lokasi → memahami statusnya → membuat laporan**

tanpa membutuhkan tutorial khusus.

## Indikator Keberhasilan Project

Untuk demonstrasi tugas, minimal terdapat simulasi beberapa laporan sehingga terlihat perubahan kondisi.

Contoh:

```text
Sebelum:

Wi-Fi Gedung 1 Lt. 3
🟢 Normal


User 1 membuat laporan
        ↓
Wi-Fi bermasalah


User 2 membuat laporan
        ↓
Incident diperbarui


Setelah:

Wi-Fi Gedung 1 Lt. 3
🔴 Bermasalah

2 laporan aktif
```

---

# Scope MVP 12 Pertemuan

Agar project tidak terlalu besar, versi pertama Campus Ghost hanya berfokus pada:

```text
┌──────────────────────────────┐
│        CAMPUS GHOST          │
├──────────────────────────────┤
│                              │
│        Campus Map            │
│             ↓                │
│       Location Detail        │
│             ↓                │
│       Live Incidents         │
│             ↓                │
│       Report Issue           │
│             ↓                │
│       Incident Grouping      │
│             ↓                │
│        Status Update         │
│                              │
└──────────────────────────────┘
```

Fokus project bukan membuat sistem kampus yang sangat kompleks, tetapi membuktikan konsep:

> **Mahasiswa dapat melihat dan membagikan kondisi fasilitas kampus secara terpusat melalui aplikasi mobile.**

---

# Kesimpulan

**Campus Ghost** merupakan aplikasi mobile berbasis crowdsourcing yang mengubah laporan mahasiswa menjadi **peta kondisi kampus secara real-time**.

Masalah utama yang diselesaikan adalah:

> **Mahasiswa sering tidak mengetahui kondisi fasilitas kampus sebelum datang ke lokasi.**

Solusi yang diberikan:

> **Satu aplikasi untuk melihat kondisi fasilitas, menemukan incident, dan melaporkan masalah yang sedang terjadi.**

Nilai unik project:

> **"Bukan sekadar peta kampus, tetapi peta kondisi kampus saat ini."**

---

# Tech Stack

## Framework — Flutter (Dart)

Campus Ghost menggunakan **Flutter** sebagai framework utama untuk pengembangan aplikasi mobile.

### Alasan Pemilihan Flutter

| Aspek                     | Penjelasan                                                                                      |
| ------------------------- | ----------------------------------------------------------------------------------------------- |
| **Cross-platform**        | Satu codebase untuk Android dan iOS. Efisien untuk project 12 pertemuan.                        |
| **UI yang fleksibel**     | Widget system Flutter sangat cocok untuk membuat custom map, card, dan komponen visual lainnya. |
| **Performa**              | Flutter mengompilasi ke native code, sehingga performa mendekati aplikasi native.               |
| **Hot Reload**            | Mempercepat proses development — perubahan langsung terlihat tanpa restart aplikasi.            |
| **Ekosistem & komunitas** | Banyak package yang mendukung (maps, state management, Firebase integration).                   |
| **Mudah dipelajari**      | Dart relatif mudah dipahami, terutama bagi yang sudah familiar dengan JavaScript atau Java.     |

### Versi & Tools

```text
Flutter SDK     : Latest stable (3.x)
Dart SDK        : Latest stable (3.x)
IDE             : Android Studio / VS Code
Min Android SDK : 21 (Android 5.0)
```

### Package Utama yang Direncanakan

```text
flutter_map / google_maps_flutter   → Peta kampus
firebase_core                       → Koneksi Firebase
cloud_firestore                     → Database real-time
firebase_auth                       → Autentikasi pengguna
firebase_storage                    → Upload foto laporan
provider / riverpod                 → State management
image_picker                        → Ambil foto dari kamera/galeri
geolocator                          → Lokasi pengguna (opsional)
```

---

## Backend — Firebase (Google)

Campus Ghost menggunakan **Firebase** sebagai backend utama.

### Alasan Pemilihan Firebase

| Aspek                       | Penjelasan                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| **Real-time Database**      | Cloud Firestore mendukung sinkronisasi data secara real-time — cocok untuk live campus status. |
| **Tanpa server management** | Firebase adalah Backend-as-a-Service (BaaS), tidak perlu setup dan maintain server sendiri.    |
| **Autentikasi mudah**       | Firebase Auth mendukung email/password dan Google Sign-In.                                     |
| **Cloud Storage**           | Untuk menyimpan foto laporan dari pengguna.                                                    |
| **Free tier cukup**         | Spark plan (gratis) sudah cukup untuk skala MVP dan demonstrasi.                               |
| **Integrasi Flutter**       | FlutterFire menyediakan plugin resmi dengan dokumentasi lengkap.                               |
| **Cepat di-setup**          | Cocok untuk timeline 12 pertemuan — tidak perlu banyak waktu untuk konfigurasi backend.        |

### Layanan Firebase yang Digunakan

```text
┌─────────────────────────────────────────┐
│            FIREBASE SERVICES            │
├─────────────────────────────────────────┤
│                                         │
│  Cloud Firestore    → Database utama    │
│                       (reports,         │
│                        incidents,       │
│                        locations)       │
│                                         │
│  Firebase Auth      → Login pengguna    │
│                       (email/password,  │
│                        Google Sign-In)  │
│                                         │
│  Cloud Storage      → Simpan foto      │
│                       laporan           │
│                                         │
│  Firebase Hosting   → (Opsional)        │
│                       Web dashboard     │
│                                         │
└─────────────────────────────────────────┘
```

### Struktur Data Firestore (Rencana)

```text
users/
  └── {userId}
        ├── name
        ├── email
        └── createdAt

locations/
  └── {locationId}
        ├── name          → "Gedung 1 Lantai 3"
        ├── building      → "Gedung 1"
        ├── floor         → 3
        ├── latitude
        └── longitude

reports/
  └── {reportId}
        ├── userId
        ├── locationId
        ├── category      → "wifi" | "ac" | "printer" | ...
        ├── description
        ├── photoUrl
        ├── status        → "active" | "resolved"
        ├── createdAt
        └── incidentId

incidents/
  └── {incidentId}
        ├── locationId
        ├── category
        ├── reportCount
        ├── status        → "active" | "resolved"
        ├── lastUpdated
        └── firstReported
```

---

## Arsitektur Aplikasi

```text
┌─────────────────────────────────────┐
│           CAMPUS GHOST              │
│         (Flutter App)               │
├─────────────────────────────────────┤
│                                     │
│  ┌───────────┐    ┌──────────────┐  │
│  │    UI      │    │   State      │  │
│  │  (Widgets) │◄──►│  Management  │  │
│  │            │    │  (Provider/  │  │
│  │            │    │   Riverpod)  │  │
│  └───────────┘    └──────┬───────┘  │
│                          │          │
│                 ┌────────▼───────┐  │
│                 │   Repository   │  │
│                 │     Layer      │  │
│                 └────────┬───────┘  │
│                          │          │
├──────────────────────────┼──────────┤
│                          │          │
│  ┌───────────────────────▼───────┐  │
│  │         FIREBASE              │  │
│  │                               │  │
│  │  Firestore  Auth  Storage     │  │
│  └───────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

---

## Desain UI/UX

Desain UI/UX untuk Campus Ghost **dibuat dari awal** tanpa menggunakan desain Figma yang sudah ada sebelumnya.

### Pendekatan Desain

```text
Pertemuan 2-3    → Wireframe sederhana (sketsa layout utama)
Pertemuan 3-4    → Implementasi UI dasar di Flutter
Pertemuan 5+     → Iterasi dan perbaikan UI berdasarkan progress
```

### Prinsip Desain

- **Sederhana dan intuitif** — Pengguna baru harus bisa langsung paham tanpa tutorial.
- **Informasi cepat terlihat** — Status fasilitas (🟢🟡🔴) harus terlihat dalam 1-2 detik.
- **Mobile-first** — Semua komponen dirancang untuk layar smartphone.
- **Konsisten** — Warna, ikon, dan layout mengikuti design system yang sama.

### Halaman Utama yang Akan Dibuat

```text
1. Splash Screen        → Logo dan loading
2. Login / Register     → Autentikasi pengguna
3. Home (Campus Map)    → Peta kampus dengan status
4. Location Detail      → Detail fasilitas di lokasi tertentu
5. Incident Detail      → Detail incident dengan daftar laporan
6. Create Report        → Form buat laporan baru
7. Report Confirmation  → Konfirmasi laporan berhasil
8. My Reports           → Riwayat laporan pengguna
9. Search & Filter      → Pencarian dan filter masalah
```

---

# Timeline Project — 12 Pertemuan

## Status: Pertemuan 2 dari 12

```text
[██░░░░░░░░░░] 2/12
```

### Rencana Per Pertemuan

| Pertemuan | Fokus                                                         | Status             |
| --------- | ------------------------------------------------------------- | ------------------ |
| 1         | Ide project, deskripsi masalah, README awal                   | ✅ Selesai         |
| 2         | Tech stack, setup project Flutter + Firebase, struktur folder | 🔄 Sedang berjalan |
| 3         | Autentikasi (Login/Register) + Setup Firestore                | ⬜ Belum           |
| 4         | Campus Map — UI peta kampus dengan lokasi                     | ⬜ Belum           |
| 5         | Location Detail — Status fasilitas per lokasi                 | ⬜ Belum           |
| 6         | Report Issue — Form laporan masalah                           | ⬜ Belum           |
| 7         | Incident Grouping — Logika pengelompokan laporan              | ⬜ Belum           |
| 8         | Incident Detail — Halaman detail incident                     | ⬜ Belum           |
| 9         | User Report History — Riwayat laporan                         | ⬜ Belum           |
| 10        | Search & Filter + Live Campus Status                          | ⬜ Belum           |
| 11        | Polish UI/UX, bug fixing, optimisasi                          | ⬜ Belum           |
| 12        | Testing akhir, demo, dokumentasi final                        | ⬜ Belum           |

### Prioritas Pertemuan 2

```text
✅ Finalisasi tech stack (Flutter + Firebase)
⬜ Setup project Flutter
⬜ Konfigurasi Firebase project
⬜ Buat struktur folder project
⬜ Setup koneksi Flutter ↔ Firebase
⬜ Buat halaman dasar (Splash Screen, placeholder Home)
```

---

## Nama Aplikasi

**Campus Ghost**

### Tagline

> **See what's happening on campus.**

Alternatif:

> **Your campus, in real time.**

> **Know before you go.**
