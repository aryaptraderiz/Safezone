import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/laporan_model.dart';
import 'notification_service.dart';

class LaporanService {
  static final _col = FirebaseFirestore.instance.collection('laporan');

  // Kirim laporan baru + trigger notif
  static Future<void> kirim(LaporanModel laporan) async {
    await _col.add(laporan.toMap());
    // Trigger local notification ke device sendiri
    // (nanti kalau udah FCM, ini diganti ke broadcast semua user)
    await NotificationService.showLaporanBaru(
      kategori: laporan.kategori,
      namaUser: laporan.namaUser,
      lokasi: laporan.lokasi,
    );
  }

  // Upload foto ke Firebase Storage
  static Future<String?> uploadFoto(File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child('laporan_images').child(fileName);
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      print('Error upload foto: $e');
      return null;
    }
  }

  // Stream semua laporan realtime
  static Stream<List<LaporanModel>> streamAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LaporanModel.fromDoc).toList());
  }

  // Stream 1 laporan by id
  static Stream<LaporanModel?> streamById(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LaporanModel.fromDoc(doc);
    });
  }

  // Vote konfirmasi atau hoax
  static Future<void> vote(String laporanId, bool isKonfirmasi) async {
    await _col.doc(laporanId).update({
      isKonfirmasi ? 'konfirmasi' : 'hoax': FieldValue.increment(1),
    });
  }

  // ── Komentar subcollection ──
  static CollectionReference _komentarCol(String laporanId) =>
      _col.doc(laporanId).collection('komentar');

  static Stream<List<KomentarModel>> streamKomentar(String laporanId) {
    return _komentarCol(laporanId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(KomentarModel.fromDoc).toList());
  }

  static Future<void> kirimKomentar(
      String laporanId, KomentarModel komentar) async {
    await _komentarCol(laporanId).add(komentar.toMap());
  }

  static Future<void> sukaiKomentar(
      String laporanId, String komentarId) async {
    await _komentarCol(laporanId)
        .doc(komentarId)
        .update({'suka': FieldValue.increment(1)});
  }
}
