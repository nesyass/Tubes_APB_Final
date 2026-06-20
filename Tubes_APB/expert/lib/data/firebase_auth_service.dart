import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'database_helper.dart';
import 'models.dart';

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    DatabaseHelper? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? DatabaseHelper();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final DatabaseHelper _database;
  static Future<void>? _googleSignInInit;

  String? get currentUserUid => _auth.currentUser?.uid;

  Future<void> _ensureGoogleSignInReady() {
    return _googleSignInInit ??= GoogleSignIn.instance.initialize();
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('Login gagal. Akun tidak ditemukan.');
      }

      return _loadUserProfile(firebaseUser);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageForAuthException(e));
    } on FirebaseException catch (_) {
      throw const AuthFailure('Profil user belum bisa dibaca dari Firestore.');
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInReady();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthFailure(
          'Login Google tidak didukung di perangkat ini.',
        );
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const AuthFailure(
            'Token Google tidak tersedia. Coba login ulang.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw const AuthFailure('Login Google gagal. Akun tidak ditemukan.');
      }

      return _loadUserProfile(firebaseUser);
    } on GoogleSignInException catch (e) {
      throw AuthFailure(_messageForGoogleException(e));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageForAuthException(e));
    } on FirebaseException catch (_) {
      throw const AuthFailure('Profil user belum bisa dibaca dari Firestore.');
    }
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure(
            'Registrasi gagal. Akun tidak berhasil dibuat.');
      }

      await firebaseUser.updateDisplayName(name);
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final localUser = await _database.upsertLocalUserProfile(
        firebaseUid: firebaseUser.uid,
        name: name,
        email: email,
        phone: phone,
      );
      await _auth.signOut();
      return localUser;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageForAuthException(e));
    } on FirebaseException catch (_) {
      throw const AuthFailure(
          'Akun dibuat, tapi profil Firestore gagal disimpan.');
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInReady();
      await GoogleSignIn.instance.signOut();
    } on GoogleSignInException {
      // Email/password users should still be able to sign out from Firebase.
    }
    await _auth.signOut();
  }

  Future<UserModel?> restoreSignedInUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _loadUserProfile(firebaseUser);
  }

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthFailure('Sesi login tidak aktif. Silakan login ulang.');
    }

    final normalizedName = name.trim();
    final normalizedPhone = phone.trim();
    if (normalizedName.isEmpty) {
      throw const AuthFailure('Nama tidak boleh kosong.');
    }

    try {
      await firebaseUser.updateDisplayName(normalizedName);
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'name': normalizedName,
        'email': firebaseUser.email ?? '',
        'phone': normalizedPhone,
        'role': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return _database.upsertLocalUserProfile(
        firebaseUid: firebaseUser.uid,
        name: normalizedName,
        email: firebaseUser.email ?? '',
        phone: normalizedPhone,
      );
    } on FirebaseException catch (_) {
      throw const AuthFailure('Profil gagal disimpan ke Firebase.');
    }
  }

  Future<UserModel> _loadUserProfile(User firebaseUser) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    final email = firebaseUser.email ?? (data?['email'] as String? ?? '');
    final name = data?['name'] as String? ??
        firebaseUser.displayName ??
        email.split('@').first;
    final phone = data?['phone'] as String? ?? '';

    if (!snapshot.exists) {
      await docRef.set({
        'uid': firebaseUser.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return _database.upsertLocalUserProfile(
      firebaseUid: firebaseUser.uid,
      name: name,
      email: email,
      phone: phone,
    );
  }

  String _messageForAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah. Coba lagi.';
      default:
        return 'Autentikasi gagal. Coba lagi.';
    }
  }

  String _messageForGoogleException(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Login Google dibatalkan.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Konfigurasi Google Sign-In belum valid. Cek SHA-1 dan google-services.json.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Provider Google Sign-In belum siap. Cek Firebase Console.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'UI login Google tidak tersedia di perangkat ini.';
      default:
        return 'Login Google gagal. Coba lagi.';
    }
  }
}
