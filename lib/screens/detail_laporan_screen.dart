import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import '../app_colors.dart';
import '../models/laporan_model.dart';
import '../services/laporan_service.dart';
import '../services/auth_service.dart';
import '../widgets/open_street_map_tile_layer.dart';
import '../widgets/report_video_player.dart';

class DetailLaporanScreen extends StatefulWidget {
  final String laporanId;
  final LaporanModel? initialLaporan;
  const DetailLaporanScreen({
    super.key,
    required this.laporanId,
    this.initialLaporan,
  });

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
  // Selama ini true, tombol vote dikunci sementara sampai kita tahu pasti
  // apakah user ini sudah pernah vote laporan ini (dicek dari Firestore,
  // bukan cuma ditebak dari state layar yang selalu kosong tiap dibuka).
  bool _checkingVote = true;

  // Sebelumnya LaporanService.vote()/getMyVote() mengambil user langsung
  // dari FirebaseAuth.instance.currentUser di dalam service. Kalau app
  // ternyata punya sesi login yang tidak selalu identik dengan itu (AuthService
  // dipakai di semua tempat lain, termasuk kirim laporan & komentar yang
  // sudah terbukti jalan), FirebaseAuth.instance bisa saja null padahal user
  // kelihatan sudah login -> vote gagal diam-diam (tombol seperti tidak
  // merespon). Sekarang uid diambil dari sini, sumber yang sama dengan fitur
  // lain, lalu dikirim eksplisit ke service.
  String? get _uid => AuthService.currentUser?.uid;

  void _openPhoto(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenPhoto(url: url),
      ),
    );
  }

  StreamSubscription? _laporanSub;
  StreamSubscription? _komentarSub;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.initialLaporan != null) {
      _laporan = widget.initialLaporan;
      _localKonfirmasi = widget.initialLaporan!.konfirmasi;
      _localHoax = widget.initialLaporan!.hoax;
      final currentUid = _uid;
      if (currentUid != null &&
          widget.initialLaporan!.voters.containsKey(currentUid)) {
        _myVote = widget.initialLaporan!.voters[currentUid];
        _checkingVote = false;
      }
    }
    final uid = _uid;
    if (uid == null) {
      _checkingVote = false;
    } else {
      LaporanService.getMyVote(widget.laporanId, uid: uid).then((vote) {
        if (mounted) {
          setState(() {
            _myVote = vote;
            _checkingVote = false;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _checkingVote = false);
      });
    }
    // Listen laporan stream
    _laporanSub = LaporanService.streamById(widget.laporanId).listen(
      (l) {
        if (mounted) {
          if (l != null) {
            setState(() {
              _laporan = l;
              _localKonfirmasi = l.konfirmasi;
              _localHoax = l.hoax;
              final currentUid = _uid;
              if (currentUid != null && l.voters.containsKey(currentUid)) {
                _myVote = l.voters[currentUid];
                _checkingVote = false;
              }
            });
          } else {
            setState(() {
              _errorMsg = 'Laporan tidak ditemukan atau telah dihapus.';
            });
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMsg = 'Gagal memuat detail laporan.\n$e';
          });
        }
      },
    );
    // Listen komentar stream
    _komentarSub =
        LaporanService.streamKomentar(widget.laporanId).listen((list) {
      if (mounted) setState(() => _komentars = list);
    });

    // Safety timeout: if still loading after 8s and no error/data, show retry error
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _laporan == null && _errorMsg == null) {
        setState(() {
          _errorMsg =
              'Koneksi lambat atau laporan tidak dapat dimuat.\nSilakan coba lagi.';
        });
      }
    });
  }

  @override
  void dispose() {
    _laporanSub?.cancel();
    _komentarSub?.cancel();
    _komentarCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Optimistic Vote ──
  void _vote(bool isKonfirmasi) {
    if (_myVote != null || _checkingVote) return; // udah pernah vote
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kamu harus login dulu untuk vote.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        ),
      );
      return;
    }

    if (_laporan != null && _laporan!.uid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kamu tidak bisa memvalidasi laporan buatanmu sendiri.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        ),
      );
      return;
    }

    setState(() {
      _myVote = isKonfirmasi;
      if (isKonfirmasi) {
        _localKonfirmasi++;
      } else {
        _localHoax++;
      }
    });

    // Kirim ke Firebase di background.
    LaporanService.vote(widget.laporanId, isKonfirmasi, uid: uid)
        .catchError((e) {
      if (mounted) {
        final errorMsg = e is StateError
            ? e.message
            : (e is FirebaseException && e.code == 'permission-denied'
                ? 'Voting ditolak oleh aturan Firestore. Aturan database perlu mengizinkan vote dari pengguna yang login.'
                : (e is FirebaseException
                    ? (e.message ?? 'Gagal memvalidasi.')
                    : e.toString().replaceFirst('Exception: ', '')));

        // Jika errornya karena sudah pernah vote, jangan rollback _myVote jadi null!
        // Tombol harus tetap terkunci.
        if (errorMsg.contains('sudah pernah') ||
            errorMsg.contains('buatanmu sendiri')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white)),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            ),
          );
          return;
        }

        setState(() {
          _myVote = null;
          if (isKonfirmasi) {
            _localKonfirmasi--;
          } else {
            _localHoax--;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg,
                style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
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
    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMsg!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
    final uid = _uid;
    final isOwner = uid != null && laporan.uid == uid;
    // Sudah vote (apa pun pilihannya) atau pemilik laporan -> kedua tombol dikunci permanen
    final hasVoted = _myVote != null || _checkingVote || isOwner;

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

                        if (laporan.media.isNotEmpty) ...[
                          Text('Bukti media · ${laporan.media.length}',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 9),
                          SizedBox(
                            height: 205,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: laporan.media.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final media = laporan.media[index];
                                final width = laporan.media.length == 1
                                    ? MediaQuery.sizeOf(context).width - 40
                                    : 278.0;
                                return _LaporanMediaCard(
                                  media: media,
                                  width: width,
                                  onOpenPhoto: () => _openPhoto(media.url),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else if (laporan.hasPhoto) ...[
                          // hasPhoto true tapi imageUrl null -> upload foto
                          // sempat gagal waktu laporan ini dikirim.
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off_rounded,
                                    color: AppColors.text3, size: 26),
                                const SizedBox(height: 6),
                                Text('Foto gagal diupload saat laporan dikirim',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12, color: AppColors.text3)),
                              ],
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

                        // ── Vote Status Banner & Buttons ──
                        if (isOwner)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 18, color: AppColors.text3),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ini laporan buatanmu sendiri (tidak dapat divalidasi sendiri).',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.text2,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_myVote != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _myVote == true
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFFFF3F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _myVote == true
                                    ? const Color(0xFF10B981)
                                    : AppColors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _myVote == true
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 18,
                                  color: _myVote == true
                                      ? const Color(0xFF10B981)
                                      : AppColors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Kamu sudah memvalidasi laporan ini sebagai "${_myVote == true ? 'Beneran Ada' : 'Hoax Nih'}".',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: _myVote == true
                                            ? const Color(0xFF047857)
                                            : AppColors.red,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        _VoteButton(
                          icon: Icons.verified_user_rounded,
                          label: 'Beneran Ada',
                          count: _localKonfirmasi,
                          picked: _myVote == true,
                          hasVoted: hasVoted,
                          pickedColor: const Color(0xFF10B981),
                          pickedBg: const Color(0xFFF0FDF4),
                          pickedIconBg: const Color(0xFFD1FAE5),
                          onTap: () => _vote(true),
                        ),
                        const SizedBox(height: 10),
                        _VoteButton(
                          icon: Icons.do_not_disturb_alt_rounded,
                          label: 'Hoax Nih',
                          count: _localHoax,
                          picked: _myVote == false,
                          hasVoted: hasVoted,
                          pickedColor: AppColors.red,
                          pickedBg: const Color(0xFFFFF3F2),
                          pickedIconBg: AppColors.redLight,
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
//
// Sebelumnya: "Beneran Ada" pakai isSelected = _myVote != null (jadi
// dianggap "terpilih" walau yang dipilih itu Hoax), dan "Hoax Nih" hanya
// mengunci dirinya sendiri (isSelected = _myVote == false), jadi kalau vote
// Beneran, tombol Hoax masih terlihat aktif & bisa dipencet.
//
// Sekarang [picked] hanya true untuk tombol yang BENAR-BENAR dipilih user,
// dan [hasVoted] (sama untuk kedua tombol) yang mengunci keduanya begitu
// salah satu sudah dipilih.
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool picked;
  final bool hasVoted;
  final Color pickedColor;
  final Color pickedBg;
  final Color pickedIconBg;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.picked,
    required this.hasVoted,
    required this.pickedColor,
    required this.pickedBg,
    required this.pickedIconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Terkunci begitu sudah vote (apa pun pilihannya), tapi hanya diwarnai
    // kalau memang tombol inilah yang dipilih.
    final locked = hasVoted && !picked;

    final borderColor =
        picked ? pickedColor : (locked ? AppColors.cream2 : AppColors.cream2);
    final bgColor = picked ? pickedBg : Colors.white;
    final iconBg = picked ? pickedIconBg : AppColors.cream;
    final iconColor = picked ? pickedColor : AppColors.text3;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: GestureDetector(
        onTap: hasVoted ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: iconColor),
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
                      Text('$count orang',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: picked ? pickedColor : AppColors.text3)),
                  ],
                ),
              ),
              if (picked)
                Icon(Icons.check_circle_rounded, color: pickedColor, size: 18)
              else if (!hasVoted)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.text3, size: 20),
            ],
          ),
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

class _LaporanMediaCard extends StatelessWidget {
  final LaporanMedia media;
  final double width;
  final VoidCallback onOpenPhoto;

  const _LaporanMediaCard({
    required this.media,
    required this.width,
    required this.onOpenPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: 205,
        child: media.isVideo
            ? Center(child: ReportVideoPlayer(url: media.url))
            : GestureDetector(
                onTap: onOpenPhoto,
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(
                    media.url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const ColoredBox(
                                color: AppColors.cream,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.red, strokeWidth: 2)),
                              ),
                    errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.cream,
                        child: Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: AppColors.text3, size: 30))),
                  ),
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color(0x99000000), shape: BoxShape.circle),
                      child: Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.zoom_out_map_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  final String url;

  const _FullScreenPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Tutup foto',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x66000000),
                  fixedSize: const Size.square(44),
                ),
              ),
            ),
          ],
        ),
      ),
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
