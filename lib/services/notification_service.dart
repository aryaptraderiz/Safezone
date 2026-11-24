import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'user_settings_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Kata-kata notif yang menarik per kategori
  static const _messages = {
    'Begal': [
      ('🚨 Waspada Begal!', 'Ada laporan percobaan begal baru di sekitarmu. Tetap waspada dan hindari area tersebut!'),
      ('⚠️ Peringatan Keamanan', 'Warga melaporkan aksi begal di areamu. Jangan keluar sendirian malam ini!'),
      ('🔴 Zona Bahaya Aktif', 'Laporan begal masuk! Beritahu keluarga dan tetanggamu sekarang.'),
    ],
    'Tawuran': [
      ('🚧 Tawuran Terdeteksi!', 'Ada laporan tawuran di dekatmu. Hindari area tersebut untuk sementara.'),
      ('⚡ Situasi Memanas', 'Warga melaporkan tawuran aktif. Cari rute alternatif dan stay safe!'),
      ('🛑 Hindari Area Ini', 'Laporan tawuran masuk! Jauhi lokasi dan informasikan ke pihak berwajib.'),
    ],
    'Kecelakaan': [
      ('🚗 Laporan Kecelakaan', 'Ada kecelakaan di sekitarmu. Hati-hati dan kurangi kecepatan di area tersebut!'),
      ('🩺 Butuh Bantuan?', 'Warga melaporkan kecelakaan. Jika kamu di sekitar lokasi, bantu hubungi 119!'),
      ('⚠️ Arus Lalu Lintas', 'Kecelakaan terjadi! Pantau rute perjalananmu sekarang.'),
    ],
    'Lainnya': [
      ('📢 Laporan Baru Masuk!', 'Ada aktivitas mencurigakan dilaporkan warga di sekitarmu. Tetap waspada!'),
      ('🛡️ SafeZone Alert', 'Wargamu butuh perhatianmu! Ada laporan baru yang masuk di areamu.'),
      ('👀 Stay Alert!', 'Laporan keamanan baru masuk. Cek sekarang dan bantu verifikasi!'),
    ],
  };

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  // Tampilkan notif untuk laporan baru
  static Future<void> showLaporanBaru({
    required String kategori,
    required String namaUser,
    required String lokasi,
  }) async {
    if (!await UserSettingsService.getReportNotificationsEnabled()) return;
    await init();
    final soundEnabled =
        await UserSettingsService.getNotificationSoundEnabled();

    final msgs = _messages[kategori] ?? _messages['Lainnya']!;
    final picked = msgs[Random().nextInt(msgs.length)];
    final title = picked.$1;
    // Tambahkan nama user & lokasi ke body
    final body = '${picked.$2}\n\n📍 $lokasi — dilaporkan oleh $namaUser';

    final androidDetails = AndroidNotificationDetails(
      'safezone_laporan',
      'Laporan SafeZone',
      channelDescription: 'Notifikasi laporan keamanan terbaru di sekitarmu',
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
      color: Color(0xFFC0392B),
      ledColor: Color(0xFFC0392B),
      ledOnMs: 500,
      ledOffMs: 500,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  // Notif selamat datang saat pertama install/login
  static Future<void> showWelcome(String nama) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'safezone_general',
      'SafeZone General',
      channelDescription: 'Notifikasi umum SafeZone',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Color(0xFFC0392B),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      0,
      '👋 Selamat datang, $nama!',
      'Kamu sekarang bagian dari komunitas SafeZone. Bersama kita jaga keamanan lingkungan! 🛡️',
      details,
    );
  }
}
