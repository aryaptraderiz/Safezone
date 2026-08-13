# SafeZone

SafeZone adalah aplikasi Flutter untuk membantu warga memantau kondisi keamanan lingkungan, melaporkan kejadian, dan mengakses kontak darurat dengan cepat.

Dirancang sebagai aplikasi komunitas yang ringan, responsif, dan mudah dipakai saat situasi mendesak.

## Highlights

- Laporan kejadian warga secara realtime
- Kategori laporan seperti begal, tawuran, kecelakaan, dan lainnya
- Detail laporan dengan verifikasi dan komentar warga
- Kontak darurat cepat untuk medis, polisi, pemadam, dan SOS
- Autentikasi pengguna menggunakan Firebase Authentication
- Penyimpanan laporan menggunakan Cloud Firestore
- Notifikasi lokal untuk laporan dan aktivitas penting
- UI mobile-first dengan gaya visual SafeZone yang hangat dan aman

## Tech Stack

- Flutter
- Dart
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Flutter Local Notifications
- Google Fonts
- URL Launcher

## Screens

SafeZone terdiri dari beberapa layar utama:

- `Home` - ringkasan keamanan, kategori darurat, dan laporan terbaru
- `Map` - tampilan area sekitar
- `Lapor` - form untuk mengirim laporan kejadian
- `Alerts` - daftar laporan realtime dari warga
- `Detail Laporan` - detail, verifikasi, dan komentar laporan
- `Login / Register` - autentikasi pengguna
- `Settings` - profil dan pengaturan akun

## Project Structure

```text
lib/
  app_colors.dart
  main.dart
  firebase_options.dart
  models/
    laporan_model.dart
  screens/
    home_screen.dart
    map_screen.dart
    lapor_screen.dart
    alerts_screen.dart
    detail_laporan_screen.dart
    login_screen.dart
    register_screen.dart
    settings_screen.dart
  services/
    auth_service.dart
    laporan_service.dart
    notification_service.dart
```

## Getting Started

Pastikan Flutter sudah terpasang:

```bash
flutter --version
```

Clone repository:

```bash
git clone https://github.com/aryaptraderiz/Safezone.git
cd Safezone
```

Install dependencies:

```bash
flutter pub get
```

Jalankan aplikasi:

```bash
flutter run
```

## Firebase Setup

Project ini memakai Firebase untuk authentication dan database. File konfigurasi Firebase sudah tersedia di project, tetapi jika ingin memakai project Firebase sendiri, ikuti panduan:

```text
SETUP_FIREBASE.md
```

Fitur Firebase yang digunakan:

- Authentication untuk login dan register
- Cloud Firestore untuk laporan, komentar, dan verifikasi
- Firebase Core sebagai inisialisasi platform

## Build Android

Debug APK:

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release
```

Hasil build akan berada di:

```text
build/app/outputs/flutter-apk/
```

## Notes

- Folder `build/`, `.dart_tool/`, dan cache Flutter tidak ikut disimpan di Git.
- Pastikan konfigurasi Firebase cocok dengan package name aplikasi sebelum build release.
- Beberapa fitur seperti lokasi/map masih bisa dikembangkan lebih lanjut sesuai kebutuhan lapangan.

## License

Project ini dibuat untuk kebutuhan pengembangan aplikasi SafeZone.
