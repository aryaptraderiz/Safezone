import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // Stream user state
  static Stream<User?> get userStream => _auth.authStateChanges();

  // Current user
  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;

  // LOGIN dengan email & password
  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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

    // Update display name
    await cred.user?.updateDisplayName(name.trim());

    // Simpan profil ke Firestore /users/{uid}
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'name': name.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  // LOGOUT
  static Future<void> logout() async {
    await _auth.signOut();
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
      default:
        return 'Terjadi kesalahan: ${e.message}';
    }
  }
}
