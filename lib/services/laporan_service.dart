import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/laporan_model.dart';
import 'notification_service.dart';

class LaporanService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('laporan');

  // ── Cloudinary (unsigned upload) ──
  //
  // Firebase Storage untuk project ini butuh paket Blaze (kartu tersambung)
  // sejak kebijakan baru Firebase per Feb 2026, jadi upload foto laporan
  // dipindah ke Cloudinary yang gratis tanpa kartu. Upload preset harus
  // "Unsigned" di dashboard Cloudinary supaya app bisa upload langsung tanpa
  // API secret (API secret TIDAK BOLEH ditaruh di kode app).
  static const _cloudinaryCloudName = 'ycptfpbu';
  static const _cloudinaryUploadPreset = 'Safezone';

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

  // Upload foto ke Cloudinary (unsigned upload, tanpa API key/secret di app).
  static Future<String?> uploadFoto(File file) async {
    return _uploadMedia(file, video: false);
  }

  static Future<String?> uploadVideo(File file) async {
    return _uploadMedia(file, video: true);
  }

  static Future<String?> _uploadMedia(File file, {required bool video}) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/${video ? 'video' : 'image'}/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(
            Duration(seconds: video ? 180 : 60),
          );
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode != 200) {
        String detail = 'HTTP ${res.statusCode}';
        try {
          final errJson = jsonDecode(res.body);
          if (errJson is Map &&
              errJson['error'] is Map &&
              errJson['error']['message'] != null) {
            detail = errJson['error']['message'].toString();
          }
        } catch (_) {}

        if (detail.contains('must be whitelisted for unsigned uploads')) {
          print(
              '[Cloudinary] Upload preset "$_cloudinaryUploadPreset" belum diset ke mode "Unsigned" di dashboard Cloudinary.');
          throw Exception(
            'Preset Cloudinary "$_cloudinaryUploadPreset" belum diaktifkan mode Unsigned di dashboard Cloudinary.',
          );
        }

        print('Error upload media ke Cloudinary: $detail');
        throw Exception('Gagal upload ${video ? 'video' : 'foto'}: $detail');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['secure_url'] as String?;
    } catch (e) {
      print('Error upload media: $e');
      rethrow;
    }
  }

  // Stream laporan hanya untuk sesi terautentikasi.
  static Stream<List<LaporanModel>> streamAll() {
    late final StreamController<List<LaporanModel>> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        reportsSubscription;

    controller = StreamController<List<LaporanModel>>(
      onListen: () {
        authSubscription = FirebaseAuth.instance.authStateChanges().listen(
          (user) async {
            await reportsSubscription?.cancel();
            reportsSubscription = null;
            if (user == null) {
              controller.add([]);
              return;
            }
            reportsSubscription = _col.snapshots().listen(
                  (snapshot) => controller.add(_parseReports(snapshot)),
                  onError: controller.addError,
                );
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await authSubscription?.cancel();
        await reportsSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  static List<LaporanModel> _parseReports(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final laporan = <LaporanModel>[];
    for (final doc in snapshot.docs) {
      try {
        laporan.add(LaporanModel.fromDoc(doc));
      } catch (_) {
        // Skip one malformed legacy document without breaking the feed.
      }
    }
    laporan.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return laporan;
  }

  // Stream 1 laporan by id
  static Stream<LaporanModel?> streamById(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LaporanModel.fromDoc(doc);
    });
  }

  // ── Vote konfirmasi/hoax, dikunci per-user ──
  //
  // Vote dicatat langsung di field map 'voters' pada dokumen laporan (voters.{uid} = true/false),
  // dan di subcollection laporan/{id}/votes/{uid}.
  // Transaction memastikan satu uid cuma bisa vote sekali. Dokumen laporanRef
  // dibaca terlebih dahulu (wajib dalam transaksi Firestore sebelum operasi write),
  // sehingga tidak akan gagal/error di level Firestore transaction.

  static CollectionReference<Map<String, dynamic>> _votesCol(
          String laporanId) =>
      _col.doc(laporanId).collection('votes');

  /// true = konfirmasi ("Beneran Ada"), false = hoax ("Hoax Nih"),
  /// null = user ini belum pernah vote laporan ini.
  static Future<bool?> getMyVote(
    String laporanId, {
    required String? uid,
  }) async {
    if (uid == null) return null;
    try {
      // 1. Cek langsung dari dokumen laporan (paling cepat & aman dari rule subcollection)
      final doc = await _col.doc(laporanId).get();
      if (doc.exists) {
        final d = doc.data() ?? {};
        final voters = d['voters'];
        if (voters is Map && voters.containsKey(uid)) {
          return voters[uid] as bool?;
        }
      }
      // 2. Fallback cek subcollection
      final subDoc = await _votesCol(laporanId).doc(uid).get();
      if (subDoc.exists) {
        return subDoc.data()?['isKonfirmasi'] as bool?;
      }
    } catch (e) {
      print('Error getMyVote: $e');
    }
    return null;
  }

  /// Vote sekali per user. Melempar [StateError] kalau user belum login
  /// atau sudah pernah vote laporan ini sebelumnya.
  static Future<void> vote(
    String laporanId,
    bool isKonfirmasi, {
    required String? uid,
  }) async {
    if (uid == null) throw StateError('Kamu harus login dulu untuk vote.');

    final laporanRef = _col.doc(laporanId);
    final voteRef = _votesCol(laporanId).doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // PENTING: Semua READ harus dilakukan sebelum WRITE dalam transaksi Firestore!
      final doc = await tx.get(laporanRef);
      if (!doc.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final data = doc.data() ?? {};

      // Cek apakah user yang lapor mencoba memvalidasi laporannya sendiri
      if (data['uid'] == uid) {
        throw StateError(
            'Kamu tidak bisa memvalidasi laporan buatanmu sendiri.');
      }

      // Cek apakah sudah pernah vote di dokumen utama
      final voters = data['voters'];
      if (voters is Map && voters.containsKey(uid)) {
        throw StateError('Kamu sudah pernah memvalidasi laporan ini.');
      }

      // Cek apakah sudah pernah vote di subcollection
      final existingVote = await tx.get(voteRef);
      if (existingVote.exists) {
        throw StateError('Kamu sudah pernah memvalidasi laporan ini.');
      }

      // WRITE OPERATIONS:
      // Catat vote di dokumen laporan langsung agar realtime stream langsung tahu
      tx.update(laporanRef, {
        'voters.$uid': isKonfirmasi,
        isKonfirmasi ? 'konfirmasi' : 'hoax': FieldValue.increment(1),
      });

      // Catat juga di subcollection
      tx.set(voteRef, {
        'isKonfirmasi': isKonfirmasi,
        'createdAt': FieldValue.serverTimestamp(),
      });
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

  static Future<void> sukaiKomentar(String laporanId, String komentarId) async {
    await _komentarCol(laporanId)
        .doc(komentarId)
        .update({'suka': FieldValue.increment(1)});
  }
}
