import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_colors.dart';
import '../services/safe_friend_service.dart';

class ScanSafeFriendScreen extends StatefulWidget {
  const ScanSafeFriendScreen({super.key});

  @override
  State<ScanSafeFriendScreen> createState() => _ScanSafeFriendScreenState();
}

class _ScanSafeFriendScreenState extends State<ScanSafeFriendScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handlingCode = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractCode(String? rawValue) {
    if (rawValue == null) return null;
    final uri = Uri.tryParse(rawValue.trim());
    if (uri == null ||
        uri.scheme != 'safezone' ||
        uri.host != 'friend' ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final code = uri.pathSegments.single.toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{12}$').hasMatch(code)) return null;
    return code;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingCode) return;
    final value = capture.barcodes
        .map((barcode) => _extractCode(barcode.rawValue))
        .whereType<String>()
        .firstOrNull;
    if (value == null) {
      if (mounted) {
        setState(() => _error = 'QR bukan kode Safe Friend yang valid.');
      }
      return;
    }

    setState(() {
      _handlingCode = true;
      _error = null;
    });
    await _controller.stop();
    await _sendRequest(value);
  }

  Future<void> _sendRequest(String code) async {
    try {
      final friend = await SafeFriendService.lookupCode(code);
      if (friend['uid'] == SafeFriendService.uid) {
        _fail('Itu QR milik akunmu sendiri.');
        return;
      }
      final friendName = friend['name']!;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Tambah Safe Friend?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          content: Text('Kirim permintaan pertemanan kepada $friendName?',
              style: GoogleFonts.plusJakartaSans(height: 1.45)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Kirim permintaan')),
          ],
        ),
      );
      if (!mounted) return;
      if (accepted != true) {
        setState(() => _handlingCode = false);
        await _controller.start();
        return;
      }
      final result = await SafeFriendService.sendRequest(code);
      _finish(result);
    } on StateError catch (error) {
      _fail(error.message);
    } on FirebaseException catch (error) {
      _fail(error.code == 'permission-denied'
          ? 'Firebase belum mengizinkan pencarian QR atau pengiriman permintaan.'
          : 'Tidak bisa mengirim permintaan sekarang. Coba lagi.');
    } catch (_) {
      _fail('Tidak bisa memproses QR sekarang. Coba lagi.');
    }
  }

  void _finish(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _handlingCode = false;
      _error = message;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Pindai Safe Friend',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Ganti kamera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          )
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            final details = error.errorDetails?.message;
            final message = error.errorCode ==
                    MobileScannerErrorCode.permissionDenied
                ? 'Izin kamera belum diberikan. Izinkan kamera untuk SafeZone di Pengaturan.'
                : error.errorCode == MobileScannerErrorCode.unsupported
                    ? 'Kamera tidak tersedia di perangkat ini.'
                    : (details?.isNotEmpty == true
                        ? details!
                        : 'Kamera tidak dapat dibuka (${error.errorCode.name}).');
            return ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 14),
                      Text(message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white, fontSize: 13, height: 1.45)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await _controller.stop();
                            await _controller.start();
                          } catch (retryError) {
                            if (mounted) {
                              setState(() => _error = retryError.toString());
                            }
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          bottom: 56,
          child: Column(children: [
            if (_handlingCode)
              const CircularProgressIndicator(color: Colors.white)
            else
              Text('Arahkan kamera ke QR Safe Friend',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontSize: 12)),
              )
            ]
          ]),
        )
      ]),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
