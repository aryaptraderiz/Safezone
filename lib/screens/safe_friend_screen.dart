import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_colors.dart';
import '../services/safe_friend_service.dart';
import 'map_screen.dart';
import 'scan_safe_friend_screen.dart';

class SafeFriendScreen extends StatefulWidget {
  const SafeFriendScreen({super.key});

  @override
  State<SafeFriendScreen> createState() => _SafeFriendScreenState();
}

class _SafeFriendScreenState extends State<SafeFriendScreen> {
  bool _sharing = false;
  bool _saving = false;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadSharingPreference();
  }

  Future<void> _loadSharingPreference() async {
    try {
      final enabled = await SafeFriendService.sharingEnabled;
      if (enabled) await SafeFriendService.startLocationSharing();
      if (!mounted) return;
      setState(() => _sharing = enabled);
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Pengaturan berbagi belum bisa dimuat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setSharing(bool enabled) async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      if (enabled) {
        await SafeFriendService.startLocationSharing();
      } else {
        await SafeFriendService.stopLocationSharing();
      }
      if (mounted) setState(() => _sharing = enabled);
    } catch (error) {
      if (mounted) {
        setState(
            () => _message = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE7E7E7),
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 20),
                Text('Tentang Safe Friend',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 8),
                Text(
                    'Pindai QR untuk mengirim permintaan. Lokasi hanya dibagikan setelah teman menerima dan kamu mengaktifkan Berbagi lokasi. Berbagi lokasi berjalan saat aplikasi digunakan.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, height: 1.55, color: AppColors.text2)),
              ]),
        ),
      ),
    );
  }

  Future<String> _getOrCreateFriendCode() async {
    return SafeFriendService.getOrCreateCode();
  }

  Future<void> _showMyQr() async {
    String code;
    try {
      code = await _getOrCreateFriendCode();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _message = 'QR belum bisa dibuat. Periksa koneksi dan coba lagi.');
      }
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
                child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE7E7E7),
                        borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 22),
            Text('QR Safe Friend',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECE8E3)),
              ),
              child: QrImageView(
                data: 'safezone://friend/$code',
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: Color(0xFF203C62)),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF203C62)),
              ),
            ),
            const SizedBox(height: 12),
            Text(code,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.text)),
            const SizedBox(height: 6),
            Text('Minta teman memindai kode ini untuk menambahkanmu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, height: 1.5, color: AppColors.text2)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mengerti')),
          ]),
        ),
      ),
    );
  }

  Future<void> _scanQr() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ScanSafeFriendScreen()),
    );
  }

  Future<void> _respond(String id, String status) async {
    try {
      await SafeFriendService.respondToRequest(id, status);
    } catch (error) {
      if (mounted) {
        setState(
            () => _message = error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Widget _requestAndFriendList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SafeFriendService.incomingRequests(),
      builder: (context, incomingSnapshot) {
        if (incomingSnapshot.hasError) {
          return _streamError(incomingSnapshot.error);
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SafeFriendService.outgoingRequests(),
          builder: (context, outgoingSnapshot) {
            if (outgoingSnapshot.hasError) {
              return _streamError(outgoingSnapshot.error);
            }
            if (!incomingSnapshot.hasData || !outgoingSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final incomingDocs = incomingSnapshot.data!.docs;
            final outgoingDocs = outgoingSnapshot.data!.docs;
            final incomingPending = incomingDocs
                .where((doc) => doc.data()['status'] == 'pending')
                .toList();
            final outgoingPending = outgoingDocs
                .where((doc) => doc.data()['status'] == 'pending')
                .toList();
            final acceptedByUid =
                <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final doc in [...incomingDocs, ...outgoingDocs]) {
              final data = doc.data();
              if (data['status'] != 'accepted') continue;
              final otherUid = data['requesterUid'] == SafeFriendService.uid
                  ? data['recipientUid'] as String
                  : data['requesterUid'] as String;
              acceptedByUid[otherUid] = doc;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Pindai QR teman'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.cream2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _SafeFriendSectionTitle(
                    title: 'Permintaan masuk', count: incomingPending.length),
                const SizedBox(height: 10),
                if (incomingPending.isEmpty)
                  const _SafeFriendEmptyState(
                      text: 'Belum ada permintaan pertemanan.')
                else
                  for (final doc in incomingPending)
                    _IncomingFriendRequest(
                      data: doc.data(),
                      onAccept: () => _respond(doc.id, 'accepted'),
                      onReject: () => _respond(doc.id, 'rejected'),
                    ),
                const SizedBox(height: 22),
                _SafeFriendSectionTitle(
                    title: 'Teman terhubung', count: acceptedByUid.length),
                const SizedBox(height: 10),
                if (acceptedByUid.isEmpty)
                  const _SafeFriendEmptyState(
                      text:
                          'Terima permintaan teman atau pindai QR untuk mulai terhubung.')
                else
                  for (final entry in acceptedByUid.entries)
                    _ConnectedFriendCard(
                      friendUid: entry.key,
                      request: entry.value.data(),
                      myUid: SafeFriendService.uid,
                      onRemove: () => _respond(entry.value.id, 'removed'),
                    ),
                if (outgoingPending.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _SafeFriendSectionTitle(
                      title: 'Menunggu konfirmasi',
                      count: outgoingPending.length),
                  const SizedBox(height: 10),
                  for (final doc in outgoingPending)
                    _OutgoingFriendRequest(data: doc.data()),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _streamError(Object? error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error is FirebaseException && error.code == 'permission-denied'
                ? 'Rules Firestore untuk Safe Friend perlu dipublikasikan.'
                : 'Daftar Safe Friend belum bisa dimuat. Periksa koneksi lalu coba lagi.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.text2, fontSize: 13, height: 1.5),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.text, size: 20)),
        title: Text('Safe Friend',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: _showInfo,
              icon: const Icon(Icons.help_rounded,
                  color: Color(0xFF1683E8), size: 25)),
          const SizedBox(width: 8)
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Row(children: [
            Expanded(
                child: InkWell(
                    onTap: _showMyQr,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(children: [
                          const Icon(Icons.qr_code_2_rounded,
                              color: Color(0xFFB7B9BE), size: 39),
                          const SizedBox(height: 8),
                          Text('QR Saya',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text2))
                        ])))),
            Expanded(
                child: Column(children: [
              Switch.adaptive(
                  value: _sharing,
                  onChanged: _saving || _loading ? null : _setSharing,
                  activeTrackColor: const Color(0xFF45B36B)),
              Text('Berbagi lokasi',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2)),
              Text(_sharing ? 'Aktif saat aplikasi digunakan' : 'Nonaktif',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: AppColors.text3)),
            ])),
          ]),
        ),
        if (_message != null)
          Container(
              width: double.infinity,
              color: const Color(0xFFFFF5F2),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(_message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.red))),
        Expanded(child: _requestAndFriendList()),
      ]),
    );
  }
}

class _SafeFriendSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SafeFriendSectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(title,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ),
        Text('$count',
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.text3,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]);
}

class _SafeFriendEmptyState extends StatelessWidget {
  final String text;

  const _SafeFriendEmptyState({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFECE8E3)),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.text3, fontSize: 12, height: 1.45)),
      );
}

class _IncomingFriendRequest extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingFriendRequest({
    required this.data,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['requesterName'] as String? ?? 'Pengguna SafeZone';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE8E3)),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFF2E7DA),
          child: Icon(Icons.person_outline_rounded, color: AppColors.text2),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Tolak',
          onPressed: onReject,
          icon: const Icon(Icons.close_rounded, color: AppColors.text3),
        ),
        FilledButton(
          onPressed: onAccept,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            padding: const EdgeInsets.symmetric(horizontal: 13),
          ),
          child: const Text('Terima'),
        ),
      ]),
    );
  }
}

class _OutgoingFriendRequest extends StatelessWidget {
  final Map<String, dynamic> data;

  const _OutgoingFriendRequest({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFECE8E3))),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, color: AppColors.text3, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(data['recipientName'] as String? ?? 'Pengguna SafeZone',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Text('Menunggu',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.text3, fontSize: 10)),
        ]),
      );
}

class _ConnectedFriendCard extends StatelessWidget {
  final String friendUid;
  final String myUid;
  final Map<String, dynamic> request;
  final VoidCallback onRemove;

  const _ConnectedFriendCard({
    required this.friendUid,
    required this.myUid,
    required this.request,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = request['requesterUid'] == myUid
        ? request['recipientName'] as String? ?? 'Pengguna SafeZone'
        : request['requesterName'] as String? ?? 'Pengguna SafeZone';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: SafeFriendService.locationOf(friendUid),
      builder: (context, snapshot) {
        final location = snapshot.data?.data();
        final sharing = location?['sharingEnabled'] == true;
        final lat = location?['latitude'];
        final lon = location?['longitude'];
        final updated = location?['updatedAt'];
        final updatedLabel =
            updated is Timestamp ? _timeAgo(updated.toDate()) : 'baru saja';
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE8E3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(
              radius: 21,
              backgroundColor: Color(0xFFE8F3EF),
              child: Icon(Icons.person_rounded, color: Color(0xFF43856D)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (sharing && lat is num && lon is num) ...[
                      Text('Lokasi aktif · diperbarui $updatedLabel',
                          style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF43856D),
                              fontSize: 10,
                              height: 1.45)),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MapScreen(
                              initialTarget:
                                  LatLng(lat.toDouble(), lon.toDouble()),
                              initialTargetLabel: name,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined, size: 15),
                        label: const Text('Lihat lokasi di peta'),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF43856D),
                            padding: EdgeInsets.zero,
                            textStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ] else
                      Text('Belum membagikan lokasi',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.text3, fontSize: 10)),
                  ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opsi teman',
              onSelected: (_) => onRemove(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'remove', child: Text('Hapus dari Safe Friend')),
              ],
            ),
          ]),
        );
      },
    );
  }
}

String _timeAgo(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inSeconds < 60) return 'beberapa detik lalu';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} menit lalu';
  if (elapsed.inHours < 24) return '${elapsed.inHours} jam lalu';
  return '${elapsed.inDays} hari lalu';
}
