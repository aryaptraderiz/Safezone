import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../widgets/auth_ui.dart';

class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandMark(),
                  SizedBox(
                      height: (constraints.maxHeight * .045).clamp(20.0, 34.0)),
                  Text(
                    'PERJALANAN LEBIH WASPADA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'Tetap waspada\ndi setiap perjalanan.',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      height: 1.16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Lihat informasi dari warga sekitar dan rencanakan perjalanan dengan lebih tenang.',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      height: 1.55,
                      color: AppColors.text2,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: (constraints.maxHeight * .15).clamp(108.0, 148.0),
                    child: const ExcludeSemantics(
                      child: CustomPaint(painter: _EntryRoutePainter()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cream2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.redLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.map_outlined,
                                color: AppColors.red, size: 25),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi keamanan sekitar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Peta, laporan warga, dan akses SOS dalam satu aplikasi.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                      label: 'Masuk',
                      onPressed: () => Navigator.pushNamed(context, '/login')),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                            color: AppColors.cream2, width: 1.4),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Buat akun baru'),
                    ),
                  ),
                  SizedBox(
                      height: (constraints.maxHeight * .025).clamp(12.0, 22.0)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _EntryRoutePainter extends CustomPainter {
  const _EntryRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadEdge = Paint()
      ..color = AppColors.cream2.withValues(alpha: 0.78)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadSurface = Paint()
      ..color = AppColors.bg.withValues(alpha: 0.94)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final blockPaint = Paint()..style = PaintingStyle.fill;
    final blockBorder = Paint()
      ..color = AppColors.cream3.withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void block(double x, double y, double w, double h, Color color) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * x, size.height * y, size.width * w, size.height * h),
        const Radius.circular(4),
      );
      blockPaint.color = color;
      canvas.drawRRect(rect, blockPaint);
      canvas.drawRRect(rect, blockBorder);
    }

    final parkPaint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .08, size.height * .14, size.width * .13,
            size.height * .22),
        const Radius.circular(8),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .78, size.height * .67, size.width * .14,
            size.height * .19),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    block(.30, .14, .12, .17, AppColors.cream);
    block(.47, .12, .10, .19, AppColors.redLighter);
    block(.63, .14, .11, .17, AppColors.cream);
    block(.28, .67, .13, .18, AppColors.redLighter);
    block(.47, .69, .12, .16, AppColors.cream);
    block(.64, .68, .10, .18, AppColors.cream);
    block(.05, .55, .16, .13, AppColors.cream);
    block(.80, .38, .13, .16, AppColors.redLighter);

    final streets = [
      Path()
        ..moveTo(size.width * .02, size.height * .46)
        ..lineTo(size.width * .34, size.height * .46)
        ..lineTo(size.width * .44, size.height * .34)
        ..lineTo(size.width * .73, size.height * .34)
        ..lineTo(size.width * .98, size.height * .52),
      Path()
        ..moveTo(size.width * .22, size.height * .04)
        ..lineTo(size.width * .22, size.height * .42)
        ..lineTo(size.width * .23, size.height * .62)
        ..lineTo(size.width * .11, size.height * .98),
      Path()
        ..moveTo(size.width * .76, size.height * .05)
        ..lineTo(size.width * .76, size.height * .37)
        ..lineTo(size.width * .71, size.height * .57)
        ..lineTo(size.width * .71, size.height * .96),
      Path()
        ..moveTo(size.width * .02, size.height * .63)
        ..lineTo(size.width * .4, size.height * .63)
        ..lineTo(size.width * .5, size.height * .54)
        ..lineTo(size.width * .97, size.height * .54),
    ];
    for (final path in streets) {
      canvas.drawPath(path, roadEdge);
      canvas.drawPath(path, roadSurface);
    }

    final route = Paint()
      ..color = AppColors.red.withValues(alpha: 0.82)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final routePath = Path()
      ..moveTo(size.width * .08, size.height * .77)
      ..lineTo(size.width * .31, size.height * .77)
      ..lineTo(size.width * .39, size.height * .64)
      ..cubicTo(size.width * .47, size.height * .51, size.width * .45,
          size.height * .4, size.width * .59, size.height * .4)
      ..lineTo(size.width * .83, size.height * .4);
    canvas.drawPath(routePath, route);

    final markerFill = Paint()..color = AppColors.red;
    final markerRing = Paint()
      ..color = AppColors.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final start = Offset(size.width * .08, size.height * .77);
    final destination = Offset(size.width * .83, size.height * .4);
    canvas.drawCircle(start, 5, markerFill);
    canvas.drawCircle(destination, 7, markerFill);
    canvas.drawCircle(destination, 10, markerRing);
  }

  @override
  bool shouldRepaint(covariant _EntryRoutePainter oldDelegate) => false;
}
