import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../app_colors.dart';
import '../services/laporan_service.dart';
import '../models/laporan_model.dart';
import '../widgets/open_street_map_tile_layer.dart';
import 'detail_laporan_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _fromCtrl = TextEditingController(text: 'Monas, Jakarta');
  final _toCtrl = TextEditingController();
  final _distance = const Distance();
  Timer? _suggestionDebounce;
  StreamSubscription<Position>? _positionSub;
  List<LaporanModel> _laporan = [];
  List<_PlaceSuggestion> _suggestions = [];
  LaporanModel? _selectedLaporan;
  _SafeRoute? _route;
  LatLng? _fromPoint;
  LatLng? _toPoint;
  _RouteFieldType _activeField = _RouteFieldType.to;
  LatLng? _currentPosition;
  bool _navigating = false;
  bool _followUser = true;
  bool _routing = false;
  bool _loadingSuggestions = false;
  String? _routeError;
  final LatLng _defaultCenter = const LatLng(-6.200000, 106.816666);

  @override
  void initState() {
    super.initState();
    LaporanService.streamAll().listen((list) {
      if (mounted) setState(() => _laporan = list);
    });
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _positionSub?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  List<LaporanModel> get _begalReports => _laporan
      .where((l) => l.geoPoint != null && l.kategori.toLowerCase() == 'begal')
      .toList();

  Future<void> _searchRoute() async {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      _showRouteError('Isi asal dan tujuan dulu ya.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _routing = true;
      _routeError = null;
      _selectedLaporan = null;
    });

    try {
      final start = _fromPoint ?? await _geocode(from);
      final end = _toPoint ?? await _geocode(to);
      final safeRoute = await _buildSafeRoute(start, end);
      if (!mounted) return;
      setState(() => _route = safeRoute);
      _fitRoute(safeRoute.points);
    } catch (e) {
      if (mounted)
        _showRouteError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _onFieldChanged(_RouteFieldType field, String value) {
    setState(() {
      _activeField = field;
      if (field == _RouteFieldType.from) {
        _fromPoint = null;
      } else {
        _toPoint = null;
      }
    });
    _suggestionDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 450), () {
      _loadSuggestions(value.trim());
    });
  }

  Future<void> _loadSuggestions(String query) async {
    setState(() => _loadingSuggestions = true);
    try {
      final results = await _searchPlaces(query);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _selectSuggestion(_PlaceSuggestion place) {
    setState(() {
      if (_activeField == _RouteFieldType.from) {
        _fromCtrl.text = place.title;
        _fromPoint = place.point;
      } else {
        _toCtrl.text = place.title;
        _toPoint = place.point;
      }
      _suggestions = [];
      _routeError = null;
    });
    _mapController.move(place.point, 15);
  }

  void _setPointFromMap(LatLng point) {
    setState(() {
      _selectedLaporan = null;
      if (_activeField == _RouteFieldType.from) {
        _fromPoint = point;
        _fromCtrl.text =
            'Titik peta ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      } else {
        _toPoint = point;
        _toCtrl.text =
            'Titik peta ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      _suggestions = [];
    });
  }

  Future<void> _startNavigation() async {
    final route = _route;
    if (route?.start == null || route?.end == null) return;
    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) return;

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateCurrentPosition(current);
      setState(() {
        _navigating = true;
        _followUser = true;
      });

      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen(_updateCurrentPosition);
    } catch (_) {
      _showRouteError('Tidak bisa membaca lokasi perangkat.');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showRouteError('Nyalakan GPS/lokasi dulu untuk navigasi.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showRouteError('Izin lokasi dibutuhkan untuk navigasi di SafeZone.');
      return false;
    }
    return true;
  }

  void _updateCurrentPosition(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = point);
    if (_navigating && _followUser) {
      _mapController.move(point, 17);
    }
  }

  Future<void> _stopNavigation() async {
    await _positionSub?.cancel();
    _positionSub = null;
    if (mounted) {
      setState(() {
        _navigating = false;
        _followUser = false;
      });
    }
  }

  String get _navigationDistanceText {
    final current = _currentPosition;
    final end = _route?.end;
    if (current == null || end == null) return 'Menunggu GPS...';
    final meters = _distance(current, end);
    if (meters < 80) return 'Sudah dekat tujuan';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km lagi';
    return '${meters.round()} m lagi';
  }

  void _showRouteError(String message) {
    setState(() => _routeError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<LatLng> _geocode(String query) async {
    final places = await _searchPlaces(query, limit: 1);
    if (places.isEmpty) throw Exception('Lokasi "$query" tidak ditemukan.');
    return places.first.point;
  }

  Future<List<_PlaceSuggestion>> _searchPlaces(String query,
      {int limit = 5}) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
      'countrycodes': 'id',
    });
    final res = await http.get(uri, headers: {
      'User-Agent': 'SafeZone/1.0 (safezone-app)',
    });
    if (res.statusCode != 200) {
      throw Exception('Gagal mencari lokasi "$query".');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((raw) {
      final item = raw as Map<String, dynamic>;
      final displayName = (item['display_name'] as String?) ?? query;
      final parts = displayName.split(',').map((e) => e.trim()).toList();
      return _PlaceSuggestion(
        title: parts.take(2).join(' '),
        subtitle: parts.skip(2).take(4).join(', '),
        point: LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
      );
    }).toList();
  }

  Future<_SafeRoute> _buildSafeRoute(LatLng start, LatLng end) async {
    final direct = await _fetchRoute([start, end]);
    final danger = _nearestDangerToRoute(direct.points);
    if (danger == null || danger.distanceMeters > 260) {
      return direct.copyWith(
        start: start,
        end: end,
        status: 'Rute normal',
        note: _begalReports.isEmpty
            ? 'Belum ada titik Begal aktif di sekitar rute.'
            : 'Rute tidak melewati titik Begal terdekat.',
      );
    }

    final alternatives = <_SafeRoute>[];
    for (final side in [-1, 1]) {
      final via = _avoidanceWaypoint(start, end, danger.point, side);
      try {
        alternatives.add(await _fetchRoute([start, via, end]));
      } catch (_) {
        // Public OSRM can reject a waypoint; try the other side.
      }
    }

    if (alternatives.isEmpty) {
      return direct.copyWith(
        start: start,
        end: end,
        danger: danger,
        status: 'Rute rawan',
        note: 'Belum dapat membuat rute alternatif dari layanan OSM.',
      );
    }

    alternatives.sort((a, b) {
      final aRisk = _nearestDangerToRoute(a.points)?.distanceMeters ?? 999999;
      final bRisk = _nearestDangerToRoute(b.points)?.distanceMeters ?? 999999;
      final riskCompare = bRisk.compareTo(aRisk);
      if (riskCompare != 0) return riskCompare;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    final best = alternatives.first;
    final bestDanger = _nearestDangerToRoute(best.points);
    final tooLong = best.distanceMeters > direct.distanceMeters * 1.8;
    if (tooLong) {
      return direct.copyWith(
        start: start,
        end: end,
        danger: danger,
        status: 'Rute rawan',
        note:
            'Rute alternatif terlalu memutar, jadi tetap tampilkan rute utama.',
      );
    }

    return best.copyWith(
      start: start,
      end: end,
      danger: bestDanger,
      status: 'Rute lebih aman',
      note:
          'Rute dialihkan menjauh dari laporan Begal sekitar ${danger.distanceMeters.round()} m dari jalur utama.',
    );
  }

  Future<_SafeRoute> _fetchRoute(List<LatLng> points) async {
    final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&alternatives=false&steps=false');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Gagal mengambil rute.');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) throw Exception('Rute tidak ditemukan.');

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    return _SafeRoute(
      points: coordinates.map((coord) {
        final pair = coord as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList(),
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }

  _DangerPoint? _nearestDangerToRoute(List<LatLng> route) {
    _DangerPoint? nearest;
    for (final laporan in _begalReports) {
      final point =
          LatLng(laporan.geoPoint!.latitude, laporan.geoPoint!.longitude);
      final distance = _minDistanceToPolyline(point, route);
      if (nearest == null || distance < nearest.distanceMeters) {
        nearest = _DangerPoint(point, laporan, distance);
      }
    }
    return nearest;
  }

  double _minDistanceToPolyline(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;
    var best = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final distance = _distanceToSegmentMeters(point, route[i], route[i + 1]);
      if (distance < best) best = distance;
    }
    return best;
  }

  double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final latScale = 111320.0;
    final lngScale = latScale * math.cos(a.latitude * math.pi / 180);
    final px = (p.longitude - a.longitude) * lngScale;
    final py = (p.latitude - a.latitude) * latScale;
    final bx = (b.longitude - a.longitude) * lngScale;
    final by = (b.latitude - a.latitude) * latScale;
    final lenSq = bx * bx + by * by;
    if (lenSq == 0) return _distance(p, a);
    final t = ((px * bx + py * by) / lenSq).clamp(0.0, 1.0);
    final projX = bx * t;
    final projY = by * t;
    return math.sqrt(math.pow(px - projX, 2) + math.pow(py - projY, 2));
  }

  LatLng _avoidanceWaypoint(LatLng start, LatLng end, LatLng danger, int side) {
    final latScale = 111320.0;
    final lngScale = latScale * math.cos(danger.latitude * math.pi / 180);
    var vx = (end.longitude - start.longitude) * lngScale;
    var vy = (end.latitude - start.latitude) * latScale;
    final len = math.sqrt(vx * vx + vy * vy);
    if (len == 0) return danger;
    vx /= len;
    vy /= len;
    final offsetMeters = 750.0;
    final ox = -vy * side * offsetMeters;
    final oy = vx * side * offsetMeters;
    return LatLng(
      danger.latitude + oy / latScale,
      danger.longitude + ox / lngScale,
    );
  }

  void _fitRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final span = math.max(maxLat - minLat, maxLng - minLng);
    final zoom = span < 0.01
        ? 15.0
        : span < 0.035
            ? 13.5
            : span < 0.08
                ? 12.2
                : 11.0;
    _mapController.move(center, zoom);
  }

  List<Marker> _buildMarkers() {
    return _laporan.where((l) => l.geoPoint != null).map((l) {
      final pos = LatLng(l.geoPoint!.latitude, l.geoPoint!.longitude);
      return Marker(
        point: pos,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedLaporan = l);
            _mapController.move(pos, 16);
          },
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  _iconForKategori(l.kategori),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              Container(
                width: 2,
                height: 6,
                color: AppColors.red,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildRouteMarkers(_SafeRoute route) {
    if (route.start == null || route.end == null) return [];
    return [
      Marker(
        point: route.start!,
        width: 42,
        height: 42,
        child: const _RoutePin(
          icon: Icons.trip_origin_rounded,
          color: Color(0xFF16A34A),
        ),
      ),
      Marker(
        point: route.end!,
        width: 42,
        height: 42,
        child: const _RoutePin(
          icon: Icons.flag_rounded,
          color: AppColors.red,
        ),
      ),
      if (route.danger != null)
        Marker(
          point: route.danger!.point,
          width: 46,
          height: 46,
          child: const _RoutePin(
            icon: Icons.motorcycle_rounded,
            color: Color(0xFF991B1B),
          ),
        ),
    ];
  }

  IconData _iconForKategori(String k) {
    switch (k) {
      case 'Begal':
        return Icons.motorcycle_rounded;
      case 'Tawuran':
        return Icons.people_alt_rounded;
      case 'Kecelakaan':
        return Icons.directions_car_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── OpenStreetMap ──
          Stack(
            fit: StackFit.expand,
            children: [
              const OpenStreetMapFallback(),
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 13,
                  onTap: (_, point) => _setPointFromMap(point),
                ),
                children: [
                  const OpenStreetMapTileLayer(),
                  if (_route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route!.points,
                          strokeWidth: 7,
                          color: Colors.white,
                        ),
                        Polyline(
                          points: _route!.points,
                          strokeWidth: 4,
                          color: _route!.isSafer
                              ? const Color(0xFF16A34A)
                              : AppColors.red,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: _buildMarkers()),
                  if (_route != null)
                    MarkerLayer(markers: _buildRouteMarkers(_route!)),
                  if (_currentPosition != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 46,
                        height: 46,
                        child: const _CurrentLocationMarker(),
                      )
                    ]),
                ],
              ),
              const Positioned(
                left: 10,
                bottom: 10,
                child: IgnorePointer(
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
            ],
          ),

          if (!_navigating)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xECFFF8F1),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(children: [
                          const Icon(Icons.shield_rounded,
                              color: AppColors.red, size: 20),
                          const SizedBox(width: 6),
                          Text('SafeZone',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.red)),
                        ]),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xECFFF8F1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(Icons.account_circle_rounded,
                            color: AppColors.text2, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Route search ──
          if (!_navigating)
            Positioned(
              top: 78,
              left: 16,
              right: 16,
              child: SafeArea(
                child: _RouteSearchCard(
                  fromCtrl: _fromCtrl,
                  toCtrl: _toCtrl,
                  loading: _routing,
                  error: _routeError,
                  route: _route,
                  activeField: _activeField,
                  suggestions: _suggestions,
                  loadingSuggestions: _loadingSuggestions,
                  onSearch: _searchRoute,
                  onStartNavigation: _startNavigation,
                  onFieldChanged: _onFieldChanged,
                  onFieldFocus: (field) => setState(() => _activeField = field),
                  onSuggestionSelected: _selectSuggestion,
                  onClear: () {
                    setState(() {
                      _route = null;
                      _routeError = null;
                      _suggestions = [];
                    });
                    _mapController.move(_defaultCenter, 13);
                  },
                ),
              ),
            ),

          if (_navigating && _route != null)
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: SafeArea(
                child: _NavigationHeader(
                  route: _route!,
                  distanceText: _navigationDistanceText,
                ),
              ),
            ),

          if (_navigating && _route != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: _NavigationPanel(
                route: _route!,
                distanceText: _navigationDistanceText,
                following: _followUser,
                onRecenter: () {
                  final current = _currentPosition;
                  if (current == null) return;
                  setState(() => _followUser = true);
                  _mapController.move(current, 17);
                },
                onStop: _stopNavigation,
              ),
            ),

          if (!_navigating)
            Positioned(
              top: 250,
              left: 20,
              child: SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        '${_laporan.where((l) => l.geoPoint != null).length} Laporan Aktif',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Reset view button ──
          Positioned(
            bottom: _navigating
                ? 150
                : _selectedLaporan != null
                    ? 220
                    : 30,
            right: 16,
            child: GestureDetector(
              onTap: () => _mapController.move(_defaultCenter, 13),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.red, size: 22),
              ),
            ),
          ),

          // ── Bottom sheet laporan terpilih ──
          if (_selectedLaporan != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _LaporanBottomCard(
                laporan: _selectedLaporan!,
                onClose: () => setState(() => _selectedLaporan = null),
                onDetail: () {
                  if (_selectedLaporan!.id != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DetailLaporanScreen(laporanId: _selectedLaporan!.id!),
                    ));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bottom Card saat marker dipilih ──
class _LaporanBottomCard extends StatelessWidget {
  final LaporanModel laporan;
  final VoidCallback onClose;
  final VoidCallback onDetail;

  const _LaporanBottomCard({
    required this.laporan,
    required this.onClose,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(50)),
                child: Text(laporan.kategori,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.text3, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.redLight, shape: BoxShape.circle),
              child: Icon(_iconForKategori(laporan.kategori),
                  color: AppColors.red, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(laporan.kategori,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  Text(laporan.lokasi,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppColors.text2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
          if (laporan.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(laporan.imageUrl!,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ],
          const SizedBox(height: 10),
          Text(laporan.deskripsi,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.text2, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Row(children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.red, size: 14),
                const SizedBox(width: 4),
                Text('${laporan.konfirmasi} Verifikasi',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.red,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            ElevatedButton(
              onPressed: onDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              child: Text('Lihat Detail',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _RouteSearchCard extends StatelessWidget {
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final bool loading;
  final bool loadingSuggestions;
  final String? error;
  final _SafeRoute? route;
  final _RouteFieldType activeField;
  final List<_PlaceSuggestion> suggestions;
  final VoidCallback onSearch;
  final VoidCallback onStartNavigation;
  final void Function(_RouteFieldType field, String value) onFieldChanged;
  final ValueChanged<_RouteFieldType> onFieldFocus;
  final ValueChanged<_PlaceSuggestion> onSuggestionSelected;
  final VoidCallback onClear;

  const _RouteSearchCard({
    required this.fromCtrl,
    required this.toCtrl,
    required this.loading,
    required this.loadingSuggestions,
    required this.error,
    required this.route,
    required this.activeField,
    required this.suggestions,
    required this.onSearch,
    required this.onStartNavigation,
    required this.onFieldChanged,
    required this.onFieldFocus,
    required this.onSuggestionSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _RouteField(
                      controller: fromCtrl,
                      icon: Icons.trip_origin_rounded,
                      hint: 'Dari mana?',
                      active: activeField == _RouteFieldType.from,
                      onTap: () => onFieldFocus(_RouteFieldType.from),
                      onChanged: (value) =>
                          onFieldChanged(_RouteFieldType.from, value),
                    ),
                    const SizedBox(height: 8),
                    _RouteField(
                      controller: toCtrl,
                      icon: Icons.flag_rounded,
                      hint: 'Mau ke mana?',
                      active: activeField == _RouteFieldType.to,
                      onTap: () => onFieldFocus(_RouteFieldType.to),
                      onChanged: (value) =>
                          onFieldChanged(_RouteFieldType.to, value),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 104,
                child: ElevatedButton(
                  onPressed: loading ? null : onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    disabledBackgroundColor:
                        AppColors.red.withValues(alpha: .5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.alt_route_rounded, size: 25),
                ),
              ),
            ],
          ),
          if (loadingSuggestions || suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SuggestionList(
              loading: loadingSuggestions,
              suggestions: suggestions,
              onSelected: onSuggestionSelected,
            ),
          ],
          if (route != null || error != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error != null
                      ? Icons.error_rounded
                      : route!.isSafer
                          ? Icons.verified_user_rounded
                          : Icons.warning_rounded,
                  color: error != null
                      ? AppColors.red
                      : route!.isSafer
                          ? const Color(0xFF16A34A)
                          : AppColors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error ??
                        '${route!.status} • ${route!.distanceText} • ${route!.durationText}\n${route!.note}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.text3, size: 18),
                  ),
                ),
              ],
            ),
            if (route != null && error == null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStartNavigation,
                  icon: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 18),
                  label: Text('Mulai Navigasi',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07869A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  const _RouteField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.active,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.red : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        onTap: onTap,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.red, size: 18),
          hintText: hint,
          hintStyle:
              GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.text3),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final bool loading;
  final List<_PlaceSuggestion> suggestions;
  final ValueChanged<_PlaceSuggestion> onSelected;

  const _SuggestionList({
    required this.loading,
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 210),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream, width: 1),
      ),
      child: loading && suggestions.isEmpty
          ? const SizedBox(
              height: 54,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.red,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.cream),
              itemBuilder: (context, i) {
                final item = suggestions[i];
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: const Icon(Icons.location_on_outlined,
                      color: AppColors.text2, size: 23),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: item.subtitle.isEmpty
                      ? null
                      : Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.text2,
                          ),
                        ),
                  onTap: () => onSelected(item),
                );
              },
            ),
    );
  }
}

class _RoutePin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RoutePin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF07869A).withValues(alpha: .18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF07869A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationHeader extends StatelessWidget {
  final _SafeRoute route;
  final String distanceText;

  const _NavigationHeader({
    required this.route,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF047857),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.straight_rounded, color: Colors.white, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  route.isSafer
                      ? 'Ikuti rute aman SafeZone'
                      : 'Ikuti rute dengan hati-hati',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: .82),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  final _SafeRoute route;
  final String distanceText;
  final bool following;
  final VoidCallback onRecenter;
  final VoidCallback onStop;

  const _NavigationPanel({
    required this.route,
    required this.distanceText,
    required this.following,
    required this.onRecenter,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xF9FFFFFF),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF7F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation_rounded,
                color: Color(0xFF07869A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distanceText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.status} • ${route.durationText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        route.isSafer ? const Color(0xFF16A34A) : AppColors.red,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRecenter,
            tooltip: following ? 'Mengikuti lokasi' : 'Ikuti lokasi',
            icon: Icon(
              Icons.my_location_rounded,
              color: following ? const Color(0xFF07869A) : AppColors.text3,
            ),
          ),
          TextButton(
            onPressed: onStop,
            child: Text(
              'Stop',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng? start;
  final LatLng? end;
  final _DangerPoint? danger;
  final String status;
  final String note;

  const _SafeRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.start,
    this.end,
    this.danger,
    this.status = 'Rute normal',
    this.note = '',
  });

  bool get isSafer => status == 'Rute lebih aman' || status == 'Rute normal';

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes menit';
    return '${minutes ~/ 60}j ${minutes % 60}m';
  }

  _SafeRoute copyWith({
    LatLng? start,
    LatLng? end,
    _DangerPoint? danger,
    String? status,
    String? note,
  }) {
    return _SafeRoute(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      start: start ?? this.start,
      end: end ?? this.end,
      danger: danger ?? this.danger,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

class _DangerPoint {
  final LatLng point;
  final LaporanModel laporan;
  final double distanceMeters;

  const _DangerPoint(this.point, this.laporan, this.distanceMeters);
}

enum _RouteFieldType { from, to }

class _PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng point;

  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });
}

IconData _iconForKategori(String k) {
  switch (k) {
    case 'Begal':
      return Icons.motorcycle_rounded;
    case 'Tawuran':
      return Icons.people_alt_rounded;
    case 'Kecelakaan':
      return Icons.directions_car_rounded;
    default:
      return Icons.warning_rounded;
  }
}
