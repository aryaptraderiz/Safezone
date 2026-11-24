import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/auth_ui.dart';

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});
  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  void _finishLogin({bool needsVerification = false}) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        needsVerification ? '/verify-email' : '/home',
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.login(email: _email.text, password: _password.text);
      if (!mounted) return;
      _finishLogin(
        needsVerification:
            AuthService.needsEmailVerification(AuthService.currentUser),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Tidak bisa masuk sekarang. Periksa koneksi lalu coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthService.signInWithGoogle(
        requestExistingPassword: (email) =>
            requestPasswordToLinkGoogle(context, email),
      );
      if (result == null || !mounted) return;
      _finishLogin();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() => _error = message.contains('serverClientId') ||
              message.contains('clientConfigurationError')
          ? 'Google belum siap. Periksa provider Firebase dan SHA-1 aplikasi.'
          : 'Google Sign-In gagal. Coba lagi sebentar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Isi email untuk menerima link reset password.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link reset dikirim ke $email')));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) => AuthBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: AutofillGroup(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AuthBackButton(
                      onPressed: () => Navigator.of(context).maybePop()),
                  const AuthBrandMark(),
                ],
              ),
              const SizedBox(height: 20),
              const AuthHeroBanner(
                title: 'Selamat datang kembali',
                subtitle:
                    'Masuk untuk tetap terhubung dengan lingkungan yang aman.',
              ),
              const SizedBox(height: 24),
              AuthTextField(
                  controller: _email,
                  label: 'Alamat email',
                  hint: 'nama@email.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email
                  ],
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  }),
              const SizedBox(height: 18),
              AuthTextField(
                  controller: _password,
                  label: 'Password',
                  hint: 'Masukkan password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!_loading) _login();
                  },
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  }),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Lupa password?'))),
              AuthErrorBanner(message: _error),
              if (_error != null) const SizedBox(height: 12),
              AuthPrimaryButton(
                  label: 'Masuk',
                  icon: Icons.arrow_forward_rounded,
                  loading: _loading,
                  onPressed: _login),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(child: Divider(color: AppColors.cream2)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('atau masuk dengan',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.text3))),
                const Expanded(child: Divider(color: AppColors.cream2))
              ]),
              const SizedBox(height: 16),
              AuthGoogleButton(onPressed: _google, loading: _loading),
              const SizedBox(height: 26),
              Center(
                  child: Wrap(alignment: WrapAlignment.center, children: [
                Text('Belum punya akun? ',
                    style: GoogleFonts.inter(color: AppColors.text2)),
                GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text('Daftar',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, color: AppColors.red)))
              ])),
            ]),
          ),
        ),
      );
}
