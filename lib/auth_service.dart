// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/validation/email_validator.dart';

class AuthService {
  AuthService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  //  AUTH STATE 
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  // Eski isimle uyumluluk
  Stream<User?> get authState => _auth.authStateChanges();

  //  EMAIL / PASSWORD 
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normEmail = email.trim().toLowerCase();

    // Kural kontrolü (domain kontrolü gerekirse true yap)
    final err = EmailPolicy.validate(normEmail, checkDomain: false);
    if (err != null) {
      throw Exception(err);
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: normEmail,
        password: password,
      );

      // Görünür ad
      if (displayName != null && displayName.trim().isNotEmpty) {
        try {
          await cred.user?.updateDisplayName(displayName.trim());
          await cred.user?.reload();
        } catch (_) {}
      }

      // Doğrulama e-postası (varsa tekrar göndermeye gerek yok)
      try {
        if (!(cred.user?.emailVerified ?? false)) {
          await cred.user!.sendEmailVerification();
        }
      } catch (_) {}

      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(_readable(e));
    }
  }

  // Eski çağrılar için alias
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    return registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normEmail = email.trim().toLowerCase();
    try {
      return await _auth.signInWithEmailAndPassword(
        email: normEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_readable(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_readable(e));
    }
  }

  //  GOOGLE SIGN-IN 
  Future<UserCredential> signInWithGoogle(
      {bool forceAccountChooser = false}) async {
    try {
      final google = GoogleSignIn(scopes: const ['email']);

      if (forceAccountChooser) {
        try {
          await google.signOut(); // önceki seçimi sıfırla (chooser gelsin)
        } catch (_) {}
      }

      final gUser = await google.signIn();
      if (gUser == null) {
        throw FirebaseAuthException(
          code: 'aborted-by-user',
          message: 'Google girişi kullanıcı tarafından iptal edildi.',
        );
      }

      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_readable(e));
    } catch (e) {
      throw Exception('Google ile giriş sırasında hata: $e');
    }
  }

  //  EMAIL VERIFICATION HELPERS 
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> resendVerificationEmail(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnack(
          context,
          'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
          Colors.red,
        );
        return;
      }
      if (user.emailVerified) {
        _showSnack(context, 'E-posta zaten doğrulanmış.', Colors.green);
        return;
      }
      await user.sendEmailVerification();
      _showSnack(
        context,
        'Doğrulama e-postası yeniden gönderildi.',
        Colors.blue,
      );
    } catch (e) {
      _showSnack(context, 'E-posta gönderilemedi: $e', Colors.red);
    }
  }

  Future<bool> reloadAndIsVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Eski isimle uyumluluk
  Future<bool> reloadAndCheckVerified() => reloadAndIsVerified();

  Future<void> handleVerifyAndRoute(
    BuildContext context, {
    String redirectRoute = '/home',
  }) async {
    try {
      final ok = await reloadAndIsVerified();
      if (ok) {
        _showSnack(
          context,
          'E-posta doğrulandı! Giriş yapılıyor...',
          Colors.green,
        );
        Navigator.of(context)
            .pushNamedAndRemoveUntil(redirectRoute, (r) => false);
      } else {
        _showSnack(
          context,
          'E-postan henüz doğrulanmamış. Gelen kutunu (ve spam) kontrol et veya yeniden gönder.',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnack(context, 'Bir hata oluştu: $e', Colors.red);
    }
  }

  //  SIGN OUT 
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut(); // varsa Google oturumunu da kapat
    } catch (_) {}
    await _auth.signOut();
  }

  //  INTERNALS 
  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-posta adresi geçersiz.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Bu e-posta ile bir hesap bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'invalid-credential':
        return 'Kimlik bilgileri hatalı veya süresi geçmiş.';
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten bir hesap var.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'network-request-failed':
        return 'Ağ hatası. İnternetini kontrol et.';
      default:
        return e.message ?? 'Bilinmeyen bir hata oluştu.';
    }
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}
