import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../widgets/open_street_map_tile_layer.dart';

/// Hasil pencarian lokasi. Hasil Photon/Nominatim sudah punya [point];
/// hasil Mapbox Search Box hanya punya [mapboxId] dan koordinatnya diambil
/// lewat [PlaceSearchService.resolve].
class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng? point;
  final String? mapboxId;

  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    this.point,
    this.mapboxId,
  });
}

/// Pencarian lokasi + reverse geocoding.
/// Urutan sumber: Mapbox -> Photon -> Nominatim (cari), dan
/// Mapbox -> MapTiler -> Nominatim (reverse).
class PlaceSearchService {
  PlaceSearchService._();

  static const LatLng _defaultCenter = LatLng(-6.200000, 106.816666);
  static String _sessionToken = _newSessionToken();

  // ───────────────────────────── Cari lokasi ─────────────────────────────

  static Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng? near,
    int limit = 5,
  }) async {
    if (MapTileConfig.usesMapbox) {
      try {
        final results = await _searchMapbox(query, near: near, limit: limit);
        if (results.isNotEmpty) return results;
      } catch (_) {
        // lanjut ke cadangan
      }
    }
    return _searchPhoton(query, near: near, limit: limit);
  }

  /// Ambil koordinat sebuah hasil pencarian (hasil Mapbox perlu /retrieve).
  static Future<LatLng> resolve(PlaceSuggestion place) async {
    final known = place.point;
    if (known != null) return known;

    final id = place.mapboxId;
    if (id == null) throw Exception('Lokasi tidak valid.');

    final uri =
        Uri.https('api.mapbox.com', '/search/searchbox/v1/retrieve/$id', {
      'access_token': MapTileConfig.mapboxToken,
      'session_token': _sessionToken,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil detail lokasi.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) throw Exception('Lokasi tidak ditemukan.');
    final geometry = (features.first as Map<String, dynamic>)['geometry']
        as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>; // [lon, lat]

    _sessionToken = _newSessionToken();
    return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
  }

  static Future<List<PlaceSuggestion>> _searchMapbox(
    String query, {
    LatLng? near,
    int limit = 5,
  }) async {
    final center = near ?? _defaultCenter;
    final uri = Uri.https('api.mapbox.com', '/search/searchbox/v1/suggest', {
      'q': query,
      'access_token': MapTileConfig.mapboxToken,
      'session_token': _sessionToken,
      'language': 'id',
      'country': 'id',
      'limit': '$limit',
      'proximity': '${center.longitude},${center.latitude}',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('Mapbox ${res.statusCode}');

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['suggestions'] as List<dynamic>? ?? [];
    return list
        .map((raw) {
          final s = raw as Map<String, dynamic>;
          final full = s['full_address'] as String?;
          final subtitle = (full != null && full.isNotEmpty)
              ? full
              : [s['address'], s['place_formatted']]
                  .whereType<String>()
                  .where((e) => e.trim().isNotEmpty)
                  .join(', ');
          return PlaceSuggestion(
            title: (s['name'] as String?) ?? query,
            subtitle: subtitle,
            mapboxId: s['mapbox_id'] as String?,
          );
        })
        .where((p) => p.mapboxId != null)
        .toList();
  }

  static Future<List<PlaceSuggestion>> _searchPhoton(
    String query, {
    LatLng? near,
    int limit = 5,
  }) async {
    final center = near ?? _defaultCenter;
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '$limit',
      'lang': 'id',
      'lat': '${center.latitude}',
      'lon': '${center.longitude}',
    });

    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      return _searchNominatim(query, limit: limit);
    }
    if (res.statusCode != 200) return _searchNominatim(query, limit: limit);

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return _searchNominatim(query, limit: limit);

    return features.map((raw) {
      final feature = raw as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>; // [lon, lat]

      final addressParts = [
        props['street'],
        props['district'],
        props['city'],
        props['state'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();

      return PlaceSuggestion(
        title: (props['name'] as String?) ?? query,
        subtitle: addressParts.join(', '),
        point: LatLng(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
      );
    }).toList();
  }

  static Future<List<PlaceSuggestion>> _searchNominatim(
    String query, {
    int limit = 5,
  }) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
      'countrycodes': 'id',
    });
    final res = await http.get(uri, headers: {
      'User-Agent': 'SafeZone/1.0 (safezone-app)',
    }).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Gagal mencari lokasi "$query".');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((raw) {
      final item = raw as Map<String, dynamic>;
      final displayName = (item['display_name'] as String?) ?? query;
      final parts = displayName.split(',').map((e) => e.trim()).toList();
      return PlaceSuggestion(
        title: parts.take(2).join(' '),
        subtitle: parts.skip(2).take(4).join(', '),
        point: LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
      );
    }).toList();
  }

  // ─────────────────────────── Reverse geocoding ───────────────────────────

  /// Nama jalan/alamat singkat untuk sebuah titik, atau null kalau semua
  /// sumber gagal.
  static Future<String?> reverse(LatLng point) async {
    return await _reverseMapbox(point) ??
        await _reverseMapTiler(point) ??
        await _reverseNominatim(point);
  }

  static String? _short(String? full) {
    final text = full?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  static Future<String?> _reverseMapbox(LatLng p) async {
    if (!MapTileConfig.usesMapbox) return null;
    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/${p.longitude},${p.latitude}.json',
        {
          'access_token': MapTileConfig.mapboxToken,
          'language': 'id',
          'limit': '1',
          'types': 'poi,address,place,locality,neighborhood,street',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;
      return _short(
          (features.first as Map<String, dynamic>)['place_name'] as String?);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _reverseMapTiler(LatLng p) async {
    if (!MapTileConfig.usesMapTiler) return null;
    try {
      final uri = Uri.https(
        'api.maptiler.com',
        '/geocoding/${p.longitude},${p.latitude}.json',
        {
          'key': MapTileConfig.maptilerKey,
          'language': 'id',
          'limit': '1',
        },
      );
      // User-Agent ini di-whitelist di MapTiler Cloud.
      final res = await http.get(uri, headers: {
        'User-Agent': 'com.safezone.app'
      }).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;
      return _short(
          (features.first as Map<String, dynamic>)['place_name'] as String?);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _reverseNominatim(LatLng p) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'format': 'jsonv2',
        'zoom': '18',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'SafeZone/1.0 (safezone-app)',
      }).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return _short(data['display_name'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// UUID v4 acak untuk session_token Mapbox Search Box.
  static String _newSessionToken() {
    final r = math.Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    const variants = '89ab';
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${variants[r.nextInt(4)]}${hex(3)}-${hex(12)}';
  }
}
