import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../app_colors.dart';
import '../widgets/open_street_map_tile_layer.dart';

class PickedLocation {
  final LatLng point;
  final String address;
  const PickedLocation(this.point, this.address);
}

/// Layar pilih lokasi ala Google Maps: geser peta (pin selalu di tengah)
/// atau cari alamat lewat kolom pencarian, lalu konfirmasi dengan tombol
/// di bawah. Dipakai untuk set/ubah lokasi "Rumah", "Kantor", dst tanpa
/// user harus tau trik long-press di peta utama.
class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLng initialCenter;

  const LocationPickerScreen({
    super.key,
    required this.title,
    required this.initialCenter,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<_Suggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _resolving = false;
  late LatLng _center = widget.initialCenter;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loadingSuggestions = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '6',
        'addressdetails': '1',
        'countrycodes': 'id',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'SafeZone/1.0 (safezone-app)',
      });
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as List<dynamic>;
      final results = data.map((raw) {
        final item = raw as Map<String, dynamic>;
        final displayName = (item['display_name'] as String?) ?? query;
        final parts = displayName.split(',').map((e) => e.trim()).toList();
        return _Suggestion(
          title: parts.take(2).join(' '),
          subtitle: parts.skip(2).take(4).join(', '),
          point: LatLng(
            double.parse(item['lat'] as String),
            double.parse(item['lon'] as String),
          ),
        );
      }).toList();
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {
      // biarkan kosong, user masih bisa pilih lewat geser peta
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _selectSuggestion(_Suggestion s) {
    setState(() {
      _searchCtrl.text = s.title;
      _suggestions = [];
      _center = s.point;
    });
    _mapController.move(s.point, 17);
  }

  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'jsonv2',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'SafeZone/1.0 (safezone-app)',
      }).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final name = data['display_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name;
      }
    } catch (_) {
      // fallback ke koordinat di bawah
    }
    return 'Titik peta ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _confirm() async {
    setState(() => _resolving = true);
    final address = await _reverseGeocode(_center);
    if (!mounted) return;
    Navigator.of(context).pop(PickedLocation(_center, address));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 16,
              onPositionChanged: (pos, hasGesture) {
                final c = pos.center;
                if (c != null) _center = c;
              },
            ),
            children: const [OpenStreetMapTileLayer()],
          ),
          // Pin tetap di tengah layar; yang bergerak adalah petanya.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_on_rounded,
                    color: AppColors.red, size: 46),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              hintText: 'Cari alamat untuk ${widget.title}',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, color: AppColors.text3),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppColors.text2, size: 20),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_loadingSuggestions || _suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: .1),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: _loadingSuggestions && _suggestions.isEmpty
                          ? const SizedBox(
                              height: 54,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: AppColors.red, strokeWidth: 2),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.cream),
                              itemBuilder: (context, i) {
                                final s = _suggestions[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.text2),
                                  title: Text(s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800)),
                                  subtitle: s.subtitle.isEmpty
                                      ? null
                                      : Text(s.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppColors.text2)),
                                  onTap: () => _selectSuggestion(s),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resolving ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      disabledBackgroundColor:
                          AppColors.red.withValues(alpha: .5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _resolving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Set lokasi ${widget.title} di sini',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestion {
  final String title;
  final String subtitle;
  final LatLng point;

  const _Suggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });
}
