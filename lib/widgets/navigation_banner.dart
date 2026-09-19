import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Satu langkah navigasi (belok, lurus, bundaran, tiba, dst).
/// Format JSON kompatibel dengan OSRM dan Mapbox Directions.
class NavStep {
  final String type; // turn, roundabout, arrive, depart, ...
  final String? modifier; // left, right, slight left, sharp right, uturn, ...
  final String streetName;
  final double distance; // meter, panjang langkah ini
  final LatLng location; // titik manuver

  NavStep({
    required this.type,
    required this.modifier,
    required this.streetName,
    required this.distance,
    required this.location,
  });

  factory NavStep.fromJson(Map<String, dynamic> j) {
    final m = j['maneuver'] as Map<String, dynamic>;
    final loc = m['location'] as List<dynamic>;
    return NavStep(
      type: (m['type'] as String?) ?? 'turn',
      modifier: m['modifier'] as String?,
      streetName: (j['name'] as String?) ?? '',
      distance: (j['distance'] as num?)?.toDouble() ?? 0,
      location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
    );
  }
}

class NavRoute {
  final List<LatLng> points;
  final List<NavStep> steps;
  final double distance; // meter
  final double duration; // detik

  NavRoute(this.points, this.steps, this.distance, this.duration);
}

/// Melacak langkah aktif berdasarkan posisi GPS.
/// Panggil [updatePosition] setiap ada posisi baru dari geolocator.
class NavigationController extends ChangeNotifier {
  final NavRoute route;
  int index = 0; // langkah manuver yang akan datang
  double distanceToNext = 0;
  bool arrived = false;

  static const _dist = Distance();

  NavigationController(this.route) {
    // steps[0] = "depart" (mulai jalan), banner langsung menunjuk manuver berikutnya.
    if (route.steps.length > 1) {
      index = 1;
      distanceToNext = route.steps[0].distance;
    } else {
      distanceToNext = route.distance;
    }
  }

  NavStep get current => route.steps[index];
  NavStep? get next =>
      index + 1 < route.steps.length ? route.steps[index + 1] : null;

  void updatePosition(LatLng pos) {
    if (arrived) return;
    distanceToNext = _dist(pos, route.steps[index].location);

    // Sudah dekat titik manuver -> maju ke langkah berikutnya.
    if (distanceToNext < 25) {
      if (index + 1 < route.steps.length) {
        index++;
        distanceToNext = _dist(pos, route.steps[index].location);
      } else {
        arrived = true;
      }
    }
    notifyListeners();
  }
}

/// Ikon belok berdasarkan maneuver.
IconData maneuverIcon(String type, String? modifier) {
  if (type == 'arrive') return Icons.place;
  if (type == 'roundabout' || type == 'rotary') {
    return (modifier ?? '').contains('left')
        ? Icons.roundabout_left
        : Icons.roundabout_right;
  }
  switch (modifier) {
    case 'left':
      return Icons.turn_left;
    case 'right':
      return Icons.turn_right;
    case 'slight left':
      return Icons.turn_slight_left;
    case 'slight right':
      return Icons.turn_slight_right;
    case 'sharp left':
      return Icons.turn_sharp_left;
    case 'sharp right':
      return Icons.turn_sharp_right;
    case 'uturn':
      return Icons.u_turn_left;
    case 'straight':
    default:
      return Icons.straight;
  }
}

/// Teks instruksi bahasa Indonesia, misal "Belok kanan ke Jl. Sudirman".
String stepInstruction(NavStep s) {
  if (s.type == 'arrive') return 'Tiba di tujuan';

  String action;
  if (s.type == 'roundabout' || s.type == 'rotary') {
    action = 'Masuk bundaran';
  } else {
    switch (s.modifier) {
      case 'left':
        action = 'Belok kiri';
        break;
      case 'right':
        action = 'Belok kanan';
        break;
      case 'slight left':
        action = 'Serong kiri';
        break;
      case 'slight right':
        action = 'Serong kanan';
        break;
      case 'sharp left':
        action = 'Belok tajam ke kiri';
        break;
      case 'sharp right':
        action = 'Belok tajam ke kanan';
        break;
      case 'uturn':
        action = 'Putar balik';
        break;
      default:
        action = 'Lurus';
    }
  }
  return s.streetName.isNotEmpty ? '$action ke ${s.streetName}' : action;
}

String formatNavDistance(double m) {
  if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
  // dibulatkan ke 10 m terdekat supaya angka tidak "berkedip"
  return '${(m / 10).round() * 10} m';
}

/// Banner atas ala Google Maps: ikon belok besar + jarak + instruksi, dan chip "Lalu".
class NavigationBanner extends StatelessWidget {
  final NavigationController controller;

  const NavigationBanner({super.key, required this.controller});

  static const _green = Color(0xFF00664F);
  static const _greenDark = Color(0xFF004D3B);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final step = controller.current;
        final next = controller.next;
        final arrived = controller.arrived;

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: _green,
                  elevation: 6,
                  borderRadius: (next == null || arrived)
                      ? BorderRadius.circular(20)
                      : const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Icon(
                          arrived
                              ? Icons.place
                              : maneuverIcon(step.type, step.modifier),
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!arrived)
                                Text(
                                  formatNavDistance(controller.distanceToNext),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              Text(
                                arrived
                                    ? 'Tiba di tujuan'
                                    : stepInstruction(step),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (next != null && !arrived)
                  Material(
                    color: _greenDark,
                    elevation: 6,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Lalu',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(width: 8),
                          Icon(maneuverIcon(next.type, next.modifier),
                              color: Colors.white, size: 26),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
