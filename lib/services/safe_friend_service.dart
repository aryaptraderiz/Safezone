import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class SafeFriendService {
  SafeFriendService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('safe_friend_codes');
  static CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('safe_friend_requests');
  static CollectionReference<Map<String, dynamic>> get _locations =>
      _db.collection('safe_friend_locations');

  static StreamSubscription<Position>? _positionSub;
  static StreamSubscription<User?>? _authSub;
  static String? _sharingUid;

  static String get uid {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('Silakan masuk kembali ke akunmu.');
    return userId;
  }

  static void _watchAuth() {
    _authSub ??= _auth.authStateChanges().listen((user) {
      if (user == null) unawaited(stopLocationSharing());
    });
  }

  static Future<String> getOrCreateCode() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Silakan masuk kembali ke akunmu.');
    final profile = _users.doc(user.uid);
    final profileSnapshot = await profile.get();
    final savedCode = profileSnapshot.data()?['safeFriendCode'];
    final displayName = (profileSnapshot.data()?['name'] as String?)?.trim();
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Pengguna SafeZone');

    if (savedCode is String && savedCode.isNotEmpty) {
      await _codes.doc(savedCode).set({
        'uid': user.uid,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return savedCode;
    }

    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code =
          List.generate(12, (_) => alphabet[random.nextInt(alphabet.length)])
              .join();
      final codeRef = _codes.doc(code);
      final reserved = await _db.runTransaction<bool>((transaction) async {
        final existing = await transaction.get(codeRef);
        if (existing.exists) return false;
        transaction.set(
            profile,
            {
              'safeFriendCode': code,
              'safeFriendCodeCreatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        transaction.set(codeRef, {
          'uid': user.uid,
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (reserved) return code;
    }
    throw StateError('QR belum bisa dibuat. Coba lagi sebentar.');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequests() =>
      _requests.where('recipientUid', isEqualTo: uid).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> outgoingRequests() =>
      _requests.where('requesterUid', isEqualTo: uid).snapshots();

  static Stream<DocumentSnapshot<Map<String, dynamic>>> locationOf(
          String friendUid) =>
      _locations.doc(friendUid).snapshots();

  static Future<Map<String, String>> lookupCode(String code) async {
    final snapshot = await _codes.doc(code).get();
    final data = snapshot.data();
    final friendUid = data?['uid'];
    if (!snapshot.exists || friendUid is! String || friendUid.isEmpty) {
      throw StateError('Kode QR tidak ditemukan. Minta teman membuat QR baru.');
    }
    return {
      'uid': friendUid,
      'name': (data?['name'] as String?)?.trim().isNotEmpty == true
          ? (data!['name'] as String).trim()
          : 'Pengguna SafeZone',
    };
  }

  static Future<String> sendRequest(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Silakan masuk kembali ke akunmu.');
    final friendData = await lookupCode(code);
    final friendUid = friendData['uid']!;
    if (friendUid == user.uid) throw StateError('Itu QR milik akunmu sendiri.');

    final outgoingRef = _requests.doc('${user.uid}_$friendUid');
    final incomingRef = _requests.doc('${friendUid}_${user.uid}');
    final snapshots = await Future.wait([outgoingRef.get(), incomingRef.get()]);
    final outgoing = snapshots[0];
    final incoming = snapshots[1];
    if (outgoing.data()?['status'] == 'accepted' ||
        incoming.data()?['status'] == 'accepted') {
      throw StateError('Kalian sudah terhubung sebagai Safe Friend.');
    }
    if (incoming.data()?['status'] == 'pending') {
      throw StateError(
          'Teman ini sudah mengirim permintaan. Cek permintaan masuk.');
    }
    final status = outgoing.data()?['status'];
    if (status == 'pending') {
      throw StateError('Permintaan ke teman ini sudah dikirim.');
    }

    final friendName = friendData['name']?.trim();
    final myName = user.displayName?.trim();
    final requestData = <String, dynamic>{
      'requesterUid': user.uid,
      'requesterName':
          myName?.isNotEmpty == true ? myName : 'Pengguna SafeZone',
      'recipientUid': friendUid,
      'recipientName':
          friendName?.isNotEmpty == true ? friendName : 'Pengguna SafeZone',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (outgoing.exists) {
      await outgoingRef.update({
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await outgoingRef.set(requestData);
    }
    return 'Permintaan Safe Friend terkirim ke ${friendName?.isNotEmpty == true ? friendName : 'temanmu'}.';
  }

  static Future<void> respondToRequest(
      String requestId, String newStatus) async {
    if (!{'accepted', 'rejected', 'cancelled', 'removed'}.contains(newStatus)) {
      throw ArgumentError.value(newStatus, 'newStatus');
    }
    await _requests.doc(requestId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> get sharingEnabled async {
    final snapshot = await _users.doc(uid).get();
    return snapshot.data()?['safeFriendSharingEnabled'] == true;
  }

  static Future<void> startLocationSharing() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Silakan masuk kembali ke akunmu.');
    _watchAuth();
    if (_sharingUid == user.uid && _positionSub != null) return;

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Aktifkan layanan lokasi perangkat terlebih dahulu.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Izin lokasi diperlukan untuk berbagi lokasi.');
    }

    final initialPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
    await _users.doc(user.uid).set({
      'safeFriendSharingEnabled': true,
      'safeFriendSharingUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      await _writeLocation(user.uid, initialPosition);
    } catch (_) {
      await _users.doc(user.uid).set({
        'safeFriendSharingEnabled': false,
        'safeFriendSharingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      rethrow;
    }

    await _positionSub?.cancel();
    _sharingUid = user.uid;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        timeLimit: Duration(seconds: 30),
      ),
    ).listen(
      (position) => unawaited(_writeLocation(user.uid, position).catchError(
          (Object error) =>
              debugPrint('Safe Friend location write failed: $error'))),
      onError: (Object error) =>
          debugPrint('Safe Friend location error: $error'),
    );
  }

  static Future<void> _writeLocation(String userId, Position position) async {
    await _locations.doc(userId).set({
      'uid': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'sharingEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> stopLocationSharing() async {
    final userId = _sharingUid ?? _auth.currentUser?.uid;
    await _positionSub?.cancel();
    _positionSub = null;
    _sharingUid = null;
    if (userId == null) return;
    try {
      await _users.doc(userId).set({
        'safeFriendSharingEnabled': false,
        'safeFriendSharingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _locations.doc(userId).delete();
    } catch (error) {
      debugPrint('Could not stop Safe Friend location sharing: $error');
    }
  }
}
