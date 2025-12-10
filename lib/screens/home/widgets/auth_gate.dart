// lib/screens/home/widgets/auth_gate.dart (dosyanın en üstü)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Alias kullanımı (daha kararlı, path çakışmalarını önler)
import 'package:ai_planner/screens/login_screen.dart' as login;
import 'package:ai_planner/screens/verify_email.dart' as verify;
import 'package:ai_planner/screens/home_screen.dart' as home;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSub;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();

    // 1) Firebase auth değişimlerini dinle
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });

    // 2) Kullanıcı giriş yaptıysa emailVerified statüsünü
    // periyodik olarak güncelle (15 sn)
    _reloadTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && !u.emailVerified) {
        try {
          await u.reload();
          if (mounted) setState(() {});
        } catch (_) {
          // sessiz geç
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _reloadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Kullanıcı yok -> Login'e git
    if (user == null) {
      return const login.LoginScreen();
    }

    // E-posta doğrulanmış -> Home'a git
    if (user.emailVerified) {
      return const home.HomeScreen();
    }

    // Doğrulanmamış kullanıcı -> VerifyEmailScreen e git
    return const verify.VerifyEmailScreen();
  }
}
