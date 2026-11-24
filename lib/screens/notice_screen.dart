import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  static const _tips = <_SafetyTip>[
    _SafetyTip(
      icon: Icons.edit_location_alt_outlined,
      title: 'Buat laporan yang mudah ditindaklanjuti',
      description:
          'Sertakan waktu, lokasi yang jelas, dan kronologi singkat. Tambahkan foto atau video hanya jika aman untuk mengambilnya.',
      color: Color(0xFF3978D5),
    ),
    _SafetyTip(
      icon: Icons.location_on_outlined,
      title: 'Bagikan lokasi dengan bijak',
      description:
          'Periksa siapa yang dapat melihat lokasimu. Bagikan hanya kepada orang tepercaya dan matikan berbagi saat sudah tidak diperlukan.',
      color: Color(0xFF43856D),
    ),
    _SafetyTip(
      icon: Icons.emergency_outlined,
      title: 'Saat membutuhkan bantuan segera',
      description:
          'Gunakan tombol SOS di tengah navigasi untuk membuka pilihan bantuan darurat. Utamakan keselamatan diri dan jangan mendekati bahaya.',
      color: AppColors.red,
    ),
    _SafetyTip(
      icon: Icons.verified_user_outlined,
      title: 'Jaga privasi warga',
      description:
          'Hindari menyebarkan nomor telepon, wajah, atau identitas orang dalam laporan di luar SafeZone.',
      color: Color(0xFF8058B8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
        ),
        title: Text('Notice',
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF253F5B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.campaign_outlined,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Info & tips keselamatan',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Panduan singkat saat menggunakan SafeZone',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: .78),
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('PENGINGAT',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text3,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
          const SizedBox(height: 10),
          for (final tip in _tips) ...[
            _TipCard(tip: tip),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SafetyTip {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _SafetyTip({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _TipCard extends StatelessWidget {
  final _SafetyTip tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.cream2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tip.color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(tip.icon, color: tip.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title,
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(tip.description,
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.text2, fontSize: 11, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
