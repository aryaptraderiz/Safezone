import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../app_colors.dart';
import '../models/saved_location_model.dart';
import '../services/saved_location_service.dart';
import 'location_picker_screen.dart';
import 'saved_location_setup_screen.dart';

/// Daftar lokasi tersimpan ala Google Maps: "Rumah" dan "Kantor" selalu
/// tampil sebagai slot tetap (dengan "Set location" kalau belum diatur,
/// atau alamat + "Edit" kalau sudah), plus lokasi custom lain yang pernah
/// disimpan lewat long-press di peta. Jadi user tidak perlu tau trik
/// long-press untuk mulai memakai fitur ini.
class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key});

  static const _fixedLabels = ['Rumah', 'Kantor'];
  static const _defaultCenter = LatLng(-6.200000, 106.816666);

  Future<void> _setLocation(
    BuildContext context,
    String label,
    SavedLocationModel? existing,
  ) async {
    final initialCenter = existing != null
        ? LatLng(existing.point.latitude, existing.point.longitude)
        : _defaultCenter;

    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => SavedLocationSetupScreen(
          title: label,
          initialCenter: initialCenter,
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    try {
      await SavedLocationService.upsertByLabel(
        label: label,
        address: picked.address,
        lat: picked.point.latitude,
        lng: picked.point.longitude,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lokasi "$label" tersimpan.',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan lokasi. Cek login dan koneksi.',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addCustom(BuildContext context) async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => const SavedLocationSetupScreen(
          title: 'lokasi baru',
          initialCenter: _defaultCenter,
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    final labelCtrl = TextEditingController();
    final label = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama lokasi',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Misal "Rumah Nenek"',
                  filled: true,
                  fillColor: AppColors.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final value = labelCtrl.text.trim();
                    if (value.isEmpty) return;
                    Navigator.of(ctx).pop(value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Simpan',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (label == null || !context.mounted) return;

    try {
      await SavedLocationService.save(
        label: label,
        address: picked.address,
        lat: picked.point.latitude,
        lng: picked.point.longitude,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan lokasi. Cek login dan koneksi.',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _iconFor(String label) {
    switch (label) {
      case 'Rumah':
        return Icons.home_rounded;
      case 'Kantor':
        return Icons.work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        titleSpacing: 0,
        title: Text('Lokasi tersimpan',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: StreamBuilder<List<SavedLocationModel>>(
        stream: SavedLocationService.streamAll(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final byLabel = <String, SavedLocationModel>{
            for (final l in all) l.label: l,
          };
          final customs =
              all.where((l) => !_fixedLabels.contains(l.label)).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final label in _fixedLabels)
                _SavedLocationTile(
                  icon: _iconFor(label),
                  label: label,
                  subtitle: byLabel[label]?.address,
                  onTap: () => _setLocation(context, label, byLabel[label]),
                ),
              const Divider(height: 24),
              for (final loc in customs)
                _SavedLocationTile(
                  icon: _iconFor(loc.label),
                  label: loc.label,
                  subtitle: loc.address,
                  onTap: () => _setLocation(context, loc.label, loc),
                  onDelete: loc.id == null
                      ? null
                      : () => SavedLocationService.delete(loc.id!),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton.icon(
                  onPressed: () => _addCustom(context),
                  icon: const Icon(Icons.add_rounded, color: AppColors.red),
                  label: Text('Tambah lokasi lain',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, color: AppColors.red)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SavedLocationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SavedLocationTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = subtitle != null && subtitle!.isNotEmpty;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration:
            const BoxDecoration(color: AppColors.cream, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.red, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text)),
      subtitle: isSet
          ? Text(subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.text2))
          : Text('Belum diatur',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.text3)),
      trailing: onDelete != null
          ? IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.text3),
            )
          : Text(isSet ? 'Edit' : 'Set location',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF07869A))),
      onTap: onTap,
    );
  }
}
