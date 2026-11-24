import 'package:cloud_firestore/cloud_firestore.dart';

class LaporanMedia {
  final String url;
  final String type;

  const LaporanMedia({required this.url, required this.type});

  bool get isVideo => type == 'video';

  Map<String, dynamic> toMap() => {'url': url, 'type': type};

  factory LaporanMedia.fromMap(Map<String, dynamic> data) => LaporanMedia(
        url: data['url'] as String? ?? '',
        type: data['type'] as String? ?? 'image',
      );
}

class LaporanModel {
  final String? id;
  final String uid;
  final String namaUser;
  final String kategori;
  final String lokasi;
  final String deskripsi;
  final bool hasPhoto;
  final String? imageUrl;
  final String? videoUrl;
  final List<LaporanMedia> media;
  final DateTime createdAt;
  final GeoPoint? geoPoint;
  final int konfirmasi; // vote "Beneran Ada"
  final int hoax; // vote "Hoax Nih"
  final Map<String, bool> voters; // { uid: isKonfirmasi }

  LaporanModel({
    this.id,
    required this.uid,
    required this.namaUser,
    required this.kategori,
    required this.lokasi,
    required this.deskripsi,
    this.hasPhoto = false,
    this.imageUrl,
    this.videoUrl,
    this.media = const [],
    required this.createdAt,
    this.geoPoint,
    this.konfirmasi = 0,
    this.hoax = 0,
    this.voters = const {},
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
      'videoUrl': videoUrl,
      'media': media.map((item) => item.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'geoPoint': geoPoint,
      'konfirmasi': konfirmasi,
      'hoax': hoax,
      'voters': voters,
    };
  }

  factory LaporanModel.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawVoters = d['voters'];
    final Map<String, bool> votersMap = {};
    if (rawVoters is Map) {
      rawVoters.forEach((key, value) {
        if (value is bool) votersMap[key.toString()] = value;
      });
    }

    final rawMedia = d['media'];
    final List<LaporanMedia> media = rawMedia is List
        ? rawMedia
            .whereType<Map>()
            .map(
                (item) => LaporanMedia.fromMap(Map<String, dynamic>.from(item)))
            .where((item) => item.url.isNotEmpty)
            .toList()
        : <LaporanMedia>[];
    // Existing reports only have imageUrl/videoUrl. Continue reading them.
    if (media.isEmpty) {
      final videoUrl = d['videoUrl'] as String?;
      final imageUrl = d['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        media.add(LaporanMedia(url: imageUrl, type: 'image'));
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        media.add(LaporanMedia(url: videoUrl, type: 'video'));
      }
    }

    return LaporanModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      namaUser: d['namaUser'] ?? 'Anonim',
      kategori: d['kategori'] ?? '',
      lokasi: d['lokasi'] ?? '',
      deskripsi: d['deskripsi'] ?? '',
      hasPhoto: d['hasPhoto'] ?? false,
      imageUrl: d['imageUrl'],
      videoUrl: d['videoUrl'],
      media: media,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      geoPoint: d['geoPoint'],
      konfirmasi: (d['konfirmasi'] as num?)?.toInt() ?? 0,
      hoax: (d['hoax'] as num?)?.toInt() ?? 0,
      voters: votersMap,
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
