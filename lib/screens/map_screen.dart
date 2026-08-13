import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedRute = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _MapArea(),
          Expanded(
            child: _MapBottom(
              selectedRute: _selectedRute,
              onRuteSelected: (i) => setState(() => _selectedRute = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        children: [
          // Grid background
          Positioned.fill(
            child: Container(
              color: AppColors.cream,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          // SVG-like map illustration
          Positioned.fill(
            child: CustomPaint(painter: _MapPainter()),
          ),
          // Start pin
          Positioned(
            top: 90,
            left: 80,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.red, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.red.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.navigation_rounded,
                  color: AppColors.red, size: 24),
            ),
          ),
          // End pin
          Positioned(
            top: 175,
            right: 65,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.red.withOpacity(0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ],
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
          // Top bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xECFFF8F1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded,
                              color: AppColors.red, size: 20),
                          const SizedBox(width: 6),
                          Text('SafeZone',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.red)),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xECFFF8F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_circle_rounded,
                          color: AppColors.text2, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cream2
      ..strokeWidth = 1;
    const step = 34.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Roads
    final roadPaint = Paint()
      ..color = const Color(0xFFD8C8B8)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(0, 110), Offset(size.width, 110), roadPaint);
    canvas.drawLine(
        const Offset(0, 220), Offset(size.width, 220), roadPaint);
    canvas.drawLine(
        const Offset(130, 0), const Offset(130, 330), roadPaint);
    canvas.drawLine(
        const Offset(260, 0), const Offset(260, 330), roadPaint);

    // Blocks
    final blockPaint = Paint()
      ..color = const Color(0xFFE8DCCe)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(20, 130, 90, 70), Radius.circular(8)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(150, 130, 90, 70), Radius.circular(8)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(20, 30, 90, 60), Radius.circular(8)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(150, 30, 90, 60), Radius.circular(8)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(280, 30, 80, 60), Radius.circular(8)),
        blockPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(280, 130, 80, 70), Radius.circular(8)),
        blockPaint);

    // Danger zone circles
    final zonePaint = Paint()
      ..color = AppColors.red.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(205, 155), 65, zonePaint);
    final zone2Paint = Paint()
      ..color = AppColors.red.withOpacity(0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(205, 155), 38, zone2Paint);

    // Dashed route
    final routePaint = Paint()
      ..color = AppColors.red.withOpacity(0.65)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawDashedPath(
        canvas,
        routePaint,
        [
          const Offset(105, 115),
          const Offset(160, 75),
          const Offset(215, 95),
          const Offset(270, 145),
          const Offset(325, 195),
        ],
        13,
        9);
  }

  void _drawDashedPath(Canvas canvas, Paint paint, List<Offset> points,
      double dashLen, double gapLen) {
    if (points.length < 2) return;
    double drawn = 0;
    bool drawing = true;
    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final d = (end - start).distance;
      double progress = 0;
      while (progress < d) {
        final segLen = drawing ? dashLen : gapLen;
        final remain = d - progress;
        final actual = segLen > remain ? remain : segLen;
        if (drawing) {
          final p1 = Offset.lerp(start, end, progress / d)!;
          final p2 = Offset.lerp(start, end, (progress + actual) / d)!;
          canvas.drawLine(p1, p2, paint);
        }
        progress += actual;
        drawn += actual;
        if (drawn >= segLen) {
          drawn = 0;
          drawing = !drawing;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MapBottom extends StatelessWidget {
  final int selectedRute;
  final ValueChanged<int> onRuteSelected;

  const _MapBottom(
      {required this.selectedRute, required this.onRuteSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, -4))
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        children: [
          Text('Mau ke mana?',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 12),
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
                  child: Text('Cari lokasi tujuan...',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Pilih Rute Aman',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 10),
          _RuteCard(
            selected: selectedRute == 0,
            onTap: () => onRuteSelected(0),
            iconBg: AppColors.greenBg,
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.green,
            name: 'Rute Utama',
            via: 'Via Jl. Sudirman • Lebih ramai',
            mins: '15',
          ),
          const SizedBox(height: 10),
          _RuteCard(
            selected: selectedRute == 1,
            onTap: () => onRuteSelected(1),
            iconBg: AppColors.cream,
            icon: Icons.directions_walk_rounded,
            iconColor: AppColors.text2,
            name: 'Rute Alternatif',
            via: 'Via Gg. Manggis • Sedikit gelap',
            mins: '12',
          ),
        ],
      ),
    );
  }
}

class _RuteCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String name;
  final String via;
  final String mins;

  const _RuteCard({
    required this.selected,
    required this.onTap,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.via,
    required this.mins,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : AppColors.cream2,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(via,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(mins,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                Text('mnt',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.text3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
