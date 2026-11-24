import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/auth_ui.dart';

class AuthRegisterScreen extends StatefulWidget {
  const AuthRegisterScreen({super.key});
  @override
  State<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends State<AuthRegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 0;
  bool _agreed = false;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
        setState(() => _error = 'Nama dan email perlu diisi.');
        return;
      }
      if (!_email.text.trim().contains('@')) {
        setState(() => _error = 'Periksa kembali format email.');
        return;
      }
      if (!_agreed) {
        setState(() =>
            _error = 'Setujui syarat dan kebijakan privasi untuk lanjut.');
        return;
      }
      setState(() {
        _step = 1;
        _error = null;
      });
    } else {
      _register();
    }
  }

  Future<void> _register() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password belum cocok.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.register(
          name: _name.text, email: _email.text, password: _password.text);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/verify-email', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().contains('network')
            ? 'Tidak ada koneksi. Coba lagi.'
            : 'Pendaftaran gagal disimpan. Coba lagi.');
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
              requestPasswordToLinkGoogle(context, email));
      if (result != null && mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Google Sign-In gagal. Periksa konfigurasi Firebase.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: AutofillGroup(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                AuthBackButton(
                    onPressed: () => _step == 0
                        ? Navigator.maybePop(context)
                        : setState(() {
                            _step = 0;
                            _error = null;
                          })),
                const AuthBrandMark()
              ]),
              const SizedBox(height: 24),
              Text('${_step + 1}/2',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _step == 1 ? AppColors.red : AppColors.cream2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              AuthHeroBanner(
                title: _step == 0 ? 'Buat akun SafeZone' : 'Amankan akunmu',
                subtitle: _step == 0
                    ? 'Daftar dengan email yang bisa kamu akses.'
                    : 'Gunakan password yang kuat dan mudah kamu ingat.',
              ),
              const SizedBox(height: 24),
              if (_step == 0) ...[
                AuthTextField(
                    controller: _name,
                    label: 'Nama lengkap',
                    hint: 'Nama yang dikenal warga',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    }),
                const SizedBox(height: 18),
                AuthTextField(
                    controller: _email,
                    label: 'Alamat email',
                    hint: 'nama@email.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    }),
                const SizedBox(height: 18),
                CheckboxListTile(
                    value: _agreed,
                    onChanged: (value) => setState(() {
                          _agreed = value ?? false;
                          _error = null;
                        }),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.red,
                    title: Text(
                        'Saya menyetujui syarat penggunaan dan kebijakan privasi SafeZone.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.text2))),
              ] else ...[
                AuthTextField(
                    controller: _password,
                    label: 'Password',
                    hint: 'Minimal 6 karakter',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    }),
                const SizedBox(height: 18),
                AuthTextField(
                    controller: _confirm,
                    label: 'Konfirmasi password',
                    hint: 'Ulangi password',
                    icon: Icons.lock_reset_rounded,
                    obscureText: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) {
                      if (!_loading) _register();
                    },
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    }),
                const SizedBox(height: 14),
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cream2)),
                    child: Row(children: [
                      const Icon(Icons.mark_email_read_outlined,
                          color: AppColors.red),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Setelah daftar, cek inbox ${_email.text} untuk tautan verifikasi.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.text2)))
                    ])),
              ],
              const SizedBox(height: 14),
              AuthErrorBanner(message: _error),
              if (_error != null) const SizedBox(height: 12),
              AuthPrimaryButton(
                  label: _step == 0 ? 'Lanjutkan' : 'Buat akun',
                  icon: Icons.arrow_forward_rounded,
                  loading: _loading,
                  onPressed: _loading ? null : _next),
              const SizedBox(height: 20),
              if (_step == 0) ...[
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.cream2)),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau daftar dengan',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.text3))),
                  const Expanded(child: Divider(color: AppColors.cream2))
                ]),
                const SizedBox(height: 14),
                AuthGoogleButton(onPressed: _google, loading: _loading),
              ],
              const SizedBox(height: 24),
              Center(
                  child: Wrap(alignment: WrapAlignment.center, children: [
                Text('Sudah punya akun? ',
                    style: GoogleFonts.inter(color: AppColors.text2)),
                GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: Text('Masuk',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, color: AppColors.red)))
              ])),
            ]),
          ),
        ),
      );
}
