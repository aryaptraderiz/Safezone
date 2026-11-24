import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../app_colors.dart';
import '../services/laporan_service.dart';
import '../services/saved_location_service.dart';
import '../models/laporan_model.dart';
import '../models/saved_location_model.dart';
import '../widgets/navigation_banner.dart';
import '../widgets/open_street_map_tile_layer.dart';
import '../widgets/place_photo.dart';
import '../widgets/report_video_player.dart';
import 'detail_laporan_screen.dart';
import 'saved_locations_screen.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialTarget;
  final String? initialTargetLabel;

  const MapScreen({super.key, this.initialTarget, this.initialTargetLabel});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _distance = const Distance();
  Timer? _suggestionDebounce;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<SavedLocationModel>>? _savedLocationSub;
  List<LaporanModel> _laporan = [];
  List<SavedLocationModel> _savedLocations = [];
  List<_PlaceSuggestion> _suggestions = [];
  LaporanModel? _selectedLaporan;
  _MapPlaceInfo? _selectedMapPlace;
  _SafeRoute? _route;
  LatLng? _fromPoint;
  LatLng? _toPoint;
  _RouteFieldType _activeField = _RouteFieldType.to;
  LatLng? _currentPosition;
  double _speedKmh = 0;
  NavigationController? _nav;
  bool _navigating = false;
  bool _followUser = true;
  bool _routing = false;
  bool _loadingSuggestions = false;
  bool _loadingMapPlace = false;
  String? _routeError;
  final LatLng _defaultCenter = const LatLng(-6.200000, 106.816666);

  // ── Reroute otomatis saat keluar jalur ──
  bool _rerouting = false;
  bool _locating = false;
  int _offRouteCount = 0;
  DateTime? _lastReroute;

  // Token sesi Mapbox Search Box (satu sesi = beberapa suggest + 1 retrieve).
  String _sessionToken = _newSessionToken();

  @override
  void initState() {
    super.initState();
    LaporanService.streamAll().listen((list) {
      if (mounted) setState(() => _laporan = list);
    });
    _savedLocationSub = SavedLocationService.streamAll().listen((list) {
      if (mounted) setState(() => _savedLocations = list);
    });
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _positionSub?.cancel();
    _savedLocationSub?.cancel();
    _nav?.dispose();
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
      _selectedMapPlace = null;
    });

    try {
      final start = (from == 'Lokasi saya' && _currentPosition != null)
          ? _currentPosition!
          : (_fromPoint ?? await _geocode(from));
      final end = _toPoint ?? await _geocode(to);
      final safeRoute = await _buildSafeRoute(start, end);
      if (!mounted) return;
      setState(() => _route = safeRoute);
      _fitRoute(safeRoute.points);
    } catch (e) {
      if (mounted) {
        _showRouteError(e.toString().replaceFirst('Exception: ', ''));
      }
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

  Future<void> _selectSuggestion(_PlaceSuggestion place) async {
    LatLng point;
    try {
      // Hasil Mapbox belum punya koordinat, diambil lewat retrieve.
      point = await _resolvePlace(place);
    } catch (_) {
      if (mounted) _showRouteError('Gagal mengambil lokasi "${place.title}".');
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_activeField == _RouteFieldType.from) {
        _fromCtrl.text = place.title;
        _fromPoint = point;
      } else {
        _toCtrl.text = place.title;
        _toPoint = point;
      }
      _suggestions = [];
      _routeError = null;
    });
    _mapController.move(point, 15);
  }

  void _selectSavedLocation(SavedLocationModel loc) {
    final point = LatLng(loc.point.latitude, loc.point.longitude);
    _selectSuggestion(_PlaceSuggestion(
      title: loc.label,
      subtitle: loc.address,
      point: point,
    ));
  }

  Future<void> _selectMapPlace(LatLng point) async {
    final fallback = _MapPlaceInfo(
      point: point,
      title: 'Titik peta',
      subtitle: _formatCoordinate(point),
      coordinate: _formatCoordinate(point),
      source: TileSourceStatus.active.value,
    );

    setState(() {
      _selectedLaporan = null;
      _selectedMapPlace = fallback;
      _loadingMapPlace = true;
      _suggestions = [];
      _routeError = null;
    });

    final info = await _reverseGeocodePlace(point);
    if (!mounted) return;

    setState(() {
      _selectedMapPlace = info ?? fallback;
      _loadingMapPlace = false;
    });
  }

  void _useMapPlaceAs(_RouteFieldType field, _MapPlaceInfo info) {
    setState(() {
      _activeField = field;
      _selectedMapPlace = null;
      _routeError = null;
      _suggestions = [];
      if (field == _RouteFieldType.from) {
        _fromPoint = info.point;
        _fromCtrl.text = info.title;
      } else {
        _toPoint = info.point;
        _toCtrl.text = info.title;
      }
    });
  }

  String _formatCoordinate(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

  Future<_MapPlaceInfo?> _reverseGeocodePlace(LatLng point) async {
    final mapbox = await _reverseWithMapbox(point);
    if (mapbox != null) return mapbox;

    final maptiler = await _reverseWithMapTiler(point);
    if (maptiler != null) return maptiler;

    return _reverseWithNominatim(point);
  }

  Future<_MapPlaceInfo?> _reverseWithMapbox(LatLng point) async {
    if (!MapTileConfig.usesMapbox) return null;
    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json',
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

      final feature = features.first as Map<String, dynamic>;
      final title = _cleanText(feature['text'] as String?) ??
          _firstAddressPart(feature['place_name'] as String?);
      if (title == null) return null;

      final placeName = _cleanText(feature['place_name'] as String?);
      final types = (feature['place_type'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .join(', ');
      return _MapPlaceInfo(
        point: point,
        title: title,
        subtitle: _subtitleWithoutTitle(placeName, title),
        coordinate: _formatCoordinate(point),
        source: 'Mapbox',
        category: types,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_MapPlaceInfo?> _reverseWithMapTiler(LatLng point) async {
    if (!MapTileConfig.usesMapTiler) return null;
    try {
      final uri = Uri.https(
        'api.maptiler.com',
        '/geocoding/${point.longitude},${point.latitude}.json',
        {
          'key': MapTileConfig.maptilerKey,
          'language': 'id',
          'limit': '1',
        },
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'com.safezone.app'
      }).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      final title = _cleanText(feature['text'] as String?) ??
          _firstAddressPart(feature['place_name'] as String?);
      if (title == null) return null;

      final placeName = _cleanText(feature['place_name'] as String?);
      final properties = feature['properties'] as Map<String, dynamic>?;
      final type = _cleanText(properties?['kind']?.toString());
      return _MapPlaceInfo(
        point: point,
        title: title,
        subtitle: _subtitleWithoutTitle(placeName, title),
        coordinate: _formatCoordinate(point),
        source: 'MapTiler',
        category: type,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_MapPlaceInfo?> _reverseWithNominatim(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'SafeZone/1.0 (safezone-app)',
      }).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      final title = _cleanText(data['name'] as String?) ??
          _cleanText(address?['road'] as String?) ??
          _firstAddressPart(data['display_name'] as String?) ??
          'Titik peta';
      final displayName = data['display_name'] as String?;
      final type = _cleanText(data['type'] as String?);
      return _MapPlaceInfo(
        point: point,
        title: title,
        subtitle: _subtitleWithoutTitle(displayName, title),
        coordinate: _formatCoordinate(point),
        source: 'OpenStreetMap',
        category: type,
      );
    } catch (_) {
      return null;
    }
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _firstAddressPart(String? value) {
    final text = _cleanText(value);
    if (text == null) return null;
    return text.split(',').first.trim();
  }

  String? _subtitleWithoutTitle(String? value, String title) {
    final text = _cleanText(value);
    if (text == null) return null;
    final trimmed = text.startsWith('$title,')
        ? text.substring(title.length + 1).trim()
        : text;
    return trimmed == title ? null : trimmed;
  }

  Future<void> _promptSaveLocation(LatLng point) async {
    final presetCtrl = TextEditingController();
    String? chosenPreset = 'Rumah';

    final result = await showModalBottomSheet<_SaveLocationResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Simpan lokasi ini',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        _PresetChip(
                          label: 'Rumah',
                          icon: Icons.home_rounded,
                          selected: chosenPreset == 'Rumah',
                          onTap: () =>
                              setSheetState(() => chosenPreset = 'Rumah'),
                        ),
                        _PresetChip(
                          label: 'Kantor',
                          icon: Icons.work_rounded,
                          selected: chosenPreset == 'Kantor',
                          onTap: () =>
                              setSheetState(() => chosenPreset = 'Kantor'),
                        ),
                        _PresetChip(
                          label: 'Lainnya',
                          icon: Icons.place_rounded,
                          selected: chosenPreset == null,
                          onTap: () => setSheetState(() => chosenPreset = null),
                        ),
                      ],
                    ),
                    if (chosenPreset == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: presetCtrl,
                        decoration: InputDecoration(
                          hintText: 'Nama lokasi, misal "Rumah Nenek"',
                          filled: true,
                          fillColor: AppColors.cream,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final label = chosenPreset ?? presetCtrl.text.trim();
                          if (label.isEmpty) return;
                          Navigator.of(ctx).pop(_SaveLocationResult(label));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Simpan',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      await SavedLocationService.save(
        label: result.label,
        address:
            'Titik peta ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        lat: point.latitude,
        lng: point.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${result.label}" tersimpan.',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showRouteError('Gagal menyimpan lokasi: $e');
      }
    }
  }

  /// Buka pratinjau rute tanpa memerlukan izin atau sinyal GPS.
  void _openRoutePreview() {
    final route = _route;
    if (route == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _RoutePreviewScreen(route: route),
    ));
  }

  Future<void> _startNavigation() async {
    final route = _route;
    if (route == null || route.start == null || route.end == null) return;
    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) return;

      // Siapkan pelacak belokan (banner ala Google Maps).
      _nav?.dispose();
      _nav = null;

      _offRouteCount = 0;
      _lastReroute = null;
      setState(() {
        _navigating = true;
        _followUser = true;
      });

      await _listenForPositionUpdates(accuracy: LocationAccuracy.high);

      // Start guidance immediately; the first GPS fix may arrive later.
      final current = await _readDevicePosition();
      if (!mounted || !_navigating) return;
      if (current != null) _updateCurrentPosition(current);

      // Kalau posisi kita jauh dari rute yang dipilih (misal titik asal beda
      // dengan lokasi sekarang), langsung hitung rute baru dari posisi kita.
      if (current != null) {
        final here = LatLng(current.latitude, current.longitude);
        if (_minDistanceToPolyline(here, route.points) > 100) {
          _rerouteFrom(here);
        }
      } else {
        _showInfo('Navigasi dimulai. Menunggu sinyal GPS...');
      }
    } catch (error) {
      _showInfo(_locationFailureMessage(error));
    }
  }

  Future<Position?> _readDevicePosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      ).timeout(const Duration(seconds: 9));
    } catch (_) {
      // A network-assisted fix is often available before a full GPS fix.
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          forceAndroidLocationManager: true,
          timeLimit: const Duration(seconds: 8),
        ).timeout(const Duration(seconds: 9));
      } catch (_) {
        // Some Android devices work better with the platform LocationManager.
      }
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
    } catch (_) {
      // Fall through to a high-accuracy request and the active stream.
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (lastKnown != null) return lastKnown;
      } catch (_) {
        // Continue with the high-accuracy provider.
      }
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      ).timeout(const Duration(seconds: 9));
    } catch (_) {
      // Wait for one stream update below.
    }

    try {
      return await Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).first.timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  String _locationFailureMessage(Object error) {
    if (error is LocationServiceDisabledException) {
      return 'Nyalakan layanan Lokasi/GPS perangkat untuk navigasi.';
    }
    if (error is PermissionDeniedException) {
      return 'Izin lokasi SafeZone belum diberikan. Aktifkan dari Pengaturan aplikasi.';
    }
    final detail = error.toString().split('\n').first;
    return 'Error lokasi (${error.runtimeType}): $detail';
  }

  NavigationController? _buildNavController(_SafeRoute route) {
    if (route.steps.isEmpty) return null;
    return NavigationController(NavRoute(
      route.points,
      route.steps,
      route.distanceMeters,
      route.durationSeconds,
    ));
  }

  /// Saat peta pertama kali siap: pindahkan kamera ke lokasi kita dan pakai
  /// sebagai titik asal default ("Lokasi saya"). Kalau izin/GPS tidak ada,
  /// peta tetap di area default tanpa pesan error.
  Future<void> _locateOnStart() async {
    unawaited(_startLocationStream());
    await _goToMyLocation(silent: true);
    final here = _currentPosition;
    if (!mounted || here == null) return;
    if (_fromCtrl.text.isEmpty && _fromPoint == null) {
      setState(() {
        _fromCtrl.text = 'Lokasi saya';
        _fromPoint = here;
      });
    }
  }

  Future<void> _startLocationStream() async {
    try {
      if (!await _ensureLocationPermission(silent: true)) return;
      await _listenForPositionUpdates(accuracy: LocationAccuracy.medium);
    } catch (error) {
      debugPrint('Could not start location stream: $error');
    }
  }

  Future<void> _listenForPositionUpdates({
    required LocationAccuracy accuracy,
    bool forceAndroidLocationManager = false,
  }) async {
    await _positionSub?.cancel();
    final settings = forceAndroidLocationManager
        ? AndroidSettings(
            accuracy: accuracy,
            distanceFilter: 3,
            forceLocationManager: true,
            intervalDuration: const Duration(seconds: 3),
          )
        : LocationSettings(accuracy: accuracy, distanceFilter: 3);
    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        final wasUnknown = _currentPosition == null;
        _updateCurrentPosition(position);
        if (wasUnknown && mounted && !_navigating) {
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            16,
          );
        }
      },
      onError: (Object error) {
        if (defaultTargetPlatform == TargetPlatform.android &&
            !forceAndroidLocationManager) {
          unawaited(_listenForPositionUpdates(
            accuracy: accuracy,
            forceAndroidLocationManager: true,
          ));
        } else {
          debugPrint('Location stream error: $error');
        }
      },
    );
  }

  /// Ambil posisi GPS sekarang lalu arahkan kamera ke sana. Dipakai saat peta
  /// dibuka dan oleh tombol lokasi (target merah) di kanan bawah.
  Future<void> _goToMyLocation({bool silent = false}) async {
    if (_locating) return;
    _locating = true;
    try {
      final allowed = await _ensureLocationPermission(silent: silent);
      if (!allowed) return;

      final pos = await _readDevicePosition();
      if (pos == null) {
        if (!silent && mounted) {
          _showRouteError(
            'Lokasi belum didapat. Pastikan izin lokasi aplikasi aktif, lalu coba lagi di area terbuka.',
          );
        }
        return;
      }

      final point = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _currentPosition = point;
        _followUser = true;
      });
      _mapController.move(point, 17);

      if (_navigating &&
          _route != null &&
          _minDistanceToPolyline(point, _route!.points) > 100) {
        _rerouteFrom(point);
      }
    } catch (error) {
      if (!silent && mounted) _showInfo(_locationFailureMessage(error));
    } finally {
      _locating = false;
    }
  }

  Future<bool> _ensureLocationPermission({bool silent = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) {
          _showInfo(
            permission == LocationPermission.deniedForever
                ? 'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.'
                : 'Izin lokasi diperlukan untuk navigasi langsung.',
          );
          if (permission == LocationPermission.deniedForever) {
            await Geolocator.openAppSettings();
          }
        }
        return false;
      }
      return true;
    } catch (error) {
      if (!silent) _showInfo(_locationFailureMessage(error));
      return false;
    }
  }

  void _updateCurrentPosition(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    if (_navigating && _nav == null && _route != null) {
      _nav = _buildNavController(_route!);
    }
    setState(() {
      _currentPosition = point;
      // Position.speed dalam m/s -> km/j (bisa -1 kalau tidak tersedia)
      _speedKmh = math.max(0, position.speed * 3.6);
    });
    _nav?.updatePosition(point);
    if (_navigating) _checkOffRoute(point, position.accuracy);
    if (_navigating && _followUser) {
      _mapController.move(point, 17);
    }
  }

  /// Deteksi keluar jalur: kalau jarak ke garis rute melebihi ambang selama
  /// beberapa pembacaan GPS berturut-turut, hitung rute baru dari posisi kita.
  void _checkOffRoute(LatLng point, double accuracy) {
    final route = _route;
    if (route == null || _rerouting) return;
    if (_nav?.arrived == true) return;
    if (accuracy > 60) return; // GPS sedang tidak akurat, abaikan

    final offMeters = _minDistanceToPolyline(point, route.points);
    final threshold = math.max(45.0, accuracy * 1.5);
    if (offMeters > threshold) {
      _offRouteCount++;
    } else {
      _offRouteCount = 0;
    }

    if (_offRouteCount >= 3) {
      final last = _lastReroute;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(seconds: 10)) {
        return; // jangan spam permintaan rute
      }
      _rerouteFrom(point);
    }
  }

  /// Hitung rute baru dari posisi sekarang ke tujuan yang sama. Tetap lewat
  /// _buildSafeRoute, jadi rute baru juga menghindari titik Begal.
  Future<void> _rerouteFrom(LatLng from) async {
    final end = _route?.end;
    if (end == null || _rerouting) return;
    _rerouting = true;
    _offRouteCount = 0;
    _showInfo('Keluar jalur. Mencari rute baru dari posisi kamu...');
    try {
      final fresh = await _buildSafeRoute(from, end);
      if (!mounted || !_navigating) return;
      final oldNav = _nav;
      setState(() {
        _route = fresh;
        _nav = _buildNavController(fresh);
      });
      oldNav?.dispose();
      _nav?.updatePosition(_currentPosition ?? from);
      _showInfo('Rute diperbarui.');
    } catch (_) {
      _showInfo('Gagal memperbarui rute, mencoba lagi...');
    } finally {
      _lastReroute = DateTime.now();
      _rerouting = false;
    }
  }

  Future<void> _stopNavigation() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _nav?.dispose();
    _nav = null;
    _rerouting = false;
    _offRouteCount = 0;
    if (mounted) {
      setState(() {
        _navigating = false;
        _followUser = false;
        _speedKmh = 0;
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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF1A73E8),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, _navigating ? 130 : 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<LatLng> _geocode(String query) async {
    final places = await _searchPlaces(query, limit: 1);
    if (places.isEmpty) throw Exception('Lokasi "$query" tidak ditemukan.');
    return _resolvePlace(places.first);
  }

  /// Pencarian lokasi: Mapbox Search Box dulu (data POI lebih baru), lalu
  /// cadangan Photon/Nominatim kalau Mapbox gagal, kuota habis, atau kosong.
  Future<List<_PlaceSuggestion>> _searchPlaces(String query,
      {int limit = 5}) async {
    if (MapTileConfig.usesMapbox) {
      try {
        final results = await _searchPlacesMapbox(query, limit: limit);
        if (results.isNotEmpty) return results;
      } catch (_) {
        // lanjut ke cadangan
      }
    }
    return _searchPlacesPhoton(query, limit: limit);
  }

  /// Mapbox Search Box API: /suggest (tanpa koordinat) lalu /retrieve saat
  /// hasil dipilih.
  Future<List<_PlaceSuggestion>> _searchPlacesMapbox(String query,
      {int limit = 5}) async {
    final near = _currentPosition ?? _defaultCenter;
    final uri = Uri.https('api.mapbox.com', '/search/searchbox/v1/suggest', {
      'q': query,
      'access_token': MapTileConfig.mapboxToken,
      'session_token': _sessionToken,
      'language': 'id',
      'country': 'id',
      'limit': '$limit',
      'proximity': '${near.longitude},${near.latitude}',
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
          return _PlaceSuggestion(
            title: (s['name'] as String?) ?? query,
            subtitle: subtitle,
            mapboxId: s['mapbox_id'] as String?,
          );
        })
        .where((p) => p.mapboxId != null)
        .toList();
  }

  /// Ambil koordinat sebuah hasil pencarian. Hasil Photon/Nominatim/lokasi
  /// tersimpan sudah punya koordinat; hasil Mapbox perlu /retrieve.
  Future<LatLng> _resolvePlace(_PlaceSuggestion place) async {
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

    _sessionToken = _newSessionToken(); // sesi selesai setelah retrieve
    return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
  }

  /// Cadangan: Photon (by Komoot), lalu Nominatim kalau Photon gagal/kosong.
  Future<List<_PlaceSuggestion>> _searchPlacesPhoton(String query,
      {int limit = 5}) async {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '$limit',
      'lang': 'id',
      'lat': '${_defaultCenter.latitude}',
      'lon': '${_defaultCenter.longitude}',
    });

    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      return _searchPlacesNominatim(query, limit: limit);
    }

    if (res.statusCode != 200) {
      return _searchPlacesNominatim(query, limit: limit);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) {
      return _searchPlacesNominatim(query, limit: limit);
    }

    return features.map((raw) {
      final feature = raw as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>; // [lon, lat]

      final name = (props['name'] as String?) ?? query;
      final addressParts = [
        props['street'],
        props['district'],
        props['city'],
        props['state'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();

      return _PlaceSuggestion(
        title: name,
        subtitle: addressParts.join(', '),
        point: LatLng(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
      );
    }).toList();
  }

  /// Sumber cadangan terakhir kalau Photon tidak tersedia atau tidak punya hasil.
  Future<List<_PlaceSuggestion>> _searchPlacesNominatim(String query,
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
        // Layanan rute bisa menolak waypoint; coba sisi lainnya.
      }
    }

    if (alternatives.isEmpty) {
      return direct.copyWith(
        start: start,
        end: end,
        danger: danger,
        status: 'Rute rawan',
        note: 'Belum dapat membuat rute alternatif dari layanan rute.',
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

  /// Ambil rute dari Mapbox Directions API. Kalau Mapbox tidak tersedia
  /// (token kosong, kuota habis, tidak ada rute), pakai OSRM sebagai cadangan.
  /// Format respons keduanya sama, jadi parsernya satu.
  Future<_SafeRoute> _fetchRoute(List<LatLng> points) async {
    final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');

    if (MapTileConfig.usesMapbox) {
      try {
        final uri = Uri.parse(
            'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
            '?geometries=geojson&overview=full&steps=true&alternatives=false'
            '&access_token=${MapTileConfig.mapboxToken}');
        final res = await http.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if ((body['routes'] as List<dynamic>? ?? []).isNotEmpty) {
            return _parseRoute(body);
          }
        }
      } catch (_) {
        // lanjut ke OSRM
      }
    }

    final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&alternatives=false&steps=true');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Gagal mengambil rute.');
    return _parseRoute(jsonDecode(res.body) as Map<String, dynamic>);
  }

  _SafeRoute _parseRoute(Map<String, dynamic> body) {
    final routes = body['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) throw Exception('Rute tidak ditemukan.');

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    // Ambil langkah belokan dari semua leg. Untuk rute dengan waypoint
    // (rute alternatif), buang "arrive"/"depart" di titik sambungan leg, dan
    // langkah yang cuma informasi (bukan belokan).
    const skipTypes = {
      'exit roundabout',
      'exit rotary',
      'notification',
      'use lane'
    };
    final steps = <NavStep>[];
    final legs = route['legs'] as List<dynamic>? ?? [];
    for (var li = 0; li < legs.length; li++) {
      final legSteps =
          (legs[li] as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
      for (final raw in legSteps) {
        final s = raw as Map<String, dynamic>;
        final type = (s['maneuver'] as Map<String, dynamic>)['type'];
        if (skipTypes.contains(type)) continue;
        if (li > 0 && type == 'depart') continue;
        if (li < legs.length - 1 && type == 'arrive') continue;
        steps.add(NavStep.fromJson(s));
      }
    }

    return _SafeRoute(
      points: coordinates.map((coord) {
        final pair = coord as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList(),
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      steps: steps,
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
    const latScale = 111320.0;
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
    const latScale = 111320.0;
    final lngScale = latScale * math.cos(danger.latitude * math.pi / 180);
    var vx = (end.longitude - start.longitude) * lngScale;
    var vy = (end.latitude - start.latitude) * latScale;
    final len = math.sqrt(vx * vx + vy * vy);
    if (len == 0) return danger;
    vx /= len;
    vy /= len;
    const offsetMeters = 750.0;
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
            setState(() {
              _selectedLaporan = l;
              _selectedMapPlace = null;
            });
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
          // Sebelumnya marker ini tidak punya onTap, jadi tap-nya tembus ke
          // peta di belakangnya dan malah membuka detail titik/jalan, bukan
          // detail laporan Begal-nya. Sekarang di-tap langsung buka laporan
          // yang terkait, sama seperti marker Begal biasa di seluruh peta.
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMapPlace = null;
                _selectedLaporan = route.danger!.laporan;
              });
              _mapController.move(route.danger!.point, 16);
            },
            child: const _RoutePin(
              icon: Icons.motorcycle_rounded,
              color: Color(0xFF991B1B),
            ),
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
    final reportCount = _laporan.where((l) => l.geoPoint != null).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Peta ──
          Stack(
            fit: StackFit.expand,
            children: [
              const OpenStreetMapFallback(),
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialTarget ?? _defaultCenter,
                  initialZoom: widget.initialTarget == null ? 13 : 16,
                  onMapReady: widget.initialTarget == null
                      ? _locateOnStart
                      : () => _mapController.move(widget.initialTarget!, 16),
                  onTap: (_, point) => _selectMapPlace(point),
                  onLongPress: (_, point) => _promptSaveLocation(point),
                ),
                children: [
                  const OpenStreetMapTileLayer(),
                  if (_route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route!.points,
                          strokeWidth: 13,
                          color: Colors.white,
                        ),
                        Polyline(
                          points: _route!.points,
                          strokeWidth: 9,
                          color: _route!.isSafer
                              ? const Color(0xFF1A73E8)
                              : AppColors.red,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: _buildMarkers()),
                  if (widget.initialTarget != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: widget.initialTarget!,
                        width: 54,
                        height: 68,
                        child: _FriendLocationPin(
                            label: widget.initialTargetLabel ?? 'Safe Friend'),
                      ),
                    ]),
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
              Positioned(
                left: 10,
                bottom: 10,
                child: IgnorePointer(
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
                          Image.asset('assets/logo.png', width: 22, height: 22),
                          const SizedBox(width: 6),
                          Text('SafeZone',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.red)),
                        ]),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const SavedLocationsScreen(),
                            )),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xECFFF8F1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: const Icon(Icons.bookmark_rounded,
                                  color: AppColors.red, size: 20),
                            ),
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
                    ],
                  ),
                ),
              ),
            ),

          // ── Route search + badge laporan aktif ──
          // Digabung dalam satu Column (bukan dua Positioned terpisah) supaya
          // badge selalu mengikuti tinggi card dan tidak pernah tertutup /
          // menutupi saat card membesar (ada saran, hasil rute, dsb).
          if (!_navigating)
            Positioned(
              top: 78,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RouteSearchCard(
                      fromCtrl: _fromCtrl,
                      toCtrl: _toCtrl,
                      loading: _routing,
                      error: _routeError,
                      route: _route,
                      activeField: _activeField,
                      suggestions: _suggestions,
                      loadingSuggestions: _loadingSuggestions,
                      savedLocations: _savedLocations,
                      onSearch: _searchRoute,
                      onStartNavigation: _startNavigation,
                      showPreview: true,
                      onPreview: _openRoutePreview,
                      onFieldChanged: _onFieldChanged,
                      onFieldFocus: (field) =>
                          setState(() => _activeField = field),
                      onSuggestionSelected: _selectSuggestion,
                      onSavedLocationSelected: _selectSavedLocation,
                      onClear: () {
                        setState(() {
                          _route = null;
                          _routeError = null;
                          _suggestions = [];
                        });
                        _mapController.move(_defaultCenter, 13);
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                            '$reportCount Laporan Aktif',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Banner belokan ala Google Maps ──
          if (_navigating && _route != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _nav != null
                  ? NavigationBanner(controller: _nav!)
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _NavigationHeader(
                          route: _route!,
                          distanceText: _navigationDistanceText,
                        ),
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

          // ── Kecepatan (kiri bawah, ala Google Maps) ──
          if (_navigating)
            Positioned(
              left: 16,
              bottom: 150,
              child: _SpeedBadge(kmh: _speedKmh),
            ),

          // ── Reset view button ──
          Positioned(
            bottom: _navigating
                ? 150
                : _selectedLaporan != null
                    ? 220
                    : _selectedMapPlace != null
                        ? 395
                        : 30,
            right: 16,
            child: GestureDetector(
              onTap: () => _goToMyLocation(),
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

          if (!_navigating && _selectedMapPlace != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: _MapPlaceCard(
                info: _selectedMapPlace!,
                loading: _loadingMapPlace,
                onClose: () => setState(() => _selectedMapPlace = null),
                onFrom: () =>
                    _useMapPlaceAs(_RouteFieldType.from, _selectedMapPlace!),
                onTo: () =>
                    _useMapPlaceAs(_RouteFieldType.to, _selectedMapPlace!),
                onSave: () => _promptSaveLocation(_selectedMapPlace!.point),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPlaceInfo {
  final LatLng point;
  final String title;
  final String? subtitle;
  final String coordinate;
  final String source;
  final String? category;

  const _MapPlaceInfo({
    required this.point,
    required this.title,
    required this.subtitle,
    required this.coordinate,
    required this.source,
    this.category,
  });
}

class _SaveLocationResult {
  final String label;
  const _SaveLocationResult(this.label);
}

class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.red : AppColors.cream,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: selected ? Colors.white : AppColors.text2),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.text2,
                )),
          ],
        ),
      ),
    );
  }
}

class _MapPlaceCard extends StatelessWidget {
  final _MapPlaceInfo info;
  final bool loading;
  final VoidCallback onClose;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onSave;

  const _MapPlaceCard({
    required this.info,
    required this.loading,
    required this.onClose,
    required this.onFrom,
    required this.onTo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = info.subtitle?.trim();
    final category = info.category?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category == 'poi'
                      ? Icons.place_rounded
                      : Icons.add_road_rounded,
                  color: AppColors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.text2,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PlacePhoto(key: ValueKey(info.point), point: info.point),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.my_location_rounded,
                  color: Color(0xFF008C99), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.coordinate,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF008C99),
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  info.source,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlaceActionButton(
                  icon: Icons.trip_origin_rounded,
                  label: 'Asal',
                  onTap: onFrom,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlaceActionButton(
                  icon: Icons.flag_rounded,
                  label: 'Tujuan',
                  filled: true,
                  onTap: onTo,
                ),
              ),
              const SizedBox(width: 8),
              _PlaceIconButton(
                icon: Icons.bookmark_add_rounded,
                onTap: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _PlaceActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.red : const Color(0xFFFFF4EE),
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: const Color(0xFFE9D9CB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: filled ? Colors.white : AppColors.red,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: filled ? Colors.white : AppColors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PlaceIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF5EFE8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9D9CB)),
        ),
        child: Icon(icon, color: AppColors.text2, size: 19),
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
              decoration: const BoxDecoration(
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
          if (laporan.imageUrl != null || laporan.videoUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: laporan.videoUrl != null
                  ? ReportVideoPlayer(url: laporan.videoUrl)
                  : Image.network(laporan.imageUrl!,
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
  final List<SavedLocationModel> savedLocations;
  final VoidCallback onSearch;
  final VoidCallback onStartNavigation;
  final bool showPreview;
  final VoidCallback onPreview;
  final void Function(_RouteFieldType field, String value) onFieldChanged;
  final ValueChanged<_RouteFieldType> onFieldFocus;
  final ValueChanged<_PlaceSuggestion> onSuggestionSelected;
  final ValueChanged<SavedLocationModel> onSavedLocationSelected;
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
    required this.savedLocations,
    required this.onSearch,
    required this.onStartNavigation,
    required this.showPreview,
    required this.onPreview,
    required this.onFieldChanged,
    required this.onFieldFocus,
    required this.onSuggestionSelected,
    required this.onSavedLocationSelected,
    required this.onClear,
  });

  bool get _activeCtrlEmpty {
    final ctrl = activeField == _RouteFieldType.from ? fromCtrl : toCtrl;
    return ctrl.text.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan pintasan lokasi tersimpan hanya kalau kolom aktif masih
    // kosong dan belum ada hasil pencarian yang sedang tampil.
    final showSavedShortcuts = savedLocations.isNotEmpty &&
        _activeCtrlEmpty &&
        suggestions.isEmpty &&
        !loadingSuggestions;

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
          if (showSavedShortcuts) ...[
            const SizedBox(height: 10),
            _SavedLocationChips(
              locations: savedLocations,
              onSelected: onSavedLocationSelected,
            ),
          ],
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
              Row(
                children: [
                  // Tombol "Preview" hanya muncul kalau titik "Dari" yang
                  // dipakai beda jauh dari posisi GPS asli kita, mirip
                  // "Route preview" di Google Maps saat kita cek rute dari
                  // tempat lain (bukan dari lokasi sekarang).
                  if (showPreview) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPreview,
                        icon: const Icon(Icons.visibility_rounded,
                            color: Color(0xFF07869A), size: 18),
                        label: Text('Preview',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF07869A))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF07869A), width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: showPreview ? 1 : 2,
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
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Baris chip pintasan lokasi tersimpan (Rumah, Kantor, dst) yang muncul
/// begitu user fokus ke kolom asal/tujuan sebelum mengetik apa pun.
class _SavedLocationChips extends StatelessWidget {
  final List<SavedLocationModel> locations;
  final ValueChanged<SavedLocationModel> onSelected;

  const _SavedLocationChips(
      {required this.locations, required this.onSelected});

  IconData _iconFor(SavedLocationModel loc) {
    switch (loc.iconKey) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final loc = locations[i];
          return GestureDetector(
            onTap: () => onSelected(loc),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(loc), size: 16, color: AppColors.red),
                  const SizedBox(width: 6),
                  Text(loc.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      )),
                ],
              ),
            ),
          );
        },
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

class _FriendLocationPin extends StatelessWidget {
  final String label;

  const _FriendLocationPin({required this.label});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 128),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.location_on_rounded, color: AppColors.red, size: 37),
        ],
      );
}

/// Header cadangan kalau rute tidak punya data langkah belokan.
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
                  'Mode dasar: data belokan tidak tersedia',
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

class _SpeedBadge extends StatelessWidget {
  final double kmh;

  const _SpeedBadge({required this.kmh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD0D5DD), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            kmh.round().toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'km/j',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.text2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Layar "Route preview" ala Google Maps ──
/// Dibuka lewat tombol "Preview" saat titik "Dari" tidak sama dengan posisi
/// GPS kita sekarang. Menampilkan instruksi belokan satu per satu, dengan
/// peta yang mengikuti langkah yang sedang dilihat, tanpa memulai navigasi
/// live (tidak melacak GPS/kecepatan).
class _RoutePreviewScreen extends StatefulWidget {
  final _SafeRoute route;
  const _RoutePreviewScreen({required this.route});

  @override
  State<_RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<_RoutePreviewScreen> {
  final MapController _mapController = MapController();
  int _stepIndex = 0;

  List<NavStep> get _steps => widget.route.steps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep(0));
  }

  void _focusStep(int i) {
    if (_steps.isEmpty) return;
    _mapController.move(_steps[i].location, 17);
  }

  void _goTo(int i) {
    if (i < 0 || i >= _steps.length) return;
    setState(() => _stepIndex = i);
    _focusStep(i);
  }

  String _instructionFor(int i) {
    final s = _steps[i];
    if (s.type == 'depart') return 'Mulai perjalanan';
    return stepInstruction(s);
  }

  @override
  Widget build(BuildContext context) {
    final hasSteps = _steps.isNotEmpty;
    final step = hasSteps ? _steps[_stepIndex] : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.text),
                ),
                Expanded(
                  child: Text('Route preview',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                ),
              ],
            ),
          ),
          if (hasSteps)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(maneuverIcon(step!.type, step.modifier),
                      color: AppColors.text, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_instructionFor(_stepIndex),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: hasSteps
                        ? _steps.first.location
                        : widget.route.points.first,
                    initialZoom: 16,
                  ),
                  children: [
                    const OpenStreetMapTileLayer(),
                    PolylineLayer(polylines: [
                      Polyline(
                        points: widget.route.points,
                        strokeWidth: 8,
                        color: const Color(0xFF1A73E8),
                      ),
                    ]),
                    if (widget.route.start != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: widget.route.start!,
                          width: 30,
                          height: 30,
                          child: const _RoutePin(
                            icon: Icons.trip_origin_rounded,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ]),
                    if (widget.route.end != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: widget.route.end!,
                          width: 34,
                          height: 34,
                          child: const _RoutePin(
                            icon: Icons.flag_rounded,
                            color: AppColors.red,
                          ),
                        ),
                      ]),
                    if (hasSteps)
                      MarkerLayer(markers: [
                        Marker(
                          point: step!.location,
                          width: 34,
                          height: 34,
                          child: const _RoutePin(
                            icon: Icons.arrow_upward_rounded,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                      ]),
                  ],
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: IgnorePointer(
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
              ],
            ),
          ),
          if (hasSteps)
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PreviewNavButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _stepIndex > 0,
                      onTap: () => _goTo(_stepIndex - 1),
                    ),
                    Text('${_stepIndex + 1} / ${_steps.length}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text2)),
                    _PreviewNavButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _stepIndex < _steps.length - 1,
                      onTap: () => _goTo(_stepIndex + 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PreviewNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppColors.cream,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Icon(icon,
            color: enabled ? AppColors.red : AppColors.text3, size: 26),
      ),
    );
  }
}

class _SafeRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<NavStep> steps;
  final LatLng? start;
  final LatLng? end;
  final _DangerPoint? danger;
  final String status;
  final String note;

  const _SafeRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
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
      steps: steps,
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

/// Hasil pencarian lokasi. Hasil Photon/Nominatim/lokasi tersimpan sudah punya
/// [point]; hasil Mapbox Search Box hanya punya [mapboxId] dan koordinatnya
/// diambil lewat /retrieve saat dipilih.
class _PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng? point;
  final String? mapboxId;

  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
    this.point,
    this.mapboxId,
  });
}

/// UUID v4 acak untuk session_token Mapbox Search Box.
String _newSessionToken() {
  final r = math.Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  const variants = '89ab';
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${variants[r.nextInt(4)]}${hex(3)}-${hex(12)}';
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
