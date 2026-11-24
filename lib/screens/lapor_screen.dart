import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';
import '../services/laporan_service.dart';
import '../services/place_search_service.dart';
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
  final _searchCtrl = TextEditingController();
  static const int _maxMediaCount = 5;
  final List<_SelectedReportMedia> _selectedMedia = [];
  LatLng? _selectedLocation;
  LatLng? _myPosition;
  bool _loading = false;
  bool _locating = false;
  bool _searching = false;
  // true selama kolom "Detail nama jalan/tempat" masih berisi teks otomatis
  // (dari reverse geocoding/hasil pencarian). Kalau user mengetik sendiri,
  // teksnya tidak akan ditimpa lagi.
  bool _autoLokasi = true;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  final _mapController = MapController();

  final _kats = [
    _KatData(Icons.motorcycle_rounded, 'Begal'),
    _KatData(Icons.people_alt_rounded, 'Tawuran'),
    _KatData(Icons.directions_car_rounded, 'Kecelakaan'),
    _KatData(Icons.more_horiz_rounded, 'Lainnya'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _descCtrl.dispose();
    _lokasiCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
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

  // ── Pilih lokasi: tap peta / cari / GPS ──

  /// Tandai [point] sebagai lokasi kejadian. [label] (dari hasil pencarian)
  /// dipakai langsung sebagai nama tempat; kalau null, dicari lewat reverse
  /// geocoding.
  Future<void> _pickPoint(
    LatLng point, {
    String? label,
    bool moveMap = true,
  }) async {
    setState(() => _selectedLocation = point);
    if (moveMap) _mapController.move(point, 16);

    if (label != null) {
      _setLokasiText(label);
      return;
    }
    final address = await PlaceSearchService.reverse(point);
    // Abaikan kalau user sudah memilih titik lain selagi menunggu.
    if (!mounted || _selectedLocation != point) return;
    if (address != null) _setLokasiText(address);
  }

  void _setLokasiText(String text) {
    if (_lokasiCtrl.text.trim().isEmpty || _autoLokasi) {
      _lokasiCtrl.text = text;
      _autoLokasi = true;
    }
  }

  Future<void> _goToMyLocation({
    bool select = true,
    bool silent = false,
  }) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!silent) _toast('Nyalakan GPS/lokasi dulu ya.');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent) _toast('Izin lokasi dibutuhkan untuk fitur ini.');
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        if (!silent) _toast('Tidak bisa membaca lokasi perangkat.');
        return;
      }
      if (!mounted) return;

      final point = LatLng(pos.latitude, pos.longitude);
      _myPosition = point;
      if (select) {
        await _pickPoint(point);
      } else {
        _mapController.move(point, 16);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {}); // supaya tombol hapus (x) ikut muncul/hilang
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final results = await PlaceSearchService.search(
          q,
          near: _myPosition ?? _selectedLocation,
        );
        if (!mounted || _searchCtrl.text.trim() != q) return;
        setState(() => _suggestions = results);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _searchCtrl.text = s.title;
    });
    try {
      final point = await PlaceSearchService.resolve(s);
      if (!mounted) return;
      final label = s.subtitle.isEmpty ? s.title : '${s.title}, ${s.subtitle}';
      await _pickPoint(point, label: label);
    } catch (_) {
      _toast('Gagal mengambil lokasi "${s.title}".');
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    setState(() {
      _searchCtrl.clear();
      _suggestions = [];
      _searching = false;
    });
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

    setState(() => _loading = true);

    try {
      final user = await AuthService.restoreSession();
      if (!mounted) return;
      if (user == null) {
        setState(() => _loading = false);
        _toast('Sesi login belum aktif. Silakan masuk, lalu kirim lagi.');
        return;
      }

      final uploadedMedia = <LaporanMedia>[];
      for (final item in List<_SelectedReportMedia>.of(_selectedMedia)) {
        try {
          final url = item.isVideo
              ? await LaporanService.uploadVideo(item.file)
              : await LaporanService.uploadFoto(item.file);
          if (url != null && url.isNotEmpty) {
            uploadedMedia.add(
                LaporanMedia(url: url, type: item.isVideo ? 'video' : 'image'));
          }
        } catch (e) {
          final errorMsg = e.toString().replaceFirst('Exception: ', '');
          if (!mounted) return;
          setState(() => _loading = false);

          final tetapKirim = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: AppColors.red, size: 24),
                  const SizedBox(width: 8),
                  Text('Upload Media Gagal',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.text)),
                ],
              ),
              content: Text(
                '$errorMsg\n\nLanjutkan laporan dengan media yang berhasil diunggah? File yang gagal akan dilewati.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.text2, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Batal',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, color: AppColors.text3)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Lanjutkan',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );

          if (tetapKirim != true) return;
          if (mounted) setState(() => _loading = true);
        }
      }

      final imageUrl = uploadedMedia
          .where((item) => !item.isVideo)
          .map((item) => item.url)
          .firstOrNull;
      final videoUrl = uploadedMedia
          .where((item) => item.isVideo)
          .map((item) => item.url)
          .firstOrNull;

      final laporan = LaporanModel(
        uid: user.uid,
        namaUser: user.displayName ?? user.email ?? 'Anonim',
        kategori: _kats[_selectedKat!].label,
        lokasi: _lokasiCtrl.text.trim().isEmpty
            ? 'Lokasi dari Peta'
            : _lokasiCtrl.text.trim(),
        deskripsi: _descCtrl.text.trim(),
        hasPhoto: _selectedMedia.isNotEmpty,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        media: uploadedMedia,
        createdAt: DateTime.now(),
        geoPoint:
            GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
      );

      await LaporanService.kirim(laporan);

      // Reset form
      setState(() {
        _selectedKat = null;
        _selectedMedia.clear();
        _selectedLocation = null;
        _suggestions = [];
        _autoLokasi = true;
      });
      _descCtrl.clear();
      _lokasiCtrl.clear();
      _searchCtrl.clear();

      widget.onKirim(); // tampilkan toast sukses
    } catch (e) {
      _toast('Gagal mengirim laporan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Tambah foto'),
                subtitle: const Text('Pilih beberapa foto sekaligus'),
                onTap: () => Navigator.pop(context, 'image')),
            ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Tambah video'),
                subtitle: const Text('Maksimal 60 detik per video'),
                onTap: () => Navigator.pop(context, 'video')),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'image') {
      final remaining = _maxMediaCount - _selectedMedia.length;
      if (remaining <= 0) {
        _toast('Maksimal $_maxMediaCount file untuk satu laporan.');
        return;
      }
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        limit: remaining,
      );
      if (pickedFiles.isEmpty || !mounted) return;
      final files = pickedFiles.take(remaining).map((file) =>
          _SelectedReportMedia(file: File(file.path), isVideo: false));
      setState(() => _selectedMedia.addAll(files));
      if (pickedFiles.length > remaining) {
        _toast('Satu laporan maksimal $_maxMediaCount file.');
      }
      return;
    }

    if (_selectedMedia.length >= _maxMediaCount) {
      _toast('Maksimal $_maxMediaCount file untuk satu laporan.');
      return;
    }
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (pickedFile != null && mounted) {
      setState(() => _selectedMedia.add(
          _SelectedReportMedia(file: File(pickedFile.path), isVideo: true)));
    }
  }

  void _removeMedia(_SelectedReportMedia media) {
    setState(() => _selectedMedia.remove(media));
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                            _CLabel('Lokasi Kejadian'),
                            const SizedBox(height: 3),
                            Text(
                              'Cari tempat, tap peta, atau pakai tombol GPS.',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: AppColors.text3),
                            ),
                            const SizedBox(height: 11),

                            // Kolom cari
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
                                  const Icon(Icons.search_rounded,
                                      color: AppColors.text2, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      onChanged: _onSearchChanged,
                                      textInputAction: TextInputAction.search,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14, color: AppColors.text),
                                      decoration: InputDecoration(
                                        hintText: 'Cari tempat atau jalan...',
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
                                  if (_searching)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 10),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.red),
                                      ),
                                    )
                                  else if (_searchCtrl.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: _clearSearch,
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 10),
                                        child: Icon(Icons.close_rounded,
                                            color: AppColors.text3, size: 18),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Hasil pencarian
                            if (_suggestions.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _SuggestionBox(
                                suggestions: _suggestions,
                                onSelected: _selectSuggestion,
                              ),
                            ],
                            const SizedBox(height: 11),

                            // Peta
                            Container(
                              height: 220,
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
                                      // Arahkan kamera ke posisi kita saat peta
                                      // muncul (tanpa memilih titiknya).
                                      onMapReady: () => _goToMyLocation(
                                          select: false, silent: true),
                                      onTap: (tapPos, latLng) {
                                        FocusScope.of(context).unfocus();
                                        setState(() => _suggestions = []);
                                        _pickPoint(latLng, moveMap: false);
                                      },
                                    ),
                                    children: [
                                      const OpenStreetMapTileLayer(),
                                      if (_myPosition != null)
                                        MarkerLayer(markers: [
                                          Marker(
                                            point: _myPosition!,
                                            width: 22,
                                            height: 22,
                                            child: const _MyLocationDot(),
                                          )
                                        ]),
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
                                  // Tombol GPS: pusatkan peta + pilih lokasi kita
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: GestureDetector(
                                      onTap: _locating ? null : _goToMyLocation,
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.15),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3))
                                          ],
                                        ),
                                        child: _locating
                                            ? const Padding(
                                                padding: EdgeInsets.all(11),
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: AppColors.red),
                                              )
                                            : const Icon(
                                                Icons.my_location_rounded,
                                                color: AppColors.red,
                                                size: 22),
                                      ),
                                    ),
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

                            // Detail nama jalan/tempat (terisi otomatis, bisa diedit)
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
                                      // Kalau user mengetik sendiri, jangan
                                      // ditimpa teks otomatis lagi.
                                      onChanged: (_) => _autoLokasi = false,
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
                            Row(children: [
                              Expanded(child: _CLabel('Bukti foto & video')),
                              Text('${_selectedMedia.length}/$_maxMediaCount',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.text3,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 5),
                            Text(
                                'Pilih beberapa foto dan video dalam satu laporan.',
                                style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.text3, fontSize: 11)),
                            const SizedBox(height: 13),
                            if (_selectedMedia.isEmpty)
                              _EmptyMediaPicker(onTap: _pickMedia)
                            else
                              Wrap(
                                spacing: 9,
                                runSpacing: 9,
                                children: [
                                  for (final item in _selectedMedia)
                                    _ReportMediaThumbnail(
                                      item: item,
                                      onRemove: () => _removeMedia(item),
                                    ),
                                  if (_selectedMedia.length < _maxMediaCount)
                                    _AddMediaTile(onTap: _pickMedia),
                                ],
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

/// Daftar hasil pencarian lokasi (maks. beberapa baris, tanpa scroll sendiri).
class _SelectedReportMedia {
  final File file;
  final bool isVideo;

  const _SelectedReportMedia({required this.file, required this.isVideo});
}

class _EmptyMediaPicker extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyMediaPicker({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.cream3,
            borderRadius: 16,
            dashWidth: 7,
            dashSpace: 5,
            strokeWidth: 1.5,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.red, size: 28),
              const SizedBox(height: 7),
              Text('Tambah foto atau video',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Maks. 5 file · video hingga 60 detik',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text3, fontSize: 10)),
            ]),
          ),
        ),
      );
}

class _ReportMediaThumbnail extends StatelessWidget {
  final _SelectedReportMedia item;
  final VoidCallback onRemove;
  const _ReportMediaThumbnail({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(fit: StackFit.expand, children: [
            if (item.isVideo)
              const ColoredBox(
                  color: Color(0xFF252525),
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white, size: 34))
            else
              Image.file(item.file, fit: BoxFit.cover),
            if (item.isVideo)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('VIDEO',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4)),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: .58),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _AddMediaTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMediaTile({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.cream3)),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: AppColors.red, size: 25),
                SizedBox(height: 3),
                Text('Tambah',
                    style: TextStyle(
                        color: AppColors.text2,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}

class _SuggestionBox extends StatelessWidget {
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelected;

  const _SuggestionBox({required this.suggestions, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cream3, width: 1.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.cream),
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: const Icon(Icons.location_on_outlined,
                  color: AppColors.text2, size: 22),
              title: Text(
                suggestions[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text),
              ),
              subtitle: suggestions[i].subtitle.isEmpty
                  ? null
                  : Text(
                      suggestions[i].subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppColors.text2),
                    ),
              onTap: () => onSelected(suggestions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Titik biru kecil penanda posisi kita di peta pemilih lokasi.
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07869A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
    );
  }
}

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
