import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../app_colors.dart';

class OpenStreetMapTileLayer extends StatelessWidget {
  const OpenStreetMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    if (MapTileConfig.usesMapbox) {
      return TileLayer(
        urlTemplate:
            'https://api.mapbox.com/styles/v1/${MapTileConfig.mapboxStyle}/tiles/256/{z}/{x}/{y}@2x?access_token=${MapTileConfig.mapboxToken}',
        userAgentPackageName: 'com.safezone.app',
        maxZoom: 22,
        additionalOptions: const {
          'accessToken': MapTileConfig.mapboxToken,
          'id': MapTileConfig.mapboxStyle,
        },
      );
    }

    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.safezone.app',
      maxZoom: 19,
    );
  }
}

class MapTileConfig {
  static const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const mapboxStyle = String.fromEnvironment(
    'MAPBOX_STYLE',
    defaultValue: 'mapbox/navigation-day-v1',
  );

  static const usesMapbox = mapboxToken != '';
  static const attribution = usesMapbox ? 'Mapbox' : 'OpenStreetMap';
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
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Text(
                MapTileConfig.attribution,
                style: TextStyle(
                  color: AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
