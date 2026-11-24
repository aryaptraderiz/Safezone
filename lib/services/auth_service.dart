import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AuthService {
  static const _sessionLifetime = Duration(days: 7);
  static const _lastActivePrefix = 'auth_last_active_';

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Stream user state
  static Stream<User?> get userStream => _auth.userChanges();

  // Current user
  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;

  static Future<User?>? _inFlightRestore;

  /// Restores the persisted Firebase Auth session across app restarts.
  /// If [currentUser] is already in memory, returns immediately.
  /// Otherwise, waits for Firebase to read stored credentials from disk.
  static Future<User?> restoreSession() {
    final current = _auth.currentUser;
    if (current != null) return Future.value(current);

    if (_inFlightRestore != null) return _inFlightRestore!;

    _inFlightRestore = _performRestoreSession().whenComplete(() {
      _inFlightRestore = null;
    });

    return _inFlightRestore!;
  }

  static Future<User?> _performRestoreSession() async {
    if (_auth.currentUser != null) return _auth.currentUser;

    try {
      // Firebase emits its persisted initial state (user or null). Waiting for
      // a non-null event can incorrectly time out on slower physical devices.
      final initialUser = await _auth.authStateChanges().first.timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException(
              'Firebase belum mengembalikan status autentikasi awal.',
            ),
          );
      if (initialUser != null) {
        debugPrint('Firebase session restore: user restored');
        return initialUser;
      }
      debugPrint('Firebase session restore: no user');
      return null;
    } catch (error) {
      debugPrint('Could not restore initial Firebase auth state: $error');
      final current = _auth.currentUser;
      if (current != null) return current;
      rethrow;
    }
  }

  static Future<User?> waitForInitialAuthState() => restoreSession();

  /// Keeps native Firebase sessions for up to seven days of inactivity.
  /// Firebase itself persists native sessions; this only applies the app's
  /// requested inactivity limit on top of that behavior.
  static Future<User?> validateAndRefreshSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_lastActivePrefix${user.uid}';
      final rawLastActive = prefs.getString(key);
      final lastActive = rawLastActive == null
          ? null
          : DateTime.tryParse(rawLastActive)?.toUtc();
      final now = DateTime.now().toUtc();

      if (lastActive != null && now.difference(lastActive) > _sessionLifetime) {
        await prefs.remove(key);
        if (_auth.currentUser?.uid == user.uid) await _auth.signOut();
        debugPrint('Firebase session expired after inactivity');
        return null;
      }

      await prefs.setString(key, now.toIso8601String());
    } catch (error) {
      // Keep the Firebase session if local activity storage is unavailable.
      debugPrint('Could not validate local session age: $error');
    }
    return user;
  }

  static Future<void> refreshSessionActivity() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_lastActivePrefix${user.uid}',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error) {
      debugPrint('Could not refresh local session activity: $error');
    }
  }

  // LOGIN dengan email & password
  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    debugPrint(
        'Firebase sign-in completed: ${credential.user != null && _auth.currentUser != null ? 'user available' : 'no current user'}');
    await refreshSessionActivity();
    return credential;
  }

  static Future<UserCredential?> signInWithGoogle({
    Future<String?> Function(String email)? requestExistingPassword,
  }) async {
    final googleSignIn = GoogleSignIn();
    // Clear Google's cached account selection so the account chooser appears.
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    UserCredential result;
    try {
      result = await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'account-exists-with-different-credential' ||
          error.email == null ||
          requestExistingPassword == null) {
        rethrow;
      }
      final password = await requestExistingPassword(error.email!);
      if (password == null || password.isEmpty) return null;
      final existing = await _auth.signInWithEmailAndPassword(
        email: error.email!,
        password: password,
      );
      final user = existing.user;
      if (user == null) throw StateError('Akun SafeZone tidak ditemukan.');
      result = await user.linkWithCredential(credential);
    }
    await refreshSessionActivity();

    final user = result.user;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        debugPrint('Could not save Google profile: $error');
      }
    }
    return result;
  }

  // REGISTER email & password + simpan profil ke Firestore
  static Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await refreshSessionActivity();

    // Update display name
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.sendEmailVerification();

    // Simpan profil ke Firestore /users/{uid}
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'name': name.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  static bool needsEmailVerification(User? user) {
    if (user == null || user.emailVerified) return false;
    final providers = user.providerData.map((item) => item.providerId);
    return providers.contains(EmailAuthProvider.PROVIDER_ID);
  }

  static Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sesi pendaftaran tidak ditemukan.');
    await user.sendEmailVerification();
  }

  static Future<bool> reloadEmailVerification() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // LOGOUT
  static Future<void> logout() async {
    debugPrint('Firebase sign-out requested by user');
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_lastActivePrefix$uid');
      } catch (error) {
        debugPrint('Could not clear local session activity: $error');
      }
    }
    try {
      await GoogleSignIn().signOut();
    } catch (error) {
      debugPrint('Could not clear Google Sign-In selection: $error');
    }
    await _auth.signOut();
  }

  static Future<void> updateProfile({
    required String name,
    required String phone,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sesi login sudah berakhir.');

    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    await user.updateDisplayName(cleanName);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': cleanName,
      'phone': cleanPhone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'email': user.email,
    }, SetOptions(merge: true));
    await user.reload();
  }

  static Future<String> getProfilePhone() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data()?['phone']?.toString() ?? '';
    } catch (error) {
      debugPrint('Could not load profile phone: $error');
      return '';
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Terjemahkan Firebase error ke pesan Indonesia
  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan. Coba daftar dulu ya!';
      case 'wrong-password':
        return 'Password salah. Coba lagi!';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar. Coba login!';
      case 'weak-password':
        return 'Password terlalu lemah. Minimal 6 karakter.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'operation-not-allowed':
        return 'Google Sign-In belum diaktifkan di Firebase Authentication.';
      default:
        return 'Terjadi kesalahan: ${e.message}';
    }
  }
}
