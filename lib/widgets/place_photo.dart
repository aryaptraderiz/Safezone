import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../app_colors.dart';
import 'open_street_map_tile_layer.dart';

/// Client token Mapillary (gratis, diawali "MLY|"). Isi lewat
///   --dart-define=MAPILLARY_TOKEN=MLY|xxxx|yyyy
/// atau tempel di defaultValue di bawah. Kalau kosong, kartu langsung
/// memakai foto satelit.
const String _mapillaryToken = String.fromEnvironment(
  'MAPILLARY_TOKEN',
  defaultValue: 'MLY|28361438770217106|052a3cd4102cf49578586046fa0a9a09',
);

enum _PhotoMode { street, satellite }

/// Foto area sekitar sebuah titik, dipakai di kartu detail lokasi.
///
///   1. Foto jalan dari Mapillary (foto sudut pandang jalan buatan komunitas,
///      gratis; cakupannya tidak merata). Ini bukan Google Street View, yang
///      berbayar.
///   2. Kalau tidak ada foto jalan: foto satelit Mapbox, lalu Esri World
///      Imagery (tanpa API key).
///   3. Terakhir: peta OpenStreetMap kecil.
///
/// Kalau ada foto jalan dan satelit, user bisa pindah lewat chip di kanan atas.
class PlacePhoto extends StatefulWidget {
  final LatLng point;

  const PlacePhoto({super.key, required this.point});

  @override
  State<PlacePhoto> createState() => _PlacePhotoState();
}

class _PlacePhotoState extends State<PlacePhoto> {
  static const _distance = Distance();

  int _generation = 0;
  _PhotoMode _mode = _PhotoMode.street;

  // Foto jalan (Mapillary)
  Uint8List? _streetBytes;
  String _streetLabel = '';
  int _streetMeters = 0;
  String? _streetNote; // alasan kalau foto jalan tidak tersedia
  bool _streetLoading = false;

  // Foto satelit
  Uint8List? _satBytes;
  String _satLabel = '';
  bool _satLoading = false;
  bool _satFailed = false;
  final List<String> _failures = [];

  bool get _hasStreetSource => _mapillaryToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(covariant PlacePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point) {
      _generation++;
      _streetBytes = null;
      _streetNote = null;
      _streetLoading = false;
      _satBytes = null;
      _satLoading = false;
      _satFailed = false;
      _failures.clear();
      _mode = _PhotoMode.street;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  bool _stale(int gen) => !mounted || gen != _generation;

  Future<void> _start() async {
    if (!mounted) return;
    final gen = _generation;

    if (_hasStreetSource) {
      await _loadStreet(gen);
      if (_stale(gen)) return;
      if (_streetBytes != null) return; // foto jalan ketemu, cukup
    } else {
      _streetNote = 'Token Mapillary belum diisi';
    }

    // Tidak ada foto jalan -> tampilkan satelit.
    setState(() => _mode = _PhotoMode.satellite);
    await _loadSatellite(gen);
  }

  // ───────────────────────── Foto jalan (Mapillary) ─────────────────────────

  Future<void> _loadStreet(int gen) async {
    setState(() => _streetLoading = true);
    try {
      final p = widget.point;
      // Cari dekat dulu (~55 m); kalau kosong, lebarkan (~220 m) dan ambil
      // foto jalan terdekat yang ada.
      const radii = [0.0005, 0.002];
      const limits = [70.0, 260.0];
      _StreetImage? best;
      for (var i = 0; i < radii.length; i++) {
        final d = radii[i];
        final bbox = '${p.longitude - d},${p.latitude - d},'
            '${p.longitude + d},${p.latitude + d}';
        final uri = Uri.https('graph.mapillary.com', '/images', {
          'access_token': _mapillaryToken,
          'fields': 'id,thumb_1024_url,geometry,captured_at,width,height',
          'bbox': bbox,
          'limit': '100',
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (_stale(gen)) return;
        if (res.statusCode != 200) {
          _streetNote = 'Mapillary ${res.statusCode}';
          return;
        }
        best = _pickNearestImage(res.body, p, limits[i]);
        if (best != null) break;
      }
      if (best == null) {
        _streetNote = 'Belum ada foto jalan di sekitar titik ini';
        return;
      }

      final img = await http
          .get(Uri.parse(best.url))
          .timeout(const Duration(seconds: 10));
      if (_stale(gen)) return;
      if (img.statusCode != 200 || img.bodyBytes.isEmpty) {
        _streetNote = 'Foto jalan gagal dimuat (${img.statusCode})';
        return;
      }

      _streetBytes = img.bodyBytes;
      _streetMeters = best.meters;
      _streetLabel =
          best.year != null ? 'Foto jalan · ${best.year}' : 'Foto jalan';
    } catch (_) {
      if (_stale(gen)) return;
      _streetNote = 'Foto jalan gagal dimuat';
    } finally {
      if (!_stale(gen)) setState(() => _streetLoading = false);
    }
  }

  _StreetImage? _pickNearestImage(String jsonBody, LatLng p, double maxMeters) {
    final data = _decodeList(jsonBody);
    _StreetImage? best;
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      final url = raw['thumb_1024_url'];
      final geom = raw['geometry'];
      if (url is! String || geom is! Map<String, dynamic>) continue;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) continue;

      // Lewati foto panorama 360 (rasio sangat lebar, terlihat melengkung).
      final w = raw['width'];
      final h = raw['height'];
      if (w is num && h is num && h > 0 && w / h > 1.9) continue;

      final meters = _distance(
        p,
        LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
      );
      if (meters > maxMeters) continue;
      if (best == null || meters < best.meters) {
        final at = raw['captured_at'];
        final year = at is num
            ? DateTime.fromMillisecondsSinceEpoch(at.toInt()).year
            : null;
        best = _StreetImage(url, meters.round(), year);
      }
    }
    return best;
  }

  List<dynamic> _decodeList(String jsonBody) {
    try {
      final decoded = jsonDecode(jsonBody);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) return data;
      }
    } catch (_) {}
    return const [];
  }

  // ───────────────────────────── Foto satelit ──────────────────────────────

  Future<void> _loadSatellite(int gen) async {
    if (_satLoading || _satBytes != null) return;
    setState(() => _satLoading = true);

    final p = widget.point;
    final lon = p.longitude.toStringAsFixed(6);
    final lat = p.latitude.toStringAsFixed(6);
    final sources = <_SatSource>[
      if (MapTileConfig.usesMapbox)
        _SatSource(
          'Mapbox',
          'Foto satelit · Mapbox',
          'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/'
              '$lon,$lat,17/640x360@2x?access_token=${MapTileConfig.mapboxToken}',
        ),
      _SatSource('Esri', 'Foto satelit · Esri', _esriUrl(p)),
    ];

    for (final src in sources) {
      try {
        final res = await http.get(
          Uri.parse(src.url),
          headers: {'User-Agent': 'com.safezone.app'},
        ).timeout(const Duration(seconds: 8));
        if (_stale(gen)) return;

        final type = res.headers['content-type'] ?? '';
        if (res.statusCode == 200 &&
            res.bodyBytes.isNotEmpty &&
            type.startsWith('image/')) {
          setState(() {
            _satBytes = res.bodyBytes;
            _satLabel = src.label;
            _satLoading = false;
          });
          return;
        }
        _failures.add('${src.name} ${res.statusCode}');
      } catch (_) {
        if (_stale(gen)) return;
        _failures.add('${src.name} error');
      }
    }
    if (!_stale(gen)) {
      setState(() {
        _satFailed = true;
        _satLoading = false;
      });
    }
  }

  /// Esri World Imagery (tanpa API key). bbox dihitung dalam Web Mercator
  /// dengan skala setara zoom 17 untuk gambar 640x360 (diminta 2x).
  String _esriUrl(LatLng p) {
    const r = 20037508.34;
    final x = p.longitude * r / 180;
    final y = math.log(math.tan((90 + p.latitude) * math.pi / 360)) /
        (math.pi / 180) *
        r /
        180;
    const unitsPerPx = 156543.03392 / 131072; // zoom 17 (2^17 = 131072)
    const halfW = 320 * unitsPerPx;
    const halfH = 180 * unitsPerPx;
    final bbox = [x - halfW, y - halfH, x + halfW, y + halfH]
        .map((v) => v.toStringAsFixed(2))
        .join(',');
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export'
        '?bbox=$bbox&bboxSR=3857&imageSR=3857&size=1280,720&format=jpg&f=image';
  }

  // ─────────────────────────────── Tampilan ────────────────────────────────

  void _showStreet() {
    if (_streetBytes == null) return;
    setState(() => _mode = _PhotoMode.street);
  }

  void _showSatellite() {
    setState(() => _mode = _PhotoMode.satellite);
    _loadSatellite(_generation);
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.cream,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.red,
        ),
      ),
    );
  }

  Widget _buildOsmMap() {
    // IgnorePointer supaya peta kecil ini tidak menangkap gestur geser/zoom.
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(initialCenter: widget.point, initialZoom: 17),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.safezone.app',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingStreet = _mode == _PhotoMode.street && _streetBytes != null;

    final Widget content;
    String title;
    String? subtitle;
    String? credit;

    if (showingStreet) {
      content =
          Image.memory(_streetBytes!, fit: BoxFit.cover, gaplessPlayback: true);
      title = _streetLabel;
      subtitle = '±$_streetMeters m dari titik';
      credit = '© Mapillary, CC BY-SA';
    } else if (_mode == _PhotoMode.street) {
      content = _placeholder();
      title = _streetLoading ? 'Memuat foto jalan...' : 'Foto jalan tidak ada';
    } else if (_satBytes != null) {
      content =
          Image.memory(_satBytes!, fit: BoxFit.cover, gaplessPlayback: true);
      title = _satLabel;
      subtitle = _streetNote == null ? null : 'Foto jalan: $_streetNote';
      if (_satLabel.contains('Esri')) {
        credit = 'Esri, Maxar, Earthstar Geographics';
      }
    } else if (_satFailed) {
      content = _buildOsmMap();
      title = 'Peta · OpenStreetMap';
      final reasons = [
        if (_streetNote != null) 'Jalan: $_streetNote',
        if (_failures.isNotEmpty) 'Satelit: ${_failures.join(' · ')}',
      ];
      subtitle = reasons.isEmpty ? null : reasons.join(' | ');
    } else {
      content = _placeholder();
      title = 'Memuat foto...';
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          // Pin hanya untuk satelit/peta, karena foto jalan tidak berpusat
          // tepat di titik yang diketuk.
          if (!showingStreet && _mode == _PhotoMode.satellite)
            Center(
              child: Transform.translate(
                offset: const Offset(0, -14),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 38),
                    Icon(Icons.location_on_rounded,
                        color: AppColors.red, size: 32),
                  ],
                ),
              ),
            ),
          if (credit != null)
            Positioned(
              right: 6,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  credit,
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
          // Label sumber di kiri atas.
          Positioned(
            left: 8,
            top: 8,
            right: _hasStreetSource ? 130 : 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Pilihan Jalan / Satelit (hanya kalau Mapillary dipakai).
          if (_hasStreetSource)
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeChip(
                    label: 'Jalan',
                    selected: showingStreet,
                    enabled: _streetBytes != null,
                    onTap: _showStreet,
                  ),
                  const SizedBox(width: 4),
                  _ModeChip(
                    label: 'Satelit',
                    selected: _mode == _PhotoMode.satellite,
                    enabled: true,
                    onTap: _showSatellite,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StreetImage {
  final String url;
  final int meters;
  final int? year;

  const _StreetImage(this.url, this.meters, this.year);
}

class _SatSource {
  final String name;
  final String label;
  final String url;

  const _SatSource(this.name, this.label, this.url);
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.red : Colors.black54,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
