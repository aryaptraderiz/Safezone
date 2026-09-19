import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_colors.dart';
import '../models/laporan_model.dart';
import '../services/laporan_service.dart';
import '../services/auth_service.dart';
import '../widgets/open_street_map_tile_layer.dart';

class DetailLaporanScreen extends StatefulWidget {
  final String laporanId;
  const DetailLaporanScreen({super.key, required this.laporanId});

  @override
  State<DetailLaporanScreen> createState() => _DetailLaporanScreenState();
}

class _DetailLaporanScreenState extends State<DetailLaporanScreen> {
  final _komentarCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Optimistic state ──
  LaporanModel? _laporan;
  List<KomentarModel> _komentars = [];
  bool _sendingKomentar = false;
  int _localKonfirmasi = 0;
  int _localHoax = 0;
  bool? _myVote; // true=konfirmasi, false=hoax, null=belum

  @override
  void initState() {
    super.initState();
    // Listen laporan stream
    LaporanService.streamById(widget.laporanId).listen((l) {
      if (l != null && mounted) {
        setState(() {
          _laporan = l;
          // Sync angka hanya kalau belum ada pending vote
          if (_myVote == null) {
            _localKonfirmasi = l.konfirmasi;
            _localHoax = l.hoax;
          }
        });
      }
    });
    // Listen komentar stream
    LaporanService.streamKomentar(widget.laporanId).listen((list) {
      if (mounted) setState(() => _komentars = list);
    });
  }

  @override
  void dispose() {
    _komentarCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Optimistic Vote ──
  void _vote(bool isKonfirmasi) {
    if (_myVote != null) return; // udah pernah vote
    setState(() {
      _myVote = isKonfirmasi;
      if (isKonfirmasi) {
        _localKonfirmasi++;
      } else {
        _localHoax++;
      }
    });
    // Kirim ke Firebase di background, no await on UI
    LaporanService.vote(widget.laporanId, isKonfirmasi).catchError((_) {
      // Rollback kalau gagal
      if (mounted) {
        setState(() {
          _myVote = null;
          if (isKonfirmasi) {
            _localKonfirmasi--;
          } else {
            _localHoax--;
          }
        });
      }
    });
  }

  // ── Optimistic Komentar ──
  Future<void> _kirimKomentar() async {
    final user = AuthService.currentUser;
    final isi = _komentarCtrl.text.trim();
    if (isi.isEmpty || user == null || _sendingKomentar) return;

    // Buat komentar lokal dulu (optimistic)
    final localKomentar = KomentarModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      uid: user.uid,
      namaUser: user.displayName ?? user.email ?? 'Anonim',
      isi: isi,
      createdAt: DateTime.now(),
      suka: 0,
    );

    setState(() {
      _komentars = [..._komentars, localKomentar];
      _sendingKomentar = true;
    });

    _komentarCtrl.clear();
    FocusScope.of(context).unfocus();

    // Scroll ke bawah smooth
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      await LaporanService.kirimKomentar(
        widget.laporanId,
        KomentarModel(
          uid: user.uid,
          namaUser: user.displayName ?? user.email ?? 'Anonim',
          isi: isi,
          createdAt: DateTime.now(),
        ),
      );
      // Stream akan update dan replace local komentar otomatis
    } catch (_) {
      // Rollback komentar lokal kalau gagal
      if (mounted) {
        setState(() {
          _komentars =
              _komentars.where((k) => k.id != localKomentar.id).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal kirim komentar, coba lagi.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingKomentar = false);
    }
  }

  // ── Optimistic Like ──
  void _sukaiKomentar(KomentarModel k) {
    if (k.id == null || k.id!.startsWith('local_')) return;
    setState(() {
      _komentars = _komentars.map((item) {
        if (item.id == k.id) {
          return KomentarModel(
            id: item.id,
            uid: item.uid,
            namaUser: item.namaUser,
            isi: item.isi,
            createdAt: item.createdAt,
            suka: item.suka + 1,
          );
        }
        return item;
      }).toList();
    });
    LaporanService.sukaiKomentar(widget.laporanId, k.id!).catchError((_) {
      // Rollback
      if (mounted) {
        setState(() {
          _komentars = _komentars.map((item) {
            if (item.id == k.id) {
              return KomentarModel(
                id: item.id,
                uid: item.uid,
                namaUser: item.namaUser,
                isi: item.isi,
                createdAt: item.createdAt,
                suka: item.suka - 1,
              );
            }
            return item;
          }).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_laporan == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.red, strokeWidth: 2)),
      );
    }

    final laporan = _laporan!;
    final total = _localKonfirmasi + _localHoax;
    final persen = total == 0 ? 0.0 : _localKonfirmasi / total;
    final persenText = '${(persen * 100).toStringAsFixed(0)}% Terverifikasi';
    final kat = _katInfo(laporan.kategori);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // ── AppBar ──
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.text, size: 20),
                    ),
                  ),
                  title: Text('Cek Laporannya',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 14),
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: AppColors.cream2, shape: BoxShape.circle),
                      child: const Icon(Icons.account_circle_rounded,
                          color: AppColors.text2, size: 22),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [kat.bgGradientTop, kat.bgGradientBot],
                            ),
                          ),
                          child: Icon(kat.icon,
                              size: 80, color: Colors.white.withOpacity(0.15)),
                        ),
                        Positioned(
                          top: 90,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(50)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                                Text('HATI-HATI!',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Reporter ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.cream2,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.yellow, width: 2),
                                ),
                                child: const Icon(Icons.account_circle_rounded,
                                    color: AppColors.text2, size: 24),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(laporan.namaUser,
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.text)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded,
                                        color: AppColors.red, size: 14),
                                  ]),
                                  Text(
                                      'Trusted Reporter · ${_timeAgo(laporan.createdAt)}',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.text3)),
                                ],
                              ),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.circular(50)),
                              child: Row(children: [
                                Text('LV. 12',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text)),
                                const SizedBox(width: 4),
                                const Text('🏆',
                                    style: TextStyle(fontSize: 12)),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ── Judul ──
                        Row(children: [
                          Expanded(
                            child: Text(
                              '${laporan.kategori} di ${laporan.lokasi}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                  height: 1.2),
                            ),
                          ),
                          const Text('⚠️', style: TextStyle(fontSize: 22)),
                        ]),
                        const SizedBox(height: 12),

                        // ── Deskripsi ──
                        Text(laporan.deskripsi,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.text2,
                                height: 1.6)),
                        const SizedBox(height: 20),

                        // ── Lokasi ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.location_on_rounded,
                                  color: AppColors.red, size: 16),
                              const SizedBox(width: 6),
                              Text(laporan.lokasi,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.text2,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            Text('Buka Map',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Foto ──
                        if (laporan.imageUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              laporan.imageUrl!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Map ──
                        if (laporan.geoPoint != null)
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.cream, width: 1.5)),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const OpenStreetMapFallback(dense: true),
                                FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      laporan.geoPoint!.latitude,
                                      laporan.geoPoint!.longitude,
                                    ),
                                    initialZoom: 16,
                                    interactionOptions:
                                        const InteractionOptions(
                                      flags: InteractiveFlag.none,
                                    ),
                                  ),
                                  children: [
                                    const OpenStreetMapTileLayer(),
                                    MarkerLayer(markers: [
                                      Marker(
                                        point: LatLng(
                                          laporan.geoPoint!.latitude,
                                          laporan.geoPoint!.longitude,
                                        ),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: AppColors.red,
                                          size: 40,
                                        ),
                                      )
                                    ]),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(16)),
                            child: Center(
                              child: Text('Lokasi tidak tersedia di peta',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, color: AppColors.text3)),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // ── Status Verifikasi ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('STATUS LAPORAN',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text3,
                                    letterSpacing: 1.2)),
                            Text(persenText,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: LinearProgressIndicator(
                            value: persen,
                            minHeight: 7,
                            backgroundColor: AppColors.cream2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.green),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Vote Buttons ──
                        _VoteButton(
                          icon: Icons.verified_user_rounded,
                          label: 'Beneran Ada',
                          count: _localKonfirmasi,
                          isActive: _myVote == true,
                          isSelected: _myVote != null,
                          onTap: () => _vote(true),
                        ),
                        const SizedBox(height: 10),
                        _VoteButton(
                          icon: Icons.do_not_disturb_alt_rounded,
                          label: 'Hoax Nih',
                          count: _localHoax,
                          isActive: false,
                          isSelected: _myVote == false,
                          onTap: () => _vote(false),
                        ),
                        const SizedBox(height: 28),

                        // ── Diskusi Warga ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Text('Diskusi Warga',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text)),
                              const SizedBox(width: 6),
                              const Text('💬', style: TextStyle(fontSize: 16)),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.circular(50)),
                              child: Text('${_komentars.length} Komentar',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text2)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_komentars.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                  'Belum ada komentar. Jadi yang pertama!',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, color: AppColors.text3)),
                            ),
                          ),

                        ..._komentars.map((k) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _KomentarItem(
                                komentar: k,
                                onSuka: () => _sukaiKomentar(k),
                              ),
                            )),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Input Komentar ──
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                  top: BorderSide(color: AppColors.cream, width: 1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _komentarCtrl,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Tulis tanggapan kamu...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: AppColors.text3),
                      filled: true,
                      fillColor: AppColors.cream,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _kirimKomentar(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendingKomentar ? null : _kirimKomentar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _sendingKomentar
                          ? AppColors.red.withOpacity(0.5)
                          : AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: _sendingKomentar
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
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

// ── Vote Button ──
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isActive,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final voted = isSelected;
    return GestureDetector(
      onTap: voted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFF0FDF4)
              : voted
                  ? const Color(0xFFFFF3F2)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isActive
                  ? const Color(0xFF10B981)
                  : voted
                      ? AppColors.red
                      : AppColors.cream2,
              width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFD1FAE5)
                    : voted
                        ? AppColors.redLight
                        : AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF059669)
                      : voted
                          ? AppColors.red
                          : AppColors.text3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  if (count > 0)
                    Text('$count ${isActive ? "Konfirmasi" : "Laporan"}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? const Color(0xFF059669)
                                : AppColors.text3)),
                ],
              ),
            ),
            if (voted)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.red, size: 18)
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.text3, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Komentar Item ──
class _KomentarItem extends StatelessWidget {
  final KomentarModel komentar;
  final VoidCallback onSuka;

  const _KomentarItem({required this.komentar, required this.onSuka});

  @override
  Widget build(BuildContext context) {
    final isLocal = komentar.id?.startsWith('local_') ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: AppColors.cream2, shape: BoxShape.circle),
          child: const Icon(Icons.account_circle_rounded,
              color: AppColors.text3, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedOpacity(
            opacity: isLocal ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(komentar.namaUser,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text)),
                    Row(children: [
                      if (isLocal)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              color: AppColors.text3, strokeWidth: 1.5),
                        )
                      else
                        Text(_timeAgo(komentar.createdAt),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppColors.text3)),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                Text(komentar.isi,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: AppColors.text2, height: 1.4)),
                const SizedBox(height: 8),
                if (!isLocal)
                  Row(children: [
                    GestureDetector(
                      onTap: onSuka,
                      child: Row(children: [
                        Icon(
                            komentar.suka > 0
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 14,
                            color: AppColors.red),
                        const SizedBox(width: 4),
                        Text(
                            komentar.suka > 0
                                ? '${komentar.suka} SUKA'
                                : 'SUKA',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.red)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Row(children: [
                      const Icon(Icons.reply_rounded,
                          size: 14, color: AppColors.text3),
                      const SizedBox(width: 4),
                      Text('BALAS',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text3)),
                    ]),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ──
class _KatInfo {
  final IconData icon;
  final Color bgGradientTop;
  final Color bgGradientBot;
  _KatInfo(this.icon, this.bgGradientTop, this.bgGradientBot);
}

_KatInfo _katInfo(String kategori) {
  switch (kategori) {
    case 'Begal':
      return _KatInfo(Icons.motorcycle_rounded, const Color(0xFFD94435),
          const Color(0xFF8B1E14));
    case 'Tawuran':
      return _KatInfo(Icons.people_alt_rounded, const Color(0xFFD97706),
          const Color(0xFF92400E));
    case 'Kecelakaan':
      return _KatInfo(Icons.directions_car_rounded, const Color(0xFF1E6B4A),
          const Color(0xFF0D3D2A));
    default:
      return _KatInfo(Icons.warning_rounded, const Color(0xFF6B4F35),
          const Color(0xFF3D2D1E));
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
