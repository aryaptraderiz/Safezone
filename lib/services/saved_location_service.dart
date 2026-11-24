import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/saved_location_model.dart';

/// Menyimpan lokasi favorit user (Rumah, Kantor, dst) di:
/// users/{uid}/saved_locations/{docId}
class SavedLocationService {
  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('User belum login, tidak bisa akses saved_locations.');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_locations');
  }

  /// Stream realtime semua lokasi tersimpan milik user yang sedang login.
  /// Kalau user belum login, kembalikan stream kosong (bukan error) supaya
  /// UI tidak crash saat dipakai di halaman yang bisa diakses tanpa auth.
  static Stream<List<SavedLocationModel>> streamAll() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_locations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SavedLocationModel.fromDoc(d.id, d.data()))
            .toList());
  }

  static Future<void> save({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) {
    return _col().add(SavedLocationModel(
      label: label,
      address: address,
      point: GeoPoint(lat, lng),
    ).toMap());
  }

  /// Simpan atau perbarui lokasi berdasarkan label, dipakai untuk slot tetap
  /// ala Google Maps ("Rumah"/"Kantor"): kalau labelnya sudah pernah
  /// disimpan, titik & alamatnya diperbarui; kalau belum ada, dibuat baru.
  /// Ini yang bikin "Set location" dan "Edit" bisa pakai alur yang sama.
  static Future<void> upsertByLabel({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final col = _col();
    final existing = await col.where('label', isEqualTo: label).limit(1).get();
    if (existing.docs.isNotEmpty) {
      await col.doc(existing.docs.first.id).update({
        'address': address,
        'point': GeoPoint(lat, lng),
      });
    } else {
      await col.add(SavedLocationModel(
        label: label,
        address: address,
        point: GeoPoint(lat, lng),
      ).toMap());
    }
  }

  static Future<void> delete(String id) => _col().doc(id).delete();
}
