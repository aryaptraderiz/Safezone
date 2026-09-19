import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';
import '../services/laporan_service.dart';
import '../models/laporan_model.dart';
import '../widgets/open_street_map_tile_layer.dart';

class LaporScreen extends StatefulWidget {
  final VoidCallback onKirim;
  final VoidCallback onBack;

  const LaporScreen({super.key, required this.onKirim, required this.onBack});

  @override
  State<LaporScreen> createState() => _LaporScreenState();
}

class _LaporScreenState extends State<LaporScreen> {
  int? _selectedKat;
  final _descCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  File? _selectedImage;
  LatLng? _selectedLocation;
  bool _loading = false;
  final _mapController = MapController();

  final _kats = [
    _KatData(Icons.motorcycle_rounded, 'Begal'),
    _KatData(Icons.people_alt_rounded, 'Tawuran'),
    _KatData(Icons.directions_car_rounded, 'Kecelakaan'),
    _KatData(Icons.more_horiz_rounded, 'Lainnya'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _lokasiCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  Future<void> _handleKirim() async {
    if (_selectedKat == null) {
      _toast('Pilih kategori laporan dulu ya!');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _toast('Ceritain dulu apa yang terjadi!');
      return;
    }
    if (_selectedLocation == null) {
      _toast('Pilih lokasi di peta terlebih dahulu!');
      return;
    }

    final user = AuthService.currentUser;
    if (user == null) {
      _toast('Kamu harus login dulu!');
      return;
    }

    setState(() => _loading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await LaporanService.uploadFoto(_selectedImage!);
      }

      final laporan = LaporanModel(
        uid: user.uid,
        namaUser: user.displayName ?? user.email ?? 'Anonim',
        kategori: _kats[_selectedKat!].label,
        lokasi: _lokasiCtrl.text.trim().isEmpty
            ? 'Lokasi dari Peta'
            : _lokasiCtrl.text.trim(),
        deskripsi: _descCtrl.text.trim(),
        hasPhoto: _selectedImage != null,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        geoPoint:
            GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
      );

      await LaporanService.kirim(laporan);

      // Reset form
      setState(() {
        _selectedKat = null;
        _selectedImage = null;
        _selectedLocation = null;
      });
      _descCtrl.clear();
      _lokasiCtrl.clear();

      widget.onKirim(); // tampilkan toast sukses
    } catch (e) {
      _toast('Gagal mengirim laporan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(
            top: 50,
            right: -30,
            child: _Blob(width: 200, height: 200, color: AppColors.redLight),
          ),
          Positioned(
            top: 220,
            left: -40,
            child:
                _Blob(width: 140, height: 140, color: const Color(0xFFFEF9C3)),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.cream, width: 1)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: widget.onBack,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                                color: AppColors.cream, shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: AppColors.text2, size: 20),
                          ),
                        ),
                      ),
                      Text('Lapor',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.red)),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      Text('Ada Kejadian?',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              height: 1.2)),
                      const SizedBox(height: 3),
                      Text('Yuk Lapor! Biar kawasan kita makin aman.',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: AppColors.text2)),
                      const SizedBox(height: 18),

                      // ── Kategori ──
                      _WCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CLabel('Kategori Laporan'),
                            const SizedBox(height: 11),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                              childAspectRatio: 1.3,
                              children: List.generate(
                                _kats.length,
                                (i) => GestureDetector(
                                  onTap: () => setState(() => _selectedKat = i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _selectedKat == i
                                          ? AppColors.redLighter
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _selectedKat == i
                                            ? AppColors.red
                                            : AppColors.cream,
                                        width: _selectedKat == i ? 2 : 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _selectedKat == i
                                                ? AppColors.redLight
                                                : AppColors.cream,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(_kats[i].icon,
                                              size: 24,
                                              color: _selectedKat == i
                                                  ? AppColors.red
                                                  : AppColors.text2),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(_kats[i].label,
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.text)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Lokasi ──
                      _WCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CLabel('Lokasi Kejadian (Tap di peta)'),
                            const SizedBox(height: 11),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.cream3, width: 1.5),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const OpenStreetMapFallback(dense: true),
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter:
                                          const LatLng(-6.200000, 106.816666),
                                      initialZoom: 13,
                                      onTap: (tapPos, latLng) {
                                        setState(
                                            () => _selectedLocation = latLng);
                                      },
                                    ),
                                    children: [
                                      const OpenStreetMapTileLayer(),
                                      if (_selectedLocation != null)
                                        MarkerLayer(markers: [
                                          Marker(
                                            point: _selectedLocation!,
                                            width: 36,
                                            height: 36,
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              color: AppColors.red,
                                              size: 36,
                                            ),
                                          )
                                        ]),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedLocation != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '📍 ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11, color: AppColors.text3),
                                ),
                              ),
                            const SizedBox(height: 11),
                            Container(
                              padding: const EdgeInsets.only(left: 4, right: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.cream3, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 10),
                                  const Icon(Icons.location_city_rounded,
                                      color: AppColors.text2, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _lokasiCtrl,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14, color: AppColors.text),
                                      decoration: InputDecoration(
                                        hintText: 'Detail nama jalan/tempat',
                                        hintStyle: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            color: AppColors.text3),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Deskripsi ──
                      _WCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CLabel('Ceritain Dikit Dong'),
                            const SizedBox(height: 11),
                            TextField(
                              controller: _descCtrl,
                              maxLines: 4,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppColors.text,
                                  height: 1.5),
                              decoration: InputDecoration(
                                hintText:
                                    'Apa yang terjadi? Ciri-ciri pelaku? Waktu kejadian?',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppColors.text3,
                                    height: 1.5),
                                filled: true,
                                fillColor: AppColors.cream,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Upload Foto ──
                      _WCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CLabel('Upload Bukti Foto/Video'),
                            const SizedBox(height: 11),
                            GestureDetector(
                              onTap: _pickImage,
                              child: CustomPaint(
                                painter: _DashedBorderPainter(
                                  color: _selectedImage != null
                                      ? AppColors.red
                                      : AppColors.cream3,
                                  borderRadius: 16,
                                  dashWidth: 7,
                                  dashSpace: 5,
                                  strokeWidth: 2,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  height: _selectedImage != null ? 200 : null,
                                  padding: _selectedImage != null
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.symmetric(
                                          vertical: 26),
                                  clipBehavior: Clip.hardEdge,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Column(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                  color: AppColors.redLight,
                                                  shape: BoxShape.circle),
                                              child: const Icon(
                                                  Icons.add_a_photo_outlined,
                                                  color: AppColors.red,
                                                  size: 24),
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                                'Tap untuk upload atau ambil foto.',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors.text),
                                                textAlign: TextAlign.center),
                                            const SizedBox(height: 4),
                                            Text(
                                                'Opsional, tapi ngebantu banget!',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        color: AppColors.text3),
                                                textAlign: TextAlign.center),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Tombol Kirim ──
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _handleKirim,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                          label: Text(
                              _loading ? 'Mengirim...' : 'Kirim Laporan',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            elevation: 8,
                            shadowColor: AppColors.red.withOpacity(0.22),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const StadiumBorder(),
                            disabledBackgroundColor:
                                AppColors.red.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper classes ──

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = dist + dashWidth;
        canvas.drawPath(
          metric.extractPath(dist, end.clamp(0, metric.length)),
          paint,
        );
        dist = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => color != old.color;
}

class _Blob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  const _Blob({required this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(120),
          topRight: Radius.circular(80),
          bottomLeft: Radius.circular(100),
          bottomRight: Radius.circular(140),
        ),
      ),
    );
  }
}

class _WCard extends StatelessWidget {
  final Widget child;
  const _WCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _CLabel extends StatelessWidget {
  final String text;
  const _CLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text));
  }
}

class _KatData {
  final IconData icon;
  final String label;
  _KatData(this.icon, this.label);
}
