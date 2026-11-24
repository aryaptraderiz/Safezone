import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../app_colors.dart';
import '../services/user_settings_service.dart';

class EmergencySosDialog extends StatefulWidget {
  final bool autoCallCountdown;

  const EmergencySosDialog({
    super.key,
    this.autoCallCountdown = true,
  });

  static Future<void> show(BuildContext context, {bool autoCountdown = true}) {
    HapticFeedback.heavyImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmergencySosDialog(autoCallCountdown: autoCountdown),
    );
  }

  @override
  State<EmergencySosDialog> createState() => _EmergencySosDialogState();
}

class _EmergencySosDialogState extends State<EmergencySosDialog> {
  int _countdown = 5;
  Timer? _countdownTimer;
  bool _countdownActive = true;
  bool _gettingLocation = false;
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();

    if (widget.autoCallCountdown) {
      _startCountdown();
    } else {
      _countdownActive = false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final list = await UserSettingsService.loadEmergencyContacts();
    if (mounted) setState(() => _contacts = list);
  }

  void _startCountdown() {
    _countdown = 5;
    _countdownActive = true;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdownActive = false);
        _callNumber('112');
      } else {
        HapticFeedback.mediumImpact();
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() => _countdownActive = false);
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      final mapsUrl =
          'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
      final message = Uri.encodeComponent(
          '🚨 PERINGATAN DARURAT SAFEZONE!\nSaya dalam bahaya dan butuh bantuan segera.\nLokasi saya saat ini: $mapsUrl');
      final waUri = Uri.parse('https://wa.me/?text=$message');
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        final smsUri = Uri.parse('sms:?body=$message');
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil lokasi GPS.')),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5DED6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BANTUAN DARURAT',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
                    const SizedBox(height: 3),
                    Text('Pilih bantuan yang kamu perlukan',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text)),
                  ]),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.text3, size: 21),
            )
          ]),
          const SizedBox(height: 12),

          // Countdown or Subtitle
          if (_countdownActive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1ED),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFF4D8D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_outlined,
                      color: AppColors.red, size: 18),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('Menghubungi 112 otomatis dalam',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2)),
                  ),
                  Text('$_countdown dtk',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.red)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelCountdown,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE7C8C1)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Batalkan panggilan otomatis',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text2,
                  ),
                ),
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('NOMOR DARURAT',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.text3)),
            ),
          ],
          const SizedBox(height: 10),

          // Quick Call Grid
          Row(
            children: [
              Expanded(
                child: _QuickCallBtn(
                  title: '112',
                  subtitle: 'Darurat Umum',
                  icon: Icons.emergency_rounded,
                  color: AppColors.red,
                  onTap: () => _callNumber('112'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickCallBtn(
                  title: '110',
                  subtitle: 'Polisi',
                  icon: Icons.local_police_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => _callNumber('110'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickCallBtn(
                  title: '119',
                  subtitle: 'Ambulans',
                  icon: Icons.medical_services_rounded,
                  color: const Color(0xFF059669),
                  onTap: () => _callNumber('119'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Share Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _gettingLocation ? null : _shareLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.text2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: const BorderSide(color: Color(0xFFE8E1D9))),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.red),
                    )
                  : const Icon(Icons.share_location_outlined,
                      size: 19, color: AppColors.red),
              label: Text(
                _gettingLocation
                    ? 'Mengambil GPS...'
                    : 'Kirim lokasi ke kerabat via WhatsApp / SMS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Emergency contacts (if any)
          if (_contacts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'KONTAK DARURAT TERSIMPAN',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: .8,
                  color: AppColors.text3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final c = _contacts[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFECE6DF))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            color: AppColors.text3, size: 20),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                c.phone,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_outlined,
                              color: AppColors.red, size: 19),
                          onPressed: () => _callNumber(c.phone),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickCallBtn extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickCallBtn({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFECE6DF)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 5),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: AppColors.text3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
