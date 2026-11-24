import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

import '../app_colors.dart';
import 'location_picker_screen.dart';

/// Intro step before choosing a saved place: use the device's current
/// location, or choose a point manually on the map.
class SavedLocationSetupScreen extends StatefulWidget {
  final String title;
  final LatLng initialCenter;

  const SavedLocationSetupScreen({
    super.key,
    required this.title,
    required this.initialCenter,
  });

  @override
  State<SavedLocationSetupScreen> createState() =>
      _SavedLocationSetupScreenState();
}

class _SavedLocationSetupScreenState extends State<SavedLocationSetupScreen> {
  bool _loadingLocation = false;
  String? _locationError;

  String get _placeName => widget.title == 'lokasi baru'
      ? 'lokasi favorit'
      : widget.title.toLowerCase();

  Future<void> _useCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const _LocationSetupException(
            'Aktifkan GPS untuk memakai lokasi saat ini.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationSetupException(
            'Izin lokasi belum diberikan. Kamu bisa memilih titik di peta.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationSetupException(
            'Izin lokasi diblokir. Aktifkan dari pengaturan atau pilih titik di peta.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final point = LatLng(position.latitude, position.longitude);
      final address = await _reverseGeocode(point);
      if (!mounted) return;
      Navigator.of(context).pop(PickedLocation(point, address));
    } on _LocationSetupException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _locationError =
            'Lokasi belum berhasil ditemukan. Coba lagi atau pilih titik di peta.');
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'jsonv2',
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'SafeZone/1.0 (safezone-app)',
      }).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['display_name'] as String?;
        if (address != null && address.trim().isNotEmpty) return address;
      }
    } catch (_) {
      // Keep coordinates as a usable address if reverse geocoding is offline.
    }
    return 'Titik peta ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _chooseManually() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: _placeName,
          initialCenter: widget.initialCenter,
        ),
      ),
    );
    if (picked != null && mounted) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFAF7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
        ),
        title: Text('Atur lokasi',
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 4, 26, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    const _LocationIllustration(),
                    const SizedBox(height: 28),
                    Text('Tentukan ${_placeName}mu',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.3)),
                    const SizedBox(height: 9),
                    Text(
                      'Simpan titik yang sering kamu gunakan agar lebih mudah dipilih saat melihat peta dan menyusun perjalanan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.text2, fontSize: 13, height: 1.65),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.cream2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              color: AppColors.text3, size: 15),
                          const SizedBox(width: 7),
                          Text('Hanya tersimpan di akunmu',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.text2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    if (_locationError != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.redLighter,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(_locationError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                color: AppColors.red,
                                fontSize: 11,
                                height: 1.45,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _loadingLocation ? null : _useCurrentLocation,
                      icon: _loadingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location_rounded, size: 19),
                      label: Text(
                          _loadingLocation
                              ? 'Mencari lokasi…'
                              : 'Gunakan lokasi saya',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loadingLocation ? null : _chooseManually,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text('Pilih titik di peta',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text2,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.cream2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationIllustration extends StatelessWidget {
  const _LocationIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 250,
        height: 228,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 208,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EDE2),
                borderRadius: BorderRadius.circular(33),
              ),
            ),
            Transform.rotate(
              angle: -.12,
              child: Container(
                width: 174,
                height: 134,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: AppColors.text, width: 2.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1A1A1108),
                        blurRadius: 0,
                        offset: Offset(0, 7)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: CustomPaint(painter: _MapLinesPainter()),
                ),
              ),
            ),
            const Positioned(
              top: 28,
              right: 34,
              child: Icon(Icons.location_on_rounded,
                  color: AppColors.red, size: 76),
            ),
            Positioned(
              bottom: 43,
              left: 44,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ],
        ),
      );
}

class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFEADFCF)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final road = Path()
      ..moveTo(size.width * .08, size.height * .27)
      ..cubicTo(size.width * .3, size.height * .15, size.width * .35,
          size.height * .39, size.width * .58, size.height * .3)
      ..cubicTo(size.width * .75, size.height * .23, size.width * .78,
          size.height * .4, size.width * 1.06, size.height * .27);
    canvas.drawPath(road, line);
    final cross = Path()
      ..moveTo(size.width * .46, -4)
      ..lineTo(size.width * .45, size.height * .42)
      ..lineTo(size.width * .57, size.height * .65)
      ..lineTo(size.width * .5, size.height + 5);
    canvas.drawPath(cross, line..strokeWidth = 5);
    final route = Paint()
      ..color = AppColors.red
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final routePath = Path()
      ..moveTo(size.width * .2, size.height * .72)
      ..cubicTo(size.width * .33, size.height * .66, size.width * .34,
          size.height * .44, size.width * .55, size.height * .48)
      ..cubicTo(size.width * .69, size.height * .51, size.width * .7,
          size.height * .68, size.width * .82, size.height * .55);
    canvas.drawPath(routePath, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LocationSetupException implements Exception {
  final String message;
  const _LocationSetupException(this.message);
}
