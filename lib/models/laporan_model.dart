import 'package:cloud_firestore/cloud_firestore.dart';

class LaporanModel {
  final String? id;
  final String uid;
  final String namaUser;
  final String kategori;
  final String lokasi;
  final String deskripsi;
  final bool hasPhoto;
  final String? imageUrl;
  final DateTime createdAt;
  final GeoPoint? geoPoint;
  final int konfirmasi;  // vote "Beneran Ada"
  final int hoax;        // vote "Hoax Nih"

  LaporanModel({
    this.id,
    required this.uid,
    required this.namaUser,
    required this.kategori,
    required this.lokasi,
    required this.deskripsi,
    this.hasPhoto = false,
    this.imageUrl,
    required this.createdAt,
    this.geoPoint,
    this.konfirmasi = 0,
    this.hoax = 0,
  });

  double get verifikasiPersen {
    final total = konfirmasi + hoax;
    if (total == 0) return 0;
    return konfirmasi / total;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'namaUser': namaUser,
      'kategori': kategori,
      'lokasi': lokasi,
      'deskripsi': deskripsi,
      'hasPhoto': hasPhoto,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'geoPoint': geoPoint,
      'konfirmasi': konfirmasi,
      'hoax': hoax,
    };
  }

  factory LaporanModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LaporanModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      namaUser: d['namaUser'] ?? 'Anonim',
      kategori: d['kategori'] ?? '',
      lokasi: d['lokasi'] ?? '',
      deskripsi: d['deskripsi'] ?? '',
      hasPhoto: d['hasPhoto'] ?? false,
      imageUrl: d['imageUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      geoPoint: d['geoPoint'],
      konfirmasi: d['konfirmasi'] ?? 0,
      hoax: d['hoax'] ?? 0,
    );
  }
}

class KomentarModel {
  final String? id;
  final String uid;
  final String namaUser;
  final String isi;
  final DateTime createdAt;
  final int suka;

  KomentarModel({
    this.id,
    required this.uid,
    required this.namaUser,
    required this.isi,
    required this.createdAt,
    this.suka = 0,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'namaUser': namaUser,
        'isi': isi,
        'createdAt': FieldValue.serverTimestamp(),
        'suka': suka,
      };

  factory KomentarModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return KomentarModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      namaUser: d['namaUser'] ?? 'Anonim',
      isi: d['isi'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      suka: d['suka'] ?? 0,
    );
  }
}
