# Google Sign-In Gagal di APK Release - Solusi

## 🔴 Masalah

Ketika install APK dan coba login dengan Google, muncul error/gagal.

**Root Cause:**  
APK release di-sign dengan **debug keystore**, tapi Firebase Console tidak memiliki SHA-1 fingerprint untuk keystore tersebut.

---

## ✅ Solusi

### **Option A: Daftarkan Debug SHA-1 (Quick Fix)**

Karena APK currently menggunakan debug signing, daftarkan debug SHA-1:

#### 1. Get Debug SHA-1

**Di Linux/Mac:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

**Di Windows:**
```cmd
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Output akan seperti:
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

#### 2. Tambahkan ke Firebase Console

1. Buka: https://console.firebase.google.com
2. Pilih project: **Campus Ghost**
3. Klik **⚙️ Project Settings**
4. Scroll ke **Your apps** → pilih Android app
5. Klik **Add fingerprint**
6. Paste SHA-1 yang didapat dari step 1
7. Klik **Save**

#### 3. Download google-services.json Baru

1. Masih di Firebase Console, scroll ke bawah
2. Klik **Download google-services.json**
3. Replace file di: `android/app/google-services.json`
4. Commit dan rebuild:
   ```bash
   git add android/app/google-services.json
   git commit -m "fix(firebase): update google-services.json with new SHA-1"
   flutter build apk --release
   ```

---

### **Option B: Proper Release Signing (Production-Ready)**

Untuk production, sebaiknya buat release keystore sendiri.

#### 1. Generate Release Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Akan ditanya:
# - Enter keystore password: [buat password]
# - Re-enter password: [ulangi password]
# - What is your first and last name?: [nama Anda]
# - What is the name of your organizational unit?: [Pradita University]
# - ... dst
```

#### 2. Create key.properties

```bash
cat > android/key.properties << EOF
storePassword=<password dari step 1>
keyPassword=<password dari step 1>
keyAlias=upload
storeFile=<path>/upload-keystore.jks
EOF
```

**⚠️ JANGAN COMMIT key.properties ke Git!**

Add to `.gitignore`:
```bash
echo "android/key.properties" >> .gitignore
```

#### 3. Update android/app/build.gradle.kts

Before `android {` block, add:
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Inside `android {`, add:
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        // ... existing config
    }
}
```

#### 4. Get Release SHA-1

```bash
keytool -list -v -keystore ~/upload-keystore.jks -alias upload | grep SHA1
```

#### 5. Daftarkan ke Firebase

Sama seperti Option A step 2-3, tapi gunakan SHA-1 dari release keystore.

---

## 🎯 Recommended Approach

**Untuk P11 / Development:** Gunakan **Option A** (debug SHA-1)
- ✅ Quick fix
- ✅ No keystore management
- ✅ Works untuk testing

**Untuk Production:** Gunakan **Option B** (release keystore)
- ✅ Proper security
- ✅ Play Store ready
- ✅ Professional setup

---

## 🔍 Troubleshooting

### Error: "10: developer error"

**Penyebab:** SHA-1 belum didaftarkan atau google-services.json outdated

**Solusi:**
1. Pastikan SHA-1 sudah didaftarkan di Firebase
2. Download ulang google-services.json
3. Replace file lama
4. Rebuild APK

### Error: "12500: sign in failed"

**Penyebab:** 
- google-services.json tidak match dengan package name
- OAuth consent screen belum setup

**Solusi:**
1. Check package name di `android/app/build.gradle.kts`:
   ```kotlin
   namespace = "com.example.campus_ghost" // atau package name Anda
   ```
2. Pastikan sama dengan package name di Firebase Console
3. Setup OAuth consent screen di Google Cloud Console

### Google Sign-In Button Tidak Muncul

**Penyebab:** GoogleSignInButton widget belum di-implement

**Check:**
```dart
// Di lib/screens/auth/login_screen.dart
GoogleSignInButton(
  onPressed: () async {
    // ... sign in logic
  },
)
```

---

## 📋 Checklist

Untuk memastikan Google Sign-In works:

- [ ] SHA-1 fingerprint didaftarkan di Firebase Console
- [ ] google-services.json up-to-date (download ulang setelah add SHA-1)
- [ ] Package name match di Firebase dan build.gradle
- [ ] OAuth consent screen configured di Google Cloud Console
- [ ] Internet permission ada di AndroidManifest.xml
- [ ] APK rebuilt setelah update google-services.json

---

## 🎓 Untuk Dosen

**Jika Google Sign-In tidak demo saat presentasi:**

Explain:
> "Google Sign-In memerlukan SHA-1 certificate fingerprint yang didaftarkan di Firebase Console. Untuk APK release, kita perlu daftarkan release SHA-1. Ini adalah security measure dari Google. Untuk demo, bisa menggunakan email/password login yang sudah berfungsi normal."

**Alternative Demo:**
- ✅ Email/password login (sudah works)
- ✅ Show code implementation Google Sign-In
- ✅ Explain SHA-1 registration process
- ✅ Demo di development mode (flutter run) dimana Google Sign-In works

---

## 📚 References

- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)
- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android/start)
- [App Signing - Android](https://developer.android.com/studio/publish/app-signing)

---

**Last Updated:** 2024-11-27  
**Status:** Development - Debug signing active  
**Production:** Requires proper release keystore setup
