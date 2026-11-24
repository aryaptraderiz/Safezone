import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../app_colors.dart';
import '../services/auth_service.dart';
import '../services/laporan_service.dart';
import '../services/user_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileName;
  String _profilePhone = '';
  String? _profilePhotoUrl;
  bool _reportNotifications = true;
  bool _notificationSound = true;
  List<EmergencyContact> _contacts = const [];
  bool _loadingSettings = true;
  int _settingsLoadGeneration = 0;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _profileName = AuthService.currentUser?.displayName;
    _profilePhotoUrl = AuthService.currentUser?.photoURL;
    _authSubscription = AuthService.userStream.listen((user) {
      if (!mounted) return;
      if (user != null) {
        setState(() {
          _profileName = user.displayName;
          _profilePhotoUrl = user.photoURL;
        });
      }
      unawaited(_loadSettings());
    });
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _settingsLoadGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final generation = ++_settingsLoadGeneration;
    try {
      final results = await Future.wait<Object>([
        UserSettingsService.getReportNotificationsEnabled(),
        UserSettingsService.getNotificationSoundEnabled(),
        UserSettingsService.loadEmergencyContacts(),
      ]);
      if (!mounted || generation != _settingsLoadGeneration) return;
      setState(() {
        _reportNotifications = results[0] as bool;
        _notificationSound = results[1] as bool;
        _contacts = results[2] as List<EmergencyContact>;
        _loadingSettings = false;
      });

      if (AuthService.currentUser != null) {
        final phone = await AuthService.getProfilePhone().timeout(
          const Duration(seconds: 4),
          onTimeout: () => _profilePhone,
        );
        if (!mounted || generation != _settingsLoadGeneration) return;
        setState(() => _profilePhone = phone);
      }
    } catch (error) {
      debugPrint('Could not load settings: $error');
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _editProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: _profileName ?? user.displayName ?? '',
    );
    final phoneController = TextEditingController(text: _profilePhone);
    File? selectedPhoto;
    var saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.manage_accounts_outlined,
                    color: AppColors.red, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit profil',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Perbarui informasi akunmu',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: AppColors.text3)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EDE2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _ProfileAvatar(
                                photoUrl: _profilePhotoUrl,
                                localPhoto: selectedPhoto,
                                radius: 42,
                              ),
                              IconButton.filled(
                                tooltip: 'Ganti foto profil',
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final source =
                                            await showModalBottomSheet<
                                                ImageSource>(
                                          context: context,
                                          builder: (context) => SafeArea(
                                            child: Wrap(children: [
                                              ListTile(
                                                leading: const Icon(Icons
                                                    .photo_library_outlined),
                                                title: const Text(
                                                    'Pilih dari galeri'),
                                                onTap: () => Navigator.pop(
                                                    context,
                                                    ImageSource.gallery),
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons
                                                    .photo_camera_outlined),
                                                title: const Text('Ambil foto'),
                                                onTap: () => Navigator.pop(
                                                    context,
                                                    ImageSource.camera),
                                              ),
                                            ]),
                                          ),
                                        );
                                        if (source == null) return;
                                        final image =
                                            await ImagePicker().pickImage(
                                          source: source,
                                          imageQuality: 78,
                                          maxWidth: 1200,
                                        );
                                        if (image != null) {
                                          setDialogState(() =>
                                              selectedPhoto = File(image.path));
                                        }
                                      },
                                icon: const Icon(Icons.camera_alt_rounded,
                                    size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nameController.text.trim().isEmpty
                                ? 'Foto profil'
                                : nameController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(user.email ?? 'Akun SafeZone',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppColors.text3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ProfileTextField(
                      controller: nameController,
                      label: 'Nama lengkap',
                      icon: Icons.person_outline_rounded,
                      capitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nama wajib diisi.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    _ProfileTextField(
                      controller: phoneController,
                      label: 'Nomor telepon',
                      hint: 'Opsional',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!,
                          style: const TextStyle(color: AppColors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        var photoUrl = _profilePhotoUrl;
                        if (selectedPhoto != null) {
                          photoUrl =
                              await LaporanService.uploadFoto(selectedPhoto!);
                          if (photoUrl == null) {
                            throw StateError('Foto profil gagal diunggah.');
                          }
                        }
                        await AuthService.updateProfile(
                          name: nameController.text,
                          phone: phoneController.text,
                          photoUrl: selectedPhoto == null ? null : photoUrl,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = e.toString().contains('Foto profil')
                              ? 'Foto gagal diunggah. Coba pilih foto lain atau periksa koneksi.'
                              : 'Profil gagal disimpan. Periksa koneksi lalu coba lagi.';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final savedName = nameController.text.trim();
    final savedPhone = phoneController.text.trim();
    nameController.dispose();
    phoneController.dispose();

    if (saved == true && mounted) {
      setState(() {
        _profileName = savedName;
        _profilePhone = savedPhone;
        if (selectedPhoto != null) {
          _profilePhotoUrl = AuthService.currentUser?.photoURL ?? user.photoURL;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
    }
  }

  Future<void> _editNotifications() async {
    var reports = _reportNotifications;
    var sound = _notificationSound;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Notifikasi keamanan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Laporan keamanan'),
                subtitle: const Text('Notifikasi saat laporan baru dikirim.'),
                value: reports,
                onChanged: (value) => setDialogState(() => reports = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Suara notifikasi'),
                value: sound,
                onChanged: reports
                    ? (value) => setDialogState(() => sound = value)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await UserSettingsService.setReportNotificationsEnabled(reports);
    await UserSettingsService.setNotificationSoundEnabled(sound);
    if (mounted) {
      setState(() {
        _reportNotifications = reports;
        _notificationSound = sound;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan notifikasi disimpan.')),
      );
    }
  }

  Future<EmergencyContact?> _contactForm({EmergencyContact? initial}) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final phoneController = TextEditingController(text: initial?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(initial == null ? 'Tambah kontak' : 'Edit kontak',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ProfileTextField(
                controller: nameController,
                label: 'Nama kontak',
                icon: Icons.person_outline_rounded,
                capitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Masukkan nama kontak.'
                    : null,
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: phoneController,
                label: 'Nomor telepon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) => value == null ||
                        value.replaceAll(RegExp(r'\D'), '').length < 6
                    ? 'Masukkan nomor yang valid.'
                    : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                EmergencyContact(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    return result;
  }

  Future<void> _editEmergencyContacts() async {
    final contacts = List<EmergencyContact>.of(_contacts);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.cream3,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: AppColors.redLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.contact_emergency_outlined,
                        color: AppColors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kontak darurat',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('Maksimal 3 orang yang kamu percaya',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppColors.text3)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (contacts.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EDE2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.person_add_alt_1_outlined,
                                  color: AppColors.text3, size: 24),
                              const SizedBox(height: 7),
                              Text('Belum ada kontak tersimpan',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                            ],
                          ),
                        ),
                      ...contacts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final contact = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.only(left: 11, right: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cream),
                          ),
                          child: Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: AppColors.redLight,
                                  borderRadius: BorderRadius.circular(11)),
                              child: const Icon(Icons.person_outline_rounded,
                                  color: AppColors.red, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(contact.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  Text(contact.phone,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.text3)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit kontak',
                              onPressed: () async {
                                final updated =
                                    await _contactForm(initial: contact);
                                if (updated != null) {
                                  setSheetState(
                                      () => contacts[index] = updated);
                                }
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Hapus kontak',
                              onPressed: () =>
                                  setSheetState(() => contacts.removeAt(index)),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.red, size: 19),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (contacts.length < 3) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final contact = await _contactForm();
                      if (contact != null) {
                        setSheetState(() => contacts.add(contact));
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tambah kontak'),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    await UserSettingsService.saveEmergencyContacts(contacts);
    if (mounted) {
      setState(() => _contacts = List.unmodifiable(contacts));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontak darurat disimpan.')),
      );
    }
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
                        Image.asset('assets/logo.png', width: 24, height: 24),
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
                        _ProfileAvatar(
                          photoUrl: _profilePhotoUrl,
                          radius: 55,
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
                      _profileName ?? user?.displayName ?? 'SafeZone User',
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
                        subtitle: 'Nama dan nomor telepon',
                        onTap: _editProfile,
                      ),
                      const _Divider(),
                      _ProfileMenuItem(
                        icon: Icons.notifications_none_outlined,
                        title: 'Notifikasi Keamanan',
                        subtitle: _loadingSettings
                            ? 'Memuat pengaturan...'
                            : _reportNotifications
                                ? 'Laporan aktif${_notificationSound ? ' · Suara aktif' : ''}'
                                : 'Notifikasi laporan nonaktif',
                        onTap: _editNotifications,
                      ),
                      const _Divider(),
                      _ProfileMenuItem(
                        icon: Icons.contact_emergency_outlined,
                        title: 'Kontak Darurat',
                        subtitle: _loadingSettings
                            ? 'Memuat kontak...'
                            : '${_contacts.length} dari 3 kontak tersimpan',
                        onTap: _editEmergencyContacts,
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
  final String? subtitle;
  final bool isLogout;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isLogout = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.red, size: 22),
      ),
      title: Text(title,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isLogout ? AppColors.red : AppColors.text)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.text3)),
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

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final File? localPhoto;
  final double radius;

  const _ProfileAvatar({
    required this.photoUrl,
    this.localPhoto,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          color: AppColors.cream2,
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded,
              size: radius * 0.9, color: AppColors.text3),
        );

    final Widget image = localPhoto != null
        ? Image.file(localPhoto!,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
        : photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(photoUrl!,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
            : fallback();

    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.red, Color(0xFFFFC857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(child: SizedBox.expand(child: image)),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final String? Function(String?)? validator;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.red, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cream)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cream)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
      ),
    );
  }
}
