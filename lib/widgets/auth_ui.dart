import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

class AuthBackdrop extends StatelessWidget {
  final Widget child;

  const AuthBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: child),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label: 'Logo SafeZone',
          child: Image.asset(
            'assets/logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'SafeZone',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class AuthHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 148,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final emblemSize = constraints.maxWidth < 300 ? 88.0 : 102.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF71332C),
                        Color(0xFF9C4436),
                        Color(0xFFB8503D),
                      ],
                    ),
                  ),
                ),
                const Positioned.fill(
                    child: CustomPaint(painter: _AuthRoutePainter())),
                Positioned(
                  right: 14,
                  top: 0,
                  bottom: 0,
                  width: emblemSize,
                  child: Center(
                    child: Container(
                      width: emblemSize,
                      height: emblemSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .07),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .18)),
                      ),
                      child: Center(
                        child: Container(
                          width: emblemSize * .68,
                          height: emblemSize * .68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFFFFF8F1).withValues(alpha: .12),
                          ),
                          child: Icon(Icons.location_on_rounded,
                              color: const Color(0xFFFFE7D4),
                              size: emblemSize * .38),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: emblemSize + 28,
                  top: 17,
                  bottom: 17,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17.5,
                            height: 1.16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.35,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 7),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFFE9DC),
                          )),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthRoutePainter extends CustomPainter {
  const _AuthRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * .5, size.height * 1.05)
      ..cubicTo(size.width * .62, size.height * .76, size.width * .37,
          size.height * .58, size.width * .57, size.height * .31)
      ..cubicTo(size.width * .67, size.height * .15, size.width * .73,
          size.height * .07, size.width * .8, -12);
    canvas.drawPath(
        route,
        Paint()
          ..color = Colors.white.withValues(alpha: .10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    final marker = Paint()
      ..color = const Color(0xFFF3C48B).withValues(alpha: .8);
    canvas.drawCircle(Offset(size.width * .57, size.height * .31), 3, marker);
    canvas.drawCircle(Offset(size.width * .5, size.height * .9), 2, marker);
  }

  @override
  bool shouldRepaint(covariant _AuthRoutePainter oldDelegate) => false;
}

class AuthBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AuthBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Kembali',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        fixedSize: const Size(46, 46),
      ),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.onToggleObscure,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .65,
            color: AppColors.text2,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: AppColors.text,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.text3,
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 3, right: 2),
              child: Icon(icon, color: AppColors.text3, size: 19),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 50, minHeight: 58),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscureText
                        ? 'Tampilkan password'
                        : 'Sembunyikan password',
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.text3,
                      size: 19,
                    ),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide:
                  const BorderSide(color: Color(0xFFE9E0D5), width: 1.1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide:
                  const BorderSide(color: Color(0xFFE9E0D5), width: 1.1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: AppColors.red, width: 1.7),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outline;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: 9),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: outline
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.redMid, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: AppColors.red,
                      ),
                    )
                  : content,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: onPressed == null
                    ? AppColors.red.withValues(alpha: 0.55)
                    : AppColors.red,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: loading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: content,
              ),
            ),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;

  const AuthGoogleButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: Color(0xFF747775), width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.red),
            )
          else
            Semantics(
              image: true,
              label: 'Logo Google',
              child: Image.asset(
                'assets/google_g_logo.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            loading ? 'Menghubungkan...' : 'Lanjutkan dengan Google',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1F1F1F),
            ),
          ),
        ]),
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  final String? message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: GoogleFonts.inter(
                color: AppColors.red,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> requestPasswordToLinkGoogle(
  BuildContext context,
  String email,
) async {
  final controller = TextEditingController();
  var obscure = true;
  final password = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Hubungkan akun Google'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Masukkan password akun SafeZone $email untuk menyatukan UID.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Password akun SafeZone',
                suffixIcon: IconButton(
                  tooltip:
                      obscure ? 'Tampilkan password' : 'Sembunyikan password',
                  onPressed: () => setDialogState(() => obscure = !obscure),
                  icon: Icon(obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Hubungkan'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return password;
}
