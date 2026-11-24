import 'package:cloud_firestore/cloud_firestore.dart';

/// Satu lokasi tersimpan milik user, misal "Rumah" atau "Kantor".
class SavedLocationModel {
  final String? id;
  final String label; // "Rumah", "Kantor", atau nama custom
  final String address;
  final GeoPoint point;

  const SavedLocationModel({
    this.id,
    required this.label,
    required this.address,
    required this.point,
  });

  factory SavedLocationModel.fromDoc(String id, Map<String, dynamic> d) {
    return SavedLocationModel(
      id: id,
      label: (d['label'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      point: d['point'] as GeoPoint,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'address': address,
        'point': point,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Ikon bawaan berdasarkan label umum, biar "Rumah"/"Kantor" auto dapat ikon khas.
  String get iconKey {
    final l = label.toLowerCase();
    if (l.contains('rumah')) return 'home';
    if (l.contains('kantor') || l.contains('kerja')) return 'work';
    return 'place';
  }
}
