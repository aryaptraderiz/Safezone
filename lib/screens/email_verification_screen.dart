import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/auth_ui.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _sending = false;
  bool _checking = false;
  String? _message;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await AuthService.resendEmailVerification();
      if (mounted)
        setState(() => _message =
            'Tautan verifikasi dikirim ulang. Cek inbox atau folder spam.');
    } catch (_) {
      if (mounted)
        setState(() => _message =
            'Belum bisa mengirim email. Periksa koneksi dan coba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final verified = await AuthService.reloadEmailVerification();
      if (!mounted) return;
      if (verified) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        setState(() => _message =
            'Email belum terverifikasi. Buka tautan di email dulu, lalu cek lagi.');
      }
    } catch (_) {
      if (mounted)
        setState(() => _message =
            'Status belum bisa diperiksa. Coba lagi saat internet stabil.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentUser?.email ?? 'email pendaftaranmu';
    return AuthBackdrop(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AuthBackButton(onPressed: () => Navigator.maybePop(context)),
              const Spacer(),
              Center(
                  child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                          color: AppColors.redLight, shape: BoxShape.circle),
                      child: const Icon(Icons.mark_email_read_outlined,
                          color: AppColors.red, size: 48))),
              const SizedBox(height: 28),
              Text('Cek emailmu',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 12),
              Text(
                  'Kami mengirim tautan verifikasi ke $email. Buka tautan tersebut untuk mengaktifkan akun SafeZone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, height: 1.6, color: AppColors.text2)),
              const SizedBox(height: 24),
              if (_message != null) ...[
                Text(_message!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: AppColors.text2)),
                const SizedBox(height: 14)
              ],
              AuthPrimaryButton(
                  label: 'Saya sudah verifikasi',
                  icon: Icons.verified_outlined,
                  loading: _checking,
                  onPressed: _checking ? null : _check),
              const SizedBox(height: 12),
              AuthPrimaryButton(
                  label: 'Kirim ulang tautan',
                  outline: true,
                  loading: _sending,
                  onPressed: _sending ? null : _resend),
              const Spacer(),
            ])));
  }
}
