import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  // Lazy — Windows'ta Firebase init olmadan erişilmez
  FirebaseAuth? _authInstance;
  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;

  GoogleSignIn? _googleInstance;
  GoogleSignIn get _google => _googleInstance ??= GoogleSignIn(
    serverClientId:
        '392545068869-4na2tjkrpeset7k9gcl4ge2bub2jfnfh.apps.googleusercontent.com',
  );

  FirebaseFirestore? _dbInstance;
  FirebaseFirestore get _db => _dbInstance ??= FirebaseFirestore.instance;

  bool get _isMobile => !Platform.isWindows && !Platform.isLinux;

  Stream<User?> get userStream =>
      _isMobile ? _auth.authStateChanges() : const Stream.empty();
  User? get currentUser => _isMobile ? _auth.currentUser : null;
  bool get isLoggedIn => _isMobile && currentUser != null;

  // ── GOOGLE GİRİŞ ─────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    if (Platform.isWindows) {
      return AuthResult.success(
        user: null,
        isNewUser: false,
        onboardingComplete: false,
      );
    }
    try {
      await _google.signOut();
      final googleUser = await _google.signIn();
      if (googleUser == null) return AuthResult.cancelled();

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final isNew = userCred.additionalUserInfo?.isNewUser ?? false;

      if (!isNew) {
        final onboardingDone = await _checkOnboardingComplete(
          userCred.user!.uid,
        );
        return AuthResult.success(
          user: userCred.user!,
          isNewUser: false,
          onboardingComplete: onboardingDone,
        );
      } else {
        await _createUserDocument(userCred.user!, isGoogle: true);
        return AuthResult.success(
          user: userCred.user!,
          isNewUser: true,
          onboardingComplete: false,
        );
      }
    } on PlatformException catch (e) {
      return AuthResult.error(
        'Kod: ${e.code} | Mesaj: ${e.message} | Detay: ${e.details}',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error('Firebase: ${e.code} - ${e.message}');
    } catch (e) {
      return AuthResult.error('Hata: ${e.runtimeType} - ${e.toString()}');
    }
  }

  // ── APPLE GİRİŞ ──────────────────────────────────
  Future<AuthResult> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return AuthResult.error('Apple girişi bu platformda desteklenmiyor.');
    }
    
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential firebaseCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCred = await _auth.signInWithCredential(firebaseCredential);
      final isNew = userCred.additionalUserInfo?.isNewUser ?? false;

      if (!isNew) {
        final onboardingDone = await _checkOnboardingComplete(
          userCred.user!.uid,
        );
        return AuthResult.success(
          user: userCred.user!,
          isNewUser: false,
          onboardingComplete: onboardingDone,
        );
      } else {
        await _createUserDocument(userCred.user!);
        return AuthResult.success(
          user: userCred.user!,
          isNewUser: true,
          onboardingComplete: false,
        );
      }
    } on PlatformException catch (e) {
      return AuthResult.error(
        'Kod: ${e.code} | Mesaj: ${e.message} | Detay: ${e.details}',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error('Firebase: ${e.code} - ${e.message}');
    } catch (e) {
      return AuthResult.error('Hata: ${e.runtimeType} - ${e.toString()}');
    }
  }

  // ── EMAIL KAYIT ───────────────────────────────────
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (Platform.isWindows) {
      return AuthResult.success(
        user: null,
        isNewUser: true,
        onboardingComplete: false,
      );
    }
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _createUserDocument(userCred.user!);
      return AuthResult.success(
        user: userCred.user!,
        isNewUser: true,
        onboardingComplete: false,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    }
  }

  // ── EMAIL GİRİŞ ───────────────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (Platform.isWindows) {
      return AuthResult.success(
        user: null,
        isNewUser: false,
        onboardingComplete: false,
      );
    }
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final onboardingDone = await _checkOnboardingComplete(userCred.user!.uid);
      return AuthResult.success(
        user: userCred.user!,
        isNewUser: false,
        onboardingComplete: onboardingDone,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    }
  }

  // ── ÇIKIŞ ─────────────────────────────────────────
  Future<void> signOut() async {
    if (Platform.isWindows) return;
    await _google.signOut();
    await _auth.signOut();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_done');
  }

  // ── HESAP SİL ─────────────────────────────────────
  Future<AuthResult> deleteAccount() async {
    if (Platform.isWindows) {
      return AuthResult.error('Bu platformda desteklenmiyor.');
    }
    final user = currentUser;
    if (user == null) return AuthResult.error('Kullanıcı bulunamadı.');
    try {
      final uid = user.uid;
      // Önce Firestore verilerini sil, ardından hesabı sil.
      // Firestore kuralları auth gerektirdiği için auth silinmeden yapılmalı.
      await _deleteFirestoreData(uid);
      await user.delete();
      return AuthResult.success(
        user: null,
        isNewUser: false,
        onboardingComplete: false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AuthResult.error('requires-recent-login');
      }
      return AuthResult.error(_firebaseErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Hata: ${e.toString()}');
    }
  }

  Future<AuthResult> reauthenticateWithEmail({required String password}) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      return AuthResult.error('Kullanıcı bulunamadı.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return AuthResult.success(
        user: user,
        isNewUser: false,
        onboardingComplete: false,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    }
  }

  Future<AuthResult> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) return AuthResult.error('Kullanıcı bulunamadı.');
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return AuthResult.cancelled();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return AuthResult.success(
        user: user,
        isNewUser: false,
        onboardingComplete: false,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    }
  }

  Future<void> _deleteFirestoreData(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    const subcollections = [
      'food_entries',
      'water_logs',
      'step_logs',
      'streaks',
      'achievements',
      'coach_messages',
      'onboarding_answers',
      'fasting',
      'fasting_history',
      'weight_history',
      'wellness_logs',
      'profiles',
      'logs',
      'coach',
      'coach_sessions',
      'feedbacks',
      'crashes',
    ];
    for (final sub in subcollections) {
      try {
        final snapshot = await userRef.collection(sub).get();
        for (final doc in snapshot.docs) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }
    try {
      await userRef.delete();
    } catch (_) {}

    // Top-level devices/uid document
    try {
      await _db.collection('devices').doc(uid).delete();
    } catch (_) {}
  }

  // ── ŞİFRE SIFIRLAMA ───────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(
        user: null,
        isNewUser: false,
        onboardingComplete: false,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_firebaseErrorMessage(e.code));
    }
  }

  // ── FIRESTORE YARDIMCI FONKSİYONLAR ──────────────

  Future<void> _createUserDocument(User user, {bool isGoogle = false}) async {
    await _db.collection('users').doc(user.uid).set({
      'profile': {
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
        'appVersion': '2.0',
        'google': isGoogle,
      },
      'onboarding': {'completed': false},
    });
  }

  Future<bool> _checkOnboardingComplete(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return false;
      return (data['onboarding']?['completed'] ?? false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateLastActive() async {
    if (currentUser == null) return;
    try {
      await _db.collection('users').doc(currentUser!.uid).update({
        'profile.lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanımda.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen bekleyin.';
      default:
        return 'Giriş başarısız. Tekrar deneyin.';
    }
  }
}

// Sonuç modeli
class AuthResult {
  final bool success;
  final bool cancelled;
  final User? user;
  final bool isNewUser;
  final bool onboardingComplete;
  final String? errorMessage;

  AuthResult._({
    required this.success,
    this.cancelled = false,
    this.user,
    this.isNewUser = false,
    this.onboardingComplete = false,
    this.errorMessage,
  });

  factory AuthResult.success({
    required User? user,
    required bool isNewUser,
    required bool onboardingComplete,
  }) => AuthResult._(
    success: true,
    user: user,
    isNewUser: isNewUser,
    onboardingComplete: onboardingComplete,
  );

  factory AuthResult.cancelled() =>
      AuthResult._(success: false, cancelled: true);

  factory AuthResult.error(String message) =>
      AuthResult._(success: false, errorMessage: message);
}
