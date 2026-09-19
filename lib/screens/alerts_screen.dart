import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/laporan_service.dart';
import '../models/laporan_model.dart';
import 'detail_laporan_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _filterIdx = 0;
  final _filters = ['Terdekat', 'Terbaru', 'Kriminalitas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.shield_rounded,
                        color: AppColors.red, size: 22),
                    const SizedBox(width: 6),
                    Text('SafeZone',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.red)),
                  ]),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                        color: AppColors.cream2, shape: BoxShape.circle),
                    child: const Icon(Icons.account_circle_rounded,
                        color: AppColors.text2, size: 22),
                  ),
                ],
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daftar Laporan Masuk',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          height: 1.1)),
                  const SizedBox(height: 4),
                  Text('Laporan kriminalitas terverifikasi oleh warga sekitar.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppColors.text2)),
                ],
              ),
            ),

            // ── Filter chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: List.generate(_filters.length, (i) {
                  final active = _filterIdx == i;
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < _filters.length - 1 ? 10 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterIdx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: active ? AppColors.red : Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: active ? AppColors.red : AppColors.cream2,
                              width: 1.5),
                        ),
                        child: Text(_filters[i],
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    active ? Colors.white : AppColors.text2)),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── List Laporan Realtime ──
            Expanded(
              child: StreamBuilder<List<LaporanModel>>(
                stream: LaporanService.streamAll(),
                initialData: const [],
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'Gagal memuat laporan.\nCek koneksi internet atau konfigurasi Firebase.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text2, height: 1.5),
                        ),
                      ),
                    );
                  }

                  final laporan = snapshot.data ?? [];

                  if (laporan.isEmpty) {
                    return _EmptyState(
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: laporan.length + 2,
                    itemBuilder: (context, i) {
                      if (i < laporan.length) {
                        final item = laporan[i];
                        final isFirst = i == 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: GestureDetector(
                            onTap: () {
                              if (item.id != null) {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      DetailLaporanScreen(laporanId: item.id!),
                                ));
                              }
                            },
                            child: isFirst
                                ? _LaporanCardUtama(laporan: item)
                                : _LaporanCardKecil(laporan: item),
                          ),
                        );
                      } else if (i == laporan.length) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: _AksiWargaCard(),
                        );
                      } else {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: _WaspadaCard(),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Laporan Utama ──
class _LaporanCardUtama extends StatelessWidget {
  final LaporanModel laporan;
  const _LaporanCardUtama({required this.laporan});

  @override
  Widget build(BuildContext context) {
    final kat = _katInfo(laporan.kategori);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
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
              Text(_timeAgo(laporan.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.text3)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.redLight, shape: BoxShape.circle),
                child: Icon(kat.icon, color: AppColors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(laporan.kategori,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(laporan.deskripsi,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.text2, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          // Foto Bukti
          if (laporan.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                laporan.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 160,
                        color: AppColors.cream,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.red, strokeWidth: 2)),
                      ),
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  color: AppColors.text3, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(laporan.lokasi,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.text3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified_user_rounded,
                  color: AppColors.red, size: 14),
              const SizedBox(width: 4),
              Text('${laporan.konfirmasi} Verifikasi',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.red,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (laporan.id != null) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DetailLaporanScreen(laporanId: laporan.id!),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Pantau Lokasi',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Laporan Kecil ──
class _LaporanCardKecil extends StatelessWidget {
  final LaporanModel laporan;
  const _LaporanCardKecil({required this.laporan});

  @override
  Widget build(BuildContext context) {
    final kat = _katInfo(laporan.kategori);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: kat.bgColor, shape: BoxShape.circle),
                child: Icon(kat.icon, color: kat.iconColor, size: 18),
              ),
              Text(_timeAgo(laporan.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.text3)),
            ],
          ),
          const SizedBox(height: 10),
          Text(laporan.kategori,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 4),
          Text(laporan.deskripsi,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.text2, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          // Thumbnail foto kecil kalau ada
          if (laporan.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                laporan.imageUrl!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.navigation_rounded,
                    color: AppColors.red, size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(laporan.lokasi,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.red,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              Row(children: [
                const Icon(Icons.remove_red_eye_outlined,
                    color: AppColors.text3, size: 13),
                const SizedBox(width: 4),
                Text('${laporan.konfirmasi} saksi',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.text3)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Aksi Warga Card ──
class _AksiWargaCard extends StatelessWidget {
  const _AksiWargaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.yellow, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF7A5800), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aksi Warga',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF7A5800))),
                const SizedBox(height: 3),
                Text(
                    'Siskamling diaktifkan di RW 04 merespon maraknya curanmor.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF7A5800),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waspada Card ──
class _WaspadaCard extends StatelessWidget {
  const _WaspadaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
          color: const Color(0xFF7A3B2E),
          borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text('82%',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1)),
          Text('WASPADA',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 2)),
          const SizedBox(height: 6),
          Text('Indeks keamanan menurun di area ini',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: Colors.white.withOpacity(0.65)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Empty State ──
class _EmptyState extends StatelessWidget {
  final bool isLoading;

  const _EmptyState({this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.redLight, shape: BoxShape.circle),
            child:
                const Icon(Icons.inbox_rounded, color: AppColors.red, size: 36),
          ),
          const SizedBox(height: 16),
          Text(isLoading ? 'Memuat laporan...' : 'Belum ada laporan',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text(
              isLoading
                  ? 'Kalau koneksi lambat, halaman ini tetap akan update otomatis.'
                  : 'Jadilah yang pertama melaporkan\nkejadian di sekitarmu!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.text2, height: 1.5)),
          if (isLoading) ...[
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: AppColors.red, strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helpers ──
class _KatInfo {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  _KatInfo(this.icon, this.bgColor, this.iconColor);
}

_KatInfo _katInfo(String kategori) {
  switch (kategori) {
    case 'Begal':
      return _KatInfo(
          Icons.motorcycle_rounded, AppColors.redLight, AppColors.red);
    case 'Tawuran':
      return _KatInfo(Icons.people_alt_rounded, const Color(0xFFFEF3C7),
          const Color(0xFF92400E));
    case 'Kecelakaan':
      return _KatInfo(Icons.directions_car_rounded, const Color(0xFFDCFCE7),
          const Color(0xFF166534));
    default:
      return _KatInfo(Icons.warning_rounded, AppColors.cream, AppColors.text2);
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}
