import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmPassCtrl.text;

    // Validasi
    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Semua field wajib diisi.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Password dan konfirmasi tidak cocok.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.register(name: name, email: email, password: pass);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e));
    } catch (e) {
      setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Glow top-left
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDE2B5).withOpacity(0.6),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Shield icon
                      Center(
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.red.withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 38),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Gabung SafeZone!',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      const SizedBox(height: 8),
                      Text('Biar kawasan kita makin aman\nbareng-bareng.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppColors.text2,
                              height: 1.5)),
                      const SizedBox(height: 28),

                      // Form card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 24,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error banner
                              if (_error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.redLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: AppColors.red, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!,
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                color: AppColors.red,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],

                              // Nama
                              _FL('Nama Lengkap'),
                              const SizedBox(height: 8),
                              _FField(
                                controller: _nameCtrl,
                                hint: 'Siapa nama kamu?',
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 18),

                              // Email
                              _FL('Email'),
                              const SizedBox(height: 8),
                              _FField(
                                controller: _emailCtrl,
                                hint: 'contoh@safezone.id',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 18),

                              // Password
                              _FL('Password'),
                              const SizedBox(height: 8),
                              _PassField(
                                controller: _passCtrl,
                                hint: 'Minimal 6 karakter',
                                obscure: _obscure,
                                onToggle: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              const SizedBox(height: 18),

                              // Konfirmasi Password
                              _FL('Konfirmasi Password'),
                              const SizedBox(height: 8),
                              _PassField(
                                controller: _confirmPassCtrl,
                                hint: 'Ulangi password',
                                obscure: _obscureConfirm,
                                onToggle: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                              const SizedBox(height: 24),

                              // Tombol daftar
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor:
                                        AppColors.red.withOpacity(0.3),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    disabledBackgroundColor:
                                        AppColors.red.withOpacity(0.5),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text('Daftar Sekarang',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Divider
                              Row(children: [
                                const Expanded(
                                    child: Divider(
                                        color: Color(0xFFF5EDE2),
                                        thickness: 1.2)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text('ATAU PAKE CARA LAIN',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text3,
                                          letterSpacing: 1.1)),
                                ),
                                const Expanded(
                                    child: Divider(
                                        color: Color(0xFFF5EDE2),
                                        thickness: 1.2)),
                              ]),
                              const SizedBox(height: 18),

                              // Social
                              Row(children: [
                                Expanded(
                                  child: _SBtn(
                                    icon: const Text('G',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF4285F4))),
                                    label: 'Google',
                                    onTap: () {},
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SBtn(
                                    icon: const Icon(Icons.apple,
                                        size: 20, color: Colors.black),
                                    label: 'Apple',
                                    onTap: () {},
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Link ke login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Udah punya akun? ',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, color: AppColors.text2)),
                          GestureDetector(
                            onTap: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                Navigator.of(context)
                                    .pushReplacementNamed('/login');
                              }
                            },
                            child: Text('Masuk di sini',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.red)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ──

class _FL extends StatelessWidget {
  final String text;
  const _FL(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text));
}

class _FField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _FField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.text3, size: 20),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: AppColors.text3.withOpacity(0.6)),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
      ),
    );
  }
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  const _PassField(
      {required this.controller,
      required this.hint,
      required this.obscure,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.text3, size: 20),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.text3,
              size: 20),
        ),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: AppColors.text3.withOpacity(0.6)),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
      ),
    );
  }
}

class _SBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _SBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDE0D0), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
