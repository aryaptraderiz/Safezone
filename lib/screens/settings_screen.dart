import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
              ),

              // ── Profile Header ──
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF9A8D4), Color(0xFFFDE047)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF9A8D4).withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white),
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cream2,
                              ),
                              child: const Icon(Icons.account_circle_rounded,
                                  size: 80, color: AppColors.text3),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCD34D),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF7A5800), size: 13),
                                const SizedBox(width: 5),
                                Text('Trusted Reporter',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF7A5800))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Nama dari Firebase
                    Text(
                      user?.displayName ?? 'SafeZone User',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 6),
                    // Email dari Firebase
                    Text(
                      user?.email ?? '',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppColors.text3),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        'Penjaga komunitas SafeZone. Suka membantu & peduli sesama! ✨',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: AppColors.text2, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Growth Card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 110,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.red.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Text('GROWTH',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 1.1)),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.trending_up_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('1,240',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1)),
                                const SizedBox(width: 6),
                                Text('Points Earned',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Twin Cards ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5EDE2),
                            borderRadius: BorderRadius.circular(22)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined,
                                color: AppColors.text2, size: 22),
                            const SizedBox(height: 10),
                            Text('42',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text)),
                            Text('Reports Made',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text3)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5EDE2),
                            borderRadius: BorderRadius.circular(22)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.group_outlined,
                                color: AppColors.red, size: 22),
                            const SizedBox(height: 10),
                            Text('158',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text)),
                            Text('Buddies',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Actions Card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _ProfileMenuItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Ubah Profil',
                        onTap: () {},
                      ),
                      const _Divider(),
                      _ProfileMenuItem(
                        icon: Icons.notifications_none_outlined,
                        title: 'Notifikasi Keamanan',
                        onTap: () {},
                      ),
                      const _Divider(),
                      _ProfileMenuItem(
                        icon: Icons.contact_emergency_outlined,
                        title: 'Kontak Darurat',
                        onTap: () {},
                      ),
                      const _Divider(),
                      _ProfileMenuItem(
                        icon: Icons.logout_rounded,
                        title: 'Keluar',
                        isLogout: true,
                        onTap: () => _handleLogout(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isLogout;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.isLogout = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AppColors.redLight, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.red, size: 22),
      ),
      title: Text(title,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isLogout ? AppColors.red : AppColors.text)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: isLogout ? AppColors.red : AppColors.text3, size: 22),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 84, endIndent: 20, color: Color(0xFFF5EDE2));
  }
}
