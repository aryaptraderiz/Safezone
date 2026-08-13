import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: const [
            _TopBar(),
            _HeroSection(),
            _AlertCard(),
            _Dots(),
            _CategorySection(),
            _LaporanTerbaru(),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppColors.red, size: 22),
              const SizedBox(width: 6),
              Text('SafeZone',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
            ],
          ),
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
