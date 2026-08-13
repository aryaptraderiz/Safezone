# SafeZone – Setup Firebase

## Yang Sudah Ada
- ✅ Firebase Auth (login, register, logout, reset password)
- ✅ Cloud Firestore (simpan laporan)
- ✅ Service layer: `AuthService`, `LaporanService`
- ✅ Model: `LaporanModel`
- ✅ Validasi form + error handling + loading state
- ✅ Toast sukses setelah laporan terkirim

---

## Langkah Setup Firebase

### 1. Buat Project Firebase
Buka https://console.firebase.google.com → New Project → nama: **safezone**

### 2. Aktifkan Firebase Auth
Firebase Console → Authentication → Sign-in method → Email/Password → Enable

### 3. Buat Firestore Database
Firebase Console → Firestore Database → Create database → Start in test mode

### 4. Pasang Firebase ke Flutter (cara termudah)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Login ke Firebase
firebase login

# Generate firebase_options.dart otomatis (jalankan di folder safezone)
flutterfire configure --project=YOUR_PROJECT_ID
```

File `lib/firebase_options.dart` akan otomatis terisi dengan config yang benar.

### 5. Android – Tambahkan google-services.json
- Firebase Console → Project Settings → Add app → Android
- Package name: `com.example.safezone`
- Download `google-services.json`
- Taruh di: `android/app/google-services.json`

### 6. Update android/build.gradle
```gradle
// android/build.gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.1'
}
```

### 7. Update android/app/build.gradle
```gradle
// Di bagian paling bawah
apply plugin: 'com.google.gms.google-services'
```

### 8. Install packages & jalankan
```bash
flutter pub get
flutter run
```

---

## Struktur Firestore

### Collection: `users`
```
users/{uid}
  - uid: string
  - name: string
  - email: string
  - createdAt: timestamp
```

### Collection: `laporan`
```
laporan/{auto-id}
  - uid: string           // uid user yang lapor
  - namaUser: string
  - kategori: string      // Begal / Tawuran / Kecelakaan / Lainnya
  - lokasi: string
  - deskripsi: string
  - hasPhoto: boolean
  - createdAt: timestamp
  - geoPoint: GeoPoint?   // nanti untuk heatmap Google Maps
```

---

## Firestore Rules (salin ke Rules tab)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User hanya bisa baca/edit profil sendiri
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    // Laporan: semua login bisa baca, yang buat bisa hapus
    match /laporan/{id} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow delete: if request.auth != null && request.auth.uid == resource.data.uid;
    }
  }
}
```

---

## Next: Heatmap Google Maps
Nanti setelah kamu masukkan Google Maps API:
1. Setiap laporan akan simpan `geoPoint` (latitude/longitude)
2. Map screen akan fetch semua laporan dan render heatmap berdasarkan koordinat
Field `geoPoint` di model sudah disiapkan!
