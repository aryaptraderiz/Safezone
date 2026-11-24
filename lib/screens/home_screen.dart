import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../app_colors.dart';
import '../models/laporan_model.dart';
import '../models/saved_location_model.dart';
import '../services/auth_service.dart';
import '../services/laporan_service.dart';
import '../services/saved_location_service.dart';
import 'detail_laporan_screen.dart';
import 'notice_screen.dart';
import 'safe_chatbot_screen.dart';
import 'saved_locations_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenLapor;
  final VoidCallback? onOpenAlerts;
  final VoidCallback? onOpenSafeFriend;
  const HomeScreen({
    super.key,
    this.onOpenSettings,
    this.onOpenMap,
    this.onOpenLapor,
    this.onOpenAlerts,
    this.onOpenSafeFriend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _SafeHomeDashboard(
          onSettings: onOpenSettings,
          onMap: onOpenMap,
          onReport: onOpenLapor,
          onAlerts: onOpenAlerts,
          onSafeFriend: onOpenSafeFriend,
        ),
      ),
    );
  }
}

class _SafeHomeDashboard extends StatelessWidget {
  final VoidCallback? onSettings;
  final VoidCallback? onMap;
  final VoidCallback? onReport;
  final VoidCallback? onAlerts;
  final VoidCallback? onSafeFriend;

  const _SafeHomeDashboard({
    this.onSettings,
    this.onMap,
    this.onReport,
    this.onAlerts,
    this.onSafeFriend,
  });

  @override
  Widget build(BuildContext context) {
    final name = AuthService.currentUser?.displayName?.trim();
    return StreamBuilder<List<LaporanModel>>(
      stream: LaporanService.streamAll(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <LaporanModel>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          children: [
            _WelcomeCard(
                name: name,
                onSettings: onSettings,
                reports: reports),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Transform.translate(
                offset: const Offset(0, -28),
                child: _ShortcutPanel(
                  onProfile: onSettings,
                  onHelp: () => _showReportingGuide(context, onReport),
                  onNotice: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const NoticeScreen()),
                  ),
                  onChat: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SafeChatbotScreen()),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 0),
                    Row(children: [
                      Expanded(
                          child: _SectionHeading(title: 'Layanan keselamatan')),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: const Color(0xFFECE5DC))),
                          child: Text('7 layanan',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.text2,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 12),
                    const _SavedHomeCard(),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 11,
                      crossAxisSpacing: 11,
                      childAspectRatio: 1.52,
                      children: [
                        _ServiceTile(
                            icon: Icons.radar_rounded,
                            title: 'Home Monitoring',
                            subtitle: 'Pantau laporan',
                            color: const Color(0xFF3978D5),
                            onTap: onAlerts),
                        _ServiceTile(
                            icon: Icons.sos_rounded,
                            title: 'Nomor penting',
                            subtitle: 'Darurat & bantuan',
                            color: AppColors.red,
                            onTap: () => _showEmergencyNumbers(context)),
                        _ServiceTile(
                            icon: Icons.videocam_rounded,
                            title: 'Safe Video',
                            subtitle: 'Bukti kejadian',
                            color: const Color(0xFFE63E78),
                            onTap: onReport),
                        _ServiceTile(
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Safe Friend',
                            subtitle: 'Tambah teman',
                            color: const Color(0xFFD49A17),
                            onTap: onSafeFriend),
                        _ServiceTile(
                            icon: Icons.groups_rounded,
                            title: 'Scout',
                            subtitle: 'Komunitas sekitar',
                            color: const Color(0xFF8058B8),
                            onTap: onAlerts),
                        _ServiceTile(
                            icon: Icons.map_rounded,
                            title: 'Safety Map',
                            subtitle: 'Peta keamanan',
                            color: const Color(0xFF4586D6),
                            onTap: onMap),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Laporan terbaru',
                                style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('Info keamanan dari warga sekitar',
                                style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.text3, fontSize: 10.5)),
                          ])),
                      TextButton(
                          onPressed: onAlerts,
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10)),
                          child: const Text('Semua')),
                    ]),
                    const SizedBox(height: 9),
                    _RecentReportList(
                      reports: reports,
                      loading:
                          snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData,
                      error: snapshot.hasError,
                    ),
                  ]),
            ),
          ],
        );
      },
    );
  }
}

void _showHomeInfo(BuildContext context, String title, String message) {
  showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: Text(title,
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
            content:
                Text(message, style: GoogleFonts.plusJakartaSans(height: 1.5)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Mengerti'))
            ],
          ));
}

void _showReportingGuide(BuildContext context, VoidCallback? onReport) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Center(
                child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE4E8ED),
                        borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 22),
            Text('Panduan pelaporan',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 6),
            Text('Bantu warga sekitar dengan laporan yang jelas dan akurat.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.text2, height: 1.5)),
            const SizedBox(height: 18),
            const _GuideStep(
                number: '01',
                title: 'Pilih jenis kejadian',
                detail: 'Tentukan kategori yang paling sesuai.'),
            const _GuideStep(
                number: '02',
                title: 'Lengkapi informasi',
                detail: 'Tulis kronologi singkat dan lokasi kejadian.'),
            const _GuideStep(
                number: '03',
                title: 'Tambahkan bukti',
                detail: 'Sertakan foto atau video jika tersedia.'),
            const _GuideStep(
                number: '04',
                title: 'Kirim laporan',
                detail: 'Periksa kembali informasi sebelum dikirim.'),
            const SizedBox(height: 18),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onReport?.call();
                    },
                    icon: const Icon(Icons.edit_location_alt_rounded),
                    label: const Text('Mulai buat laporan'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14)))),
          ])),
    ),
  );
}

class _GuideStep extends StatelessWidget {
  final String number, title, detail;
  const _GuideStep(
      {required this.number, required this.title, required this.detail});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color(0xFFFFF0EF),
              borderRadius: BorderRadius.circular(11)),
          child: Text(number,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(detail,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text2, fontSize: 11, height: 1.4))
        ]))
      ]));
}

void _showEmergencyNumbers(BuildContext context) {
  showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4E8ED),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text('Nomor penting',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 12),
            const _EmergencyNumberList()
          ]))));
}

class _ShortcutPanel extends StatelessWidget {
  final VoidCallback? onProfile, onHelp, onNotice, onChat;
  const _ShortcutPanel(
      {this.onProfile, this.onHelp, this.onNotice, this.onChat});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 13, 8, 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFECE8E3)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF3B2416).withValues(alpha: .055),
                  blurRadius: 18,
                  offset: const Offset(0, 6))
            ]),
        child: Row(children: [
          Expanded(
              child: _ShortcutItem(
                  icon: Icons.person_rounded,
                  label: 'My Info',
                  color: const Color(0xFF45627D),
                  onTap: onProfile)),
          Expanded(
              child: _ShortcutItem(
                  icon: Icons.info_rounded,
                  label: 'Help',
                  color: const Color(0xFF45627D),
                  onTap: onHelp)),
          Expanded(
              child: _ShortcutItem(
                  icon: Icons.campaign_rounded,
                  label: 'Notice',
                  color: const Color(0xFF45627D),
                  onTap: onNotice)),
          Expanded(
              child: _ShortcutItem(
                  icon: Icons.smart_toy_rounded,
                  label: 'Safe Chatbot',
                  color: const Color(0xFF5793C8),
                  onTap: onChat)),
        ]),
      );
}

class _ShortcutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ShortcutItem(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(children: [
            Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700))
          ])));
}

class _WelcomeCard extends StatelessWidget {
  final String? name;
  final VoidCallback? onSettings;
  final List<LaporanModel> reports;
  const _WelcomeCard(
      {required this.name, required this.reports, this.onSettings});

  @override
  Widget build(BuildContext context) {
    final firstName =
        name == null || name!.isEmpty ? 'Teman' : name!.split(' ').first;
    return SizedBox(
      height: 380,
      child: ClipRRect(
        child: Stack(fit: StackFit.expand, children: [
          const _HeroMascotBanner(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .34),
                  Colors.transparent,
                  Colors.black.withValues(alpha: .62),
                ],
                stops: const [0, .38, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('SAFEZONE',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.7,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 8)
                        ])),
                const Spacer(),
                _ReportNotificationButton(reports: reports),
                IconButton(
                    onPressed: onSettings,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 38, height: 38),
                    icon: const Icon(Icons.account_circle_outlined,
                        color: Colors.white, size: 23)),
              ]),
              const Spacer(),
              Text('Halo, $firstName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 10)
                      ])),
              const SizedBox(height: 7),
            const _CurrentLocationLine(),
              const SizedBox(height: 5),
              Text('Semoga perjalananmu hari ini aman.',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: .88),
                      fontSize: 11,
                      height: 1.35,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8)
                      ])),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CurrentLocationLine extends StatefulWidget {
  const _CurrentLocationLine();

  @override
  State<_CurrentLocationLine> createState() => _CurrentLocationLineState();
}

class _CurrentLocationLineState extends State<_CurrentLocationLine>
    with AutomaticKeepAliveClientMixin<_CurrentLocationLine> {
  String _label = 'Ketuk untuk melihat lokasimu';
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadLocation() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _label = 'Mencari lokasi…';
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationMessage('Aktifkan layanan lokasi di perangkat');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationMessage('Izin lokasi belum diberikan');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationMessage('Aktifkan izin lokasi di Pengaturan');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      final place =
          await _reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _label = place ?? 'Lokasi ditemukan';
      });
    } on _LocationMessage catch (error) {
      if (mounted) setState(() => _label = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _label = 'Lokasi belum ditemukan · ketuk untuk coba lagi');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'addressdetails': '1',
    });
    final response = await http.get(uri, headers: {
      'User-Agent': 'SafeZone/1.0 (location lookup)',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final address = data['address'];
    if (address is Map<String, dynamic>) {
      const preferred = [
        'neighbourhood',
        'suburb',
        'village',
        'town',
        'city_district',
        'city',
        'county',
      ];
      final parts = <String>[];
      for (final key in preferred) {
        final value = address[key];
        if (value is String && value.isNotEmpty && !parts.contains(value)) {
          parts.add(value);
          if (parts.length == 2) break;
        }
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }

    final displayName = data['display_name'];
    if (displayName is String && displayName.isNotEmpty) {
      return displayName.split(',').take(2).join(',').trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return InkWell(
      onTap: _loading ? null : _loadLocation,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_loading)
            const SizedBox(
              width: 19,
              height: 19,
              child: Padding(
                padding: EdgeInsets.all(3),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 20),
          const SizedBox(width: 5),
          Flexible(
            child: Text(_label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8)
                    ])),
          ),
          if (!_loading) ...[
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white70, size: 18),
          ],
        ]),
      ),
    );
  }
}

class _LocationMessage implements Exception {
  final String message;

  const _LocationMessage(this.message);
}

class _HeroMascotBanner extends StatefulWidget {
  const _HeroMascotBanner();

  @override
  State<_HeroMascotBanner> createState() => _HeroMascotBannerState();
}

class _HeroMascotBannerState extends State<_HeroMascotBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _zoom;
  late final VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 7))
          ..repeat(reverse: true);
    _zoom = Tween<double>(begin: 1.02, end: 1.09)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _videoController = VideoPlayerController.asset('assets/safezone_hero.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        _videoController.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _zoom,
        builder: (context, child) =>
            Transform.scale(scale: _zoom.value, child: child),
        child: _videoController.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                alignment: const Alignment(0, .05),
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              )
            : Image.asset('assets/safezone_mascot.jpg',
                fit: BoxFit.cover, alignment: const Alignment(0, .05)),
      );
}

class _ReportNotificationButton extends StatelessWidget {
  final List<LaporanModel> reports;
  const _ReportNotificationButton({required this.reports});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifikasi laporan',
      onPressed: () => _showReportNotifications(context, reports),
      icon: Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.notifications_none_rounded,
            color: AppColors.text2, size: 23),
        if (reports.isNotEmpty)
          Positioned(
              right: -2,
              top: -2,
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle)))
      ]),
    );
  }
}

void _showReportNotifications(
    BuildContext context, List<LaporanModel> reports) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: .62,
      minChildSize: .38,
      maxChildSize: .9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 11),
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE4E0DA),
                  borderRadius: BorderRadius.circular(5))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Notifikasi laporan',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('${reports.length} laporan terbaru di SafeZone',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text3, fontSize: 11)),
                  ])),
              IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon:
                      const Icon(Icons.close_rounded, color: AppColors.text2)),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFEDE9E3)),
          Expanded(
            child: reports.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                            color: Color(0xFFF1F3F6), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_none_rounded,
                            color: AppColors.text3, size: 27)),
                    const SizedBox(height: 12),
                    Text('Belum ada laporan',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Notifikasi laporan akan muncul di sini.',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text3, fontSize: 11))
                  ]))
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: report.id == null
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => DetailLaporanScreen(
                                          laporanId: report.id!,
                                          initialLaporan: report)));
                                },
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFEFED),
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: const Icon(Icons.campaign_rounded,
                                        color: AppColors.red, size: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(
                                                'Laporan ${report.kategori}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: AppColors.text,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800))),
                                        const SizedBox(width: 8),
                                        Text(_reportAge(report.createdAt),
                                            style: GoogleFonts.plusJakartaSans(
                                                color: AppColors.text3,
                                                fontSize: 9))
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(report.deskripsi,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                              color: AppColors.text2,
                                              fontSize: 10.5)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.place_outlined,
                                            color: AppColors.red, size: 13),
                                        const SizedBox(width: 3),
                                        Expanded(
                                            child: Text(report.lokasi,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: AppColors.text3,
                                                        fontSize: 9.5)))
                                      ]),
                                    ])),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.text3),
                              ])),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    ),
  );
}

class _FriendPreview extends StatelessWidget {
  final VoidCallback? onTap;
  const _FriendPreview({this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(children: [
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEAF4EF),
                          borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.people_alt_rounded,
                          color: Color(0xFF35846B), size: 23)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Teman perjalanan',
                            style: GoogleFonts.plusJakartaSans(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('Terhubung dan berbagi lokasi dengan teman',
                            maxLines: 2,
                            style: GoogleFonts.plusJakartaSans(
                                color: AppColors.text2,
                                fontSize: 10,
                                height: 1.4))
                      ])),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEAF4EF),
                          borderRadius: BorderRadius.circular(30)),
                      child: Text('Segera',
                          style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF35846B),
                              fontSize: 10,
                              fontWeight: FontWeight.w800))),
                ]))),
      );
}

class _SavedHomeCard extends StatelessWidget {
  const _SavedHomeCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedLocationModel>>(
      stream: SavedLocationService.streamAll(),
      builder: (context, snapshot) {
        final home = snapshot.data
            ?.where((location) => location.label == 'Rumah')
            .firstOrNull;
        final hasAddress = home?.address.trim().isNotEmpty == true;
        return Material(
          color: const Color(0xFFFFF5EC),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SavedLocationsScreen())),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0DECC)),
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: AppColors.red, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Save Home',
                            style: GoogleFonts.plusJakartaSans(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                        if (hasAddress) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE4F2E9),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('TERSIMPAN',
                                style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF36734E),
                                    fontSize: 7,
                                    letterSpacing: .3,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.connectionState == ConnectionState.waiting &&
                                !snapshot.hasData
                            ? 'Memuat lokasi rumah…'
                            : hasAddress
                                ? home!.address
                                : 'Atur alamat rumah untuk akses lebih cepat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text2,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.red, size: 17),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _ServiceTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFECE8E3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text3, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LiveReportSummary extends StatelessWidget {
  final VoidCallback? onTap;
  final int count;
  final bool loading;
  final bool error;
  const _LiveReportSummary(
      {this.onTap,
      required this.count,
      required this.loading,
      required this.error});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFECE8E3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.radar_rounded,
                    color: Color(0xFFB76736), size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        error
                            ? 'Memantau laporan warga'
                            : loading
                                ? 'Memuat laporan sekitar'
                                : 'Pantauan warga',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text(
                        error
                            ? 'Coba buka laporan warga'
                            : loading
                                ? 'Mengambil info terbaru'
                                : '$count laporan keamanan terbaru',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text3, fontSize: 10)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.text3, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction(
      {required this.icon,
      required this.title,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: AppColors.text3),
            ]),
          ),
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      );
}

class _EmergencyNumberList extends StatelessWidget {
  const _EmergencyNumberList();

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: const [
              Expanded(
                  child: _EmergencyNumber(
                      title: 'Darurat', number: '112', icon: Icons.emergency)),
              _EmergencyDivider(),
              Expanded(
                  child: _EmergencyNumber(
                      title: 'Polisi',
                      number: '110',
                      icon: Icons.local_police)),
              _EmergencyDivider(),
              Expanded(
                  child: _EmergencyNumber(
                      title: 'Medis',
                      number: '119',
                      icon: Icons.medical_services)),
            ],
          ),
        ),
      );
}

class _EmergencyDivider extends StatelessWidget {
  const _EmergencyDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 46,
        color: AppColors.cream,
      );
}

class _EmergencyNumber extends StatelessWidget {
  final String title;
  final String number;
  final IconData icon;
  const _EmergencyNumber(
      {required this.title, required this.number, required this.icon});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _dialNumber(context, number, title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.red, size: 19),
              const SizedBox(height: 5),
              Text(number,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text2,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _RecentReportList extends StatelessWidget {
  final List<LaporanModel> reports;
  final bool loading;
  final bool error;
  const _RecentReportList(
      {required this.reports, required this.loading, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error) {
      return const _SimpleInfoRow(
          icon: Icons.cloud_off_outlined,
          text: 'Tidak dapat memuat laporan saat ini.');
    }
    final latestReports = reports.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visibleReports = latestReports.take(3).toList();
    if (visibleReports.isEmpty) {
      return _SimpleInfoRow(
          icon: loading
              ? Icons.hourglass_empty_rounded
              : Icons.check_circle_outline_rounded,
          text: loading ? 'Memuat laporan...' : 'Belum ada laporan terbaru.');
    }
    return Column(
      children: visibleReports.map((report) {
        final category = report.kategori.toLowerCase();
        final categoryIcon = category.contains('begal')
            ? Icons.two_wheeler_rounded
            : category.contains('tawuran')
                ? Icons.groups_rounded
                : category.contains('kecelakaan')
                    ? Icons.car_crash_rounded
                    : Icons.report_gmailerrorred_rounded;
        final preview = report.imageUrl;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFECE8E3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: report.id == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DetailLaporanScreen(
                          laporanId: report.id!, initialLaporan: report))),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: SizedBox(
                              width: 62,
                              height: 62,
                              child: preview != null && preview.isNotEmpty
                                  ? Image.network(preview,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _ReportTypeIcon(
                                          icon: report.videoUrl == null
                                              ? categoryIcon
                                              : Icons
                                                  .play_circle_outline_rounded))
                                  : _ReportTypeIcon(
                                      icon: report.videoUrl == null
                                          ? categoryIcon
                                          : Icons.play_circle_outline_rounded),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(report.kategori,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.text,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF2E8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(_reportAge(report.createdAt),
                                        style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF9B5D32),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                                const SizedBox(height: 5),
                                Row(children: [
                                  const Icon(Icons.person_outline_rounded,
                                      size: 13, color: AppColors.text3),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(report.namaUser,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.text3,
                                            fontSize: 10)),
                                  ),
                                  if (report.videoUrl != null)
                                    const Icon(
                                        Icons.play_circle_outline_rounded,
                                        size: 16,
                                        color: AppColors.text3),
                                ]),
                              ],
                            ),
                          ),
                        ]),
                    const SizedBox(height: 11),
                    Text(report.deskripsi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text2,
                            fontSize: 11.5,
                            height: 1.4)),
                    const SizedBox(height: 11),
                    Container(height: 1, color: const Color(0xFFF2EFEB)),
                    const SizedBox(height: 9),
                    Row(children: [
                      const Icon(Icons.place_outlined,
                          color: AppColors.red, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(report.lokasi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                color: AppColors.text3,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.verified_outlined,
                          color: Color(0xFF43856D), size: 14),
                      const SizedBox(width: 3),
                      Text('${report.konfirmasi}',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text2,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 7),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.text3, size: 18),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReportTypeIcon extends StatelessWidget {
  final IconData icon;
  const _ReportTypeIcon({required this.icon});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.redLight,
        child: Icon(icon, color: AppColors.red, size: 23),
      );
}

String _reportAge(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);
  if (difference.inMinutes < 1) return 'Baru';
  if (difference.inHours < 1) return '${difference.inMinutes} mnt';
  if (difference.inDays < 1) return '${difference.inHours} jam';
  if (difference.inDays < 30) return '${difference.inDays} hari';
  return '${(difference.inDays / 30).floor()} bln';
}

class _SimpleInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SimpleInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, color: AppColors.text3, size: 19),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.text2, fontSize: 12))),
        ]),
      );
}

class _TopBar extends StatelessWidget {
  final VoidCallback? onAvatarTap;
  const _TopBar({this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/logo.png', width: 24, height: 24),
              const SizedBox(width: 6),
              Text('SafeZone',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
            ],
          ),
          GestureDetector(
            onTap: onAvatarTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                  color: AppColors.cream2, shape: BoxShape.circle),
              child: const Icon(Icons.account_circle_rounded,
                  color: AppColors.text2, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Halo, Stay Safe!',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2)),
          const SizedBox(height: 2),
          Text('Cek Sekitarmu',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.5,
                  height: 1.1)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(50)),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppColors.text3, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Cari lokasi...',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AlertCard extends StatefulWidget {
  const _AlertCard();

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, Color(0xFF183B5B), Color(0xFF0F766E)],
          ),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(58),
          ),
          shadows: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.22),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -26,
              child: AnimatedBuilder(
                animation: _floatCtrl,
                builder: (context, child) {
                  final v = _floatCtrl.value;
                  return Transform.translate(
                    offset: Offset(v * 8, v * 12),
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.10 + v * 0.05),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: -40,
              bottom: -30,
              child: AnimatedBuilder(
                animation: _floatCtrl,
                builder: (context, child) {
                  final rv = 1 - _floatCtrl.value;
                  return Transform.translate(
                    offset: Offset(rv * 15, -(rv * 10)),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F766E)
                            .withValues(alpha: 0.25 + rv * 0.1),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 6,
              bottom: 8,
              child: AnimatedBuilder(
                animation: _floatCtrl,
                child: const _IsoSafetyScene(),
                builder: (context, child) {
                  final v = _floatCtrl.value;
                  return Transform.translate(
                    offset: Offset(0, -(v * 6)),
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(0.04 * math.sin(v * math.pi)),
                      alignment: Alignment.center,
                      child: child,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 150, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zona kamu\nterpantau',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.05)),
                  const SizedBox(height: 8),
                  Text(
                      'Ada 12 laporan aktif. Tetap waspada dan panggil bantuan saat perlu.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.45)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _dialNumber(context, '112', 'Darurat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: const StadiumBorder(),
                      textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    child: const Text('SOS 112'),
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

class _IsoSafetyScene extends StatelessWidget {
  const _IsoSafetyScene();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 5,
            child: Container(
              width: 110,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 84,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateZ(-0.68)
                ..rotateX(0.98),
              alignment: Alignment.center,
              child: Container(
                width: 96,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF155E75), Color(0xFF0F3E52)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 48,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateZ(-0.68)
                ..rotateX(0.98),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(112, 92),
                painter: _IsoMapPainter(),
              ),
            ),
          ),
          Positioned(
            left: 52,
            top: 20,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-0.18),
              alignment: Alignment.center,
              child: const _ShieldTower(),
            ),
          ),
          const Positioned(
            left: 30,
            top: 66,
            child: _IsoPin(color: AppColors.green, height: 28),
          ),
          const Positioned(
            right: 20,
            top: 76,
            child: _IsoPin(color: AppColors.red, height: 34),
          ),
          const Positioned(
            right: 46,
            top: 47,
            child: _IsoPin(color: AppColors.yellow, height: 24),
          ),
        ],
      ),
    );
  }
}

class _ShieldTower extends StatelessWidget {
  const _ShieldTower();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Container(
            width: 48,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Container(
          width: 54,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFDDF7FF), Color(0xFFBEE7F4)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.36),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: 7,
                child: Container(
                  width: 18,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              const Center(
                child: Icon(Icons.shield_rounded,
                    color: AppColors.orange, size: 32),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IsoPin extends StatelessWidget {
  final Color color;
  final double height;

  const _IsoPin({required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: height + 14,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 6,
            child: Container(
              width: 3,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.38)],
                ),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 18,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: 1,
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

class _IsoMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mapPath = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.34)
      ..lineTo(size.width * 0.56, size.height)
      ..lineTo(0, size.height * 0.58)
      ..close();

    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB7F7EA), Color(0xFF4AB9C7), Color(0xFF17758E)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(mapPath, basePaint);

    final bevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.42);
    canvas.drawPath(mapPath, bevelPaint);

    final roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.36);
    final road1 = Path()
      ..moveTo(size.width * 0.18, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.38,
          size.width * 0.78, size.height * 0.42);
    final road2 = Path()
      ..moveTo(size.width * 0.43, size.height * 0.1)
      ..quadraticBezierTo(size.width * 0.52, size.height * 0.46,
          size.width * 0.48, size.height * 0.86);
    canvas.drawPath(road1, roadPaint);
    canvas.drawPath(road2, roadPaint);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.18);
    for (final x in [0.28, 0.62]) {
      canvas.drawLine(Offset(size.width * x, size.height * 0.18),
          Offset(size.width * (x - 0.18), size.height * 0.76), gridPaint);
    }
    for (final y in [0.3, 0.58]) {
      canvas.drawLine(Offset(size.width * 0.13, size.height * y),
          Offset(size.width * 0.86, size.height * (y + 0.03)), gridPaint);
    }

    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.42, size.height * 0.36),
          radius: size.width * 0.42));
    canvas.drawPath(mapPath, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(true),
          const SizedBox(width: 6),
          _dot(false),
          const SizedBox(width: 6),
          _dot(false),
        ],
      ),
    );
  }

  Widget _dot(bool active) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: active ? AppColors.red : AppColors.cream2,
          shape: BoxShape.circle,
        ),
      );
}

/// Helper widget that renders an AnimatedBuilder whose builder
/// returns a Positioned — this makes the Positioned a direct
/// child of the enclosing Stack, avoiding the Flutter assertion.
Future<void> _dialNumber(
    BuildContext context, String number, String name) async {
  final uri = Uri(scheme: 'tel', path: number);
  final canCall = await canLaunchUrl(uri);
  if (canCall) {
    await launchUrl(uri);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa menghubungi $name ($number)',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        ),
      );
    }
  }
}

// ── Category Section ──

class _CategorySection extends StatelessWidget {
  const _CategorySection();

  @override
  Widget build(BuildContext context) {
    final row1 = [
      _CatData(
        Icons.favorite_rounded,
        'Medis',
        '119',
        const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
        const Color(0xFFFFE0E0),
      ),
      _CatData(
        Icons.local_fire_department_rounded,
        'Pemadam',
        '113',
        const [Color(0xFFFF8C42), Color(0xFFFFB347)],
        const Color(0xFFFFF0E0),
      ),
      _CatData(
        Icons.local_police_rounded,
        'Polisi',
        '110',
        const [Color(0xFF5B8DEF), Color(0xFF7EA8F7)],
        const Color(0xFFE0EAFF),
      ),
      _CatData(
        Icons.emergency_rounded,
        'Darurat',
        '112',
        const [Color(0xFFFF4757), Color(0xFFFF6B81)],
        const Color(0xFFFFE0E4),
      ),
    ];
    final row2 = [
      _CatData(
        Icons.dangerous_rounded,
        'Begal',
        '110',
        const [Color(0xFFA855F7), Color(0xFFC084FC)],
        const Color(0xFFF0E4FF),
      ),
      _CatData(
        Icons.car_crash_rounded,
        'Kecelakaan',
        '112',
        const [Color(0xFF2DD4BF), Color(0xFF5EEAD4)],
        const Color(0xFFD5FFF8),
      ),
      _CatData(
        Icons.flood_rounded,
        'Bencana',
        '115',
        const [Color(0xFF38BDF8), Color(0xFF7DD3FC)],
        const Color(0xFFE0F4FF),
      ),
      _CatData(
        Icons.grid_view_rounded,
        'Lihat\nSemua',
        '',
        const [Color(0xFFA0AEC0), Color(0xFFCBD5E1)],
        const Color(0xFFF1F5F9),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Panggilan Darurat',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text('Atur',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Row 1
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      row1.map((cat) => _CategoryItem(data: cat)).toList(),
                ),
                const SizedBox(height: 20),
                // Row 2
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      row2.map((cat) => _CategoryItem(data: cat)).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final _CatData data;
  const _CategoryItem({required this.data});

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isMore = data.nomor.isEmpty;

    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        if (!isMore) {
          _dialNumber(context, data.nomor, data.label);
        }
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: data.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradientColors[0].withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(data.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 8),
              // Label
              Text(
                data.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatData {
  final IconData icon;
  final String label;
  final String nomor;
  final List<Color> gradientColors;
  final Color lightBg;
  _CatData(
      this.icon, this.label, this.nomor, this.gradientColors, this.lightBg);
}

// ── Laporan Terbaru ──

class _LaporanTerbaru extends StatelessWidget {
  const _LaporanTerbaru();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Laporan Terbaru',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
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
            child: Row(
              children: [
                Expanded(
                  child: _LCard(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7BAFC4), Color(0xFF4A7FA0)],
                    ),
                    icon: Icons.location_city_rounded,
                    badgeText: 'Aman',
                    badgeBg: Color(0xFFDCFCE7),
                    badgeFg: Color(0xFF15803D),
                    name: 'Jalan...',
                    time: '10 mnt lalu',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LCard(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D5016), Color(0xFF1A3310)],
                    ),
                    icon: Icons.park_rounded,
                    badgeText: 'Waspada',
                    badgeBg: Color(0xFFFEF3C7),
                    badgeFg: Color(0xFF92400E),
                    name: 'Taman Kota',
                    time: '25 mnt lalu',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String badgeText;
  final Color badgeBg;
  final Color badgeFg;
  final String name;
  final String time;

  const _LCard({
    required this.gradient,
    required this.icon,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeFg,
    required this.name,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(gradient: gradient),
            child: Center(
              child: Icon(icon, size: 44, color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: badgeBg, borderRadius: BorderRadius.circular(50)),
                  child: Text(badgeText,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeFg)),
                ),
                const SizedBox(height: 4),
                Text(name,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 1),
                Text(time,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
