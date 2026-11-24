import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../app_colors.dart';

class OpenStreetMapTileLayer extends StatelessWidget {
  const OpenStreetMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    // maxZoom dipatok ke batas OSM (19) supaya tetap aman kalau ujung-ujungnya
    // fallback sampai ke OSM di zoom tinggi (Mapbox/MapTiler bisa lebih tinggi
    // dari ini, tapi OSM tidak).
    return TileLayer(
      urlTemplate: '', // tidak dipakai; semua URL dibangun di tileProvider
      tileProvider: _ChainedTileProvider(_buildTileSources),
      userAgentPackageName: 'com.safezone.app',
      maxZoom: 19,
    );
  }
}

/// Satu kandidat sumber tile: label buat ditampilkan di attribution, dan
/// URL tile sesungguhnya untuk koordinat tertentu.
class _TileSource {
  final String label;
  final String url;
  const _TileSource(this.label, this.url);
}

class _TileCache {
  static Future<Directory>? _directory;
  static const _maxTileBytes = 2 * 1024 * 1024;
  static const _maxCachedTiles = 2000;
  static int _writesSincePrune = 0;

  static Future<Directory> _cacheDirectory() => _directory ??= () async {
        final root = await getTemporaryDirectory();
        final dir = Directory('${root.path}/safezone_map_tiles');
        await dir.create(recursive: true);
        return dir;
      }();

  static Future<Uint8List?> read(String url) async {
    try {
      final dir = await _cacheDirectory();
      final file = File('${dir.path}/${_fileName(url)}.tile');
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String url, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > _maxTileBytes) return;
    try {
      final dir = await _cacheDirectory();
      final file = File('${dir.path}/${_fileName(url)}.tile');
      await file.writeAsBytes(bytes, flush: false);
      _writesSincePrune++;
      if (_writesSincePrune >= 100) {
        _writesSincePrune = 0;
        unawaited(_prune(dir));
      }
    } catch (_) {
      // Tile cache is best-effort; network tiles remain available if storage fails.
    }
  }

  static Future<void> _prune(Directory dir) async {
    try {
      final files = await dir
          .list(followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      if (files.length <= _maxCachedTiles) return;
      final withTimes = await Future.wait(
        files.map((file) async => (file, await file.lastModified())),
      );
      withTimes.sort((a, b) => a.$2.compareTo(b.$2));
      final removeCount = files.length - _maxCachedTiles;
      for (final entry in withTimes.take(removeCount)) {
        await entry.$1.delete();
      }
    } catch (_) {
      // Cache eviction is best-effort.
    }
  }

  static String _fileName(String value) {
    var hash = 0xcbf29ce484222325;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

/// Susunan sumber peta: Mapbox dulu (kalau ada token), lalu MapTiler (kalau
/// ada key), baru OpenStreetMap sebagai penyelamat terakhir yang tidak
/// pernah kehabisan kuota. Setiap tile dicoba satu-satu sampai ada yang
/// berhasil, jadi kalau token Mapbox habis, tile itu otomatis lanjut ke
/// MapTiler tanpa perlu ubah kode atau restart app.
List<_TileSource> _buildTileSources(TileCoordinates c) {
  final z = c.z;
  final x = c.x;
  final y = c.y;
  final sources = <_TileSource>[];

  if (MapTileConfig.usesMapbox) {
    sources.add(_TileSource(
      'Mapbox',
      'https://api.mapbox.com/styles/v1/${MapTileConfig.mapboxStyle}/tiles/256/$z/$x/$y@2x'
          '?access_token=${MapTileConfig.mapboxToken}',
    ));
  }
  if (MapTileConfig.usesMapTiler) {
    sources.add(_TileSource(
      'MapTiler',
      'https://api.maptiler.com/maps/${MapTileConfig.maptilerStyle}/$z/$x/$y@2x.png'
          '?key=${MapTileConfig.maptilerKey}',
    ));
  }
  // Selalu ada di akhir daftar sebagai jaring pengaman terakhir.
  sources.add(_TileSource(
      'OpenStreetMap', 'https://tile.openstreetmap.org/$z/$x/$y.png'));

  return sources;
}

class MapTileConfig {
  static const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const mapboxStyle = String.fromEnvironment(
    'MAPBOX_STYLE',
    defaultValue: 'mapbox/streets-v12',
  );

  static const maptilerKey = String.fromEnvironment('MAPTILER_API_KEY');
  static const maptilerStyle = String.fromEnvironment(
    'MAPTILER_STYLE',
    defaultValue: 'streets-v2',
  );

  static const usesMapbox = mapboxToken != '';
  static const usesMapTiler = maptilerKey != '';

  /// Tebakan awal sebelum ada tile yang benar-benar berhasil dimuat. Setelah
  /// itu, [TileSourceStatus.active] yang jadi sumber kebenaran (lihat di
  /// bawah), karena baru itu yang mencerminkan sumber yang BENERAN berhasil
  /// dipakai, bukan sekadar tebakan dari ada/tidaknya token di config.
  static const _initialGuess = usesMapbox
      ? 'Mapbox'
      : usesMapTiler
          ? 'MapTiler'
          : 'OpenStreetMap';
}

/// Melacak sumber tile mana yang PALING TERAKHIR benar-benar berhasil
/// memuat tile (bukan sekadar tebakan dari config). Dipakai supaya teks
/// atribusi di pojok peta jujur: kalau Mapbox lagi kena limit dan diam-diam
/// fallback ke MapTiler/OSM, teksnya ikut berubah jadi "MapTiler"/
/// "OpenStreetMap", bukan tetap "Mapbox" walau sebenarnya sudah tidak dipakai.
class TileSourceStatus {
  TileSourceStatus._();
  static final ValueNotifier<String> active =
      ValueNotifier<String>(MapTileConfig._initialGuess);
}

/// TileProvider yang mencoba beberapa sumber peta secara berurutan untuk
/// setiap tile. Dipakai supaya kalau kuota Mapbox habis (401/402/429, atau
/// error jaringan apapun), tile otomatis diambil dari MapTiler, dan kalau itu
/// juga gagal, baru diambil dari OpenStreetMap.
class _ChainedTileProvider extends TileProvider {
  final List<_TileSource> Function(TileCoordinates coordinates) buildSources;
  _ChainedTileProvider(this.buildSources);

  static final Map<String, DateTime> _unavailableUntil = {};
  static final Map<String, Future<Uint8List>> _inFlight = {};
  static final http.Client _client = http.Client();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _ChainedNetworkImage(buildSources(coordinates));
  }
}

class _ChainedNetworkImage extends ImageProvider<_ChainedNetworkImage> {
  final List<_TileSource> sources;
  const _ChainedNetworkImage(this.sources);

  @override
  Future<_ChainedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_ChainedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _ChainedNetworkImage key,
    // decode bawaan tidak dipakai; kita decode manual lewat dart:ui supaya
    // tidak terikat versi API tertentu.
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(),
      scale: 1.0,
      debugLabel: sources.isNotEmpty ? sources.first.url : 'chained-tile',
    );
  }

  Future<ui.Codec> _load() async {
    Object? lastError;
    for (final source in sources) {
      final unavailable = _ChainedTileProvider._unavailableUntil[source.label];
      if (unavailable != null && DateTime.now().isBefore(unavailable)) continue;
      try {
        final cached = await _TileCache.read(source.url);
        final bytes = cached ?? await _download(source);
        if (bytes.isNotEmpty) {
          // Tile ini beneran berhasil dari `source.label` -> catat sebagai
          // sumber aktif saat ini supaya teks atribusi ikut jujur.
          if (TileSourceStatus.active.value != source.label) {
            TileSourceStatus.active.value = source.label;
          }
          if (cached == null) unawaited(_TileCache.write(source.url, bytes));
          _ChainedTileProvider._unavailableUntil.remove(source.label);
          return ui.instantiateImageCodec(bytes);
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Semua sumber tile gagal dimuat.');
  }

  Future<Uint8List> _download(_TileSource source) {
    final existing = _ChainedTileProvider._inFlight[source.url];
    if (existing != null) return existing;
    final request = _fetch(source);
    _ChainedTileProvider._inFlight[source.url] = request;
    return request
        .whenComplete(() => _ChainedTileProvider._inFlight.remove(source.url));
  }

  Future<Uint8List> _fetch(_TileSource source) async {
    try {
      final response = await _ChainedTileProvider._client
          .get(Uri.parse(source.url), headers: {
        'User-Agent': 'com.safezone.app'
      }).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      debugPrint(
          '[MapTiles] ${source.label} returned HTTP ${response.statusCode}');
      if (response.statusCode == 401 ||
          response.statusCode == 402 ||
          response.statusCode == 403 ||
          response.statusCode == 429) {
        _ChainedTileProvider._unavailableUntil[source.label] =
            DateTime.now().add(const Duration(minutes: 5));
      }
      throw HttpException('${source.label} tile HTTP ${response.statusCode}');
    } on TimeoutException catch (error) {
      debugPrint('[MapTiles] ${source.label} timed out: $error');
      _ChainedTileProvider._unavailableUntil[source.label] =
          DateTime.now().add(const Duration(seconds: 30));
      rethrow;
    } on SocketException catch (error) {
      debugPrint('[MapTiles] ${source.label} network error: $error');
      _ChainedTileProvider._unavailableUntil[source.label] =
          DateTime.now().add(const Duration(seconds: 30));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! _ChainedNetworkImage) return false;
    if (sources.length != other.sources.length) return false;
    for (var i = 0; i < sources.length; i++) {
      if (sources[i].url != other.sources[i].url) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(sources.map((s) => s.url));
}

class OpenStreetMapFallback extends StatelessWidget {
  const OpenStreetMapFallback({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OpenStreetMapFallbackPainter(dense: dense),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xEFFFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: ValueListenableBuilder<String>(
                valueListenable: TileSourceStatus.active,
                builder: (context, label, _) => Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenStreetMapFallbackPainter extends CustomPainter {
  const _OpenStreetMapFallbackPainter({required this.dense});

  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1EDE5),
    );

    final blockPaint = Paint()..color = const Color(0xFFE3D8CA);
    final parkPaint = Paint()..color = const Color(0xFFDCE8D1);
    final waterPaint = Paint()..color = const Color(0xFFD3E5EC);
    final roadPaint = Paint()
      ..color = const Color(0xFFFEFCF7)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = dense ? 8 : 14;
    final smallRoadPaint = Paint()
      ..color = const Color(0xFFF7F2EA)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = dense ? 4 : 7;
    final outlinePaint = Paint()
      ..color = const Color(0xFFD8C9B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(Offset(size.width * .82, size.height * .18),
        math.min(size.width, size.height) * .18, parkPaint);
    canvas.drawCircle(Offset(size.width * .08, size.height * .85),
        math.min(size.width, size.height) * .22, waterPaint);

    final cell = dense ? 54.0 : 82.0;
    for (double x = -20; x < size.width; x += cell) {
      for (double y = -14; y < size.height; y += cell * .8) {
        final rect = Rect.fromLTWH(
          x + 14,
          y + 12,
          cell * .48,
          cell * .3,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          blockPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          outlinePaint,
        );
      }
    }

    void road(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    road([
      Offset(-20, size.height * .25),
      Offset(size.width * .35, size.height * .33),
      Offset(size.width + 20, size.height * .22),
    ], roadPaint);
    road([
      Offset(size.width * .2, -20),
      Offset(size.width * .36, size.height * .45),
      Offset(size.width * .42, size.height + 20),
    ], roadPaint);
    road([
      Offset(-20, size.height * .68),
      Offset(size.width * .46, size.height * .58),
      Offset(size.width + 20, size.height * .72),
    ], smallRoadPaint);
    road([
      Offset(size.width * .68, -20),
      Offset(size.width * .62, size.height * .38),
      Offset(size.width * .77, size.height + 20),
    ], smallRoadPaint);
  }

  @override
  bool shouldRepaint(covariant _OpenStreetMapFallbackPainter oldDelegate) =>
      dense != oldDelegate.dense;
}
