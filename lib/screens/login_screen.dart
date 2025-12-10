// lib/screens/login_screen.dart

import 'package:ai_planner/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ai_planner/core/validation/email_validator.dart';
import 'package:ai_planner/services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _email = TextEditingController();
  final _pass = TextEditingController();

  // Form
  final _formKey = GlobalKey<FormState>();

  // UI
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // LOGO yolu
  static const String _logoAsset = 'assets/branding/branding.png';

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // Firebase hatalarını kullanıcı dostu mesaja çevir
  String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-posta adresini kontrol edelim; küçük bir yazım hatası olabilir.';
        case 'user-not-found':
        case 'wrong-password':
          return 'Bilgileri doğrulayamadık. E-posta veya şifreyi yeniden kontrol eder misin?';
        case 'network-request-failed':
          return 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dener misin?';
        default:
          return e.message ??
              'Beklenmeyen bir durum oluştu. Birazdan yeniden dener misin?';
      }
    }
    return 'Bir şeyler ters gitti. Lütfen tekrar dener misin?';
  }

  // Normal login
  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final policyErr =
        EmailPolicy.validate(_email.text.trim(), checkDomain: false);
    if (policyErr != null) {
      setState(() => _error = policyErr);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService().signInWithEmail(
        email: _email.text.trim().toLowerCase(),
        password: _pass.text,
      );
      // Yönlendirme main.dart / AuthGate tarafından yapılıyor.
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Google ile giriş
  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().signInWithGoogle(forceAccountChooser: true);
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  //  Şifremi unuttum – sadece Firebase kullanarak
  Future<void> _resetPassword() async {
    final email = _email.text.trim().toLowerCase();

    // E-posta doğrulama
    final err = EmailPolicy.validate(email, checkDomain: false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Şifre sıfırlama bağlantısını e-postana gönderdik. '
            'Gelen kutunu ve gerekirse spam klasörünü kontrol etmeyi unutma.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'Bu e-posta ile kayıtlı bir hesap bulunamadı.';
          break;
        case 'invalid-email':
          msg =
              'E-posta adresini kontrol edelim; küçük bir yazım hatası olabilir.';
          break;
        case 'too-many-requests':
          msg =
              'Kısa süre içinde çok fazla şifre sıfırlama isteği gönderdin. Biraz bekleyip tekrar dene.';
          break;
        case 'network-request-failed':
          msg =
              'İnternet bağlantısında bir sorun var gibi görünüyor. Bağlantını kontrol edip tekrar dener misin?';
          break;
        default:
          msg =
              'Şifre sıfırlama isteği sırasında bir sorun oluştu. Lütfen daha sonra tekrar dene.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Şifre sıfırlama isteği sırasında bir sorun oluştu. Lütfen daha sonra tekrar dene.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Giriş ekranından "E-posta gelmedi mi? Tekrar gönder"
  Future<void> _resendVerificationFromLogin() async {
    if (_loading) return;
    final email = _email.text.trim();
    final pass = _pass.text;

    final emailErr = EmailPolicy.validate(email, checkDomain: false);
    if (emailErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailErr)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu e-posta ile kayıtlı bir hesap yok.'),
          ),
        );
        return;
      }

      final usesPassword = methods.contains('password');
      if (usesPassword && pass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifren gerekli.')),
        );
        return;
      }

      UserCredential cred;
      if (usesPassword) {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu hesap farklı bir giriş yöntemi kullanıyor.'),
          ),
        );
        return;
      }

      final user = cred.user;
      if (user == null) return;

      await user.reload();
      if (user.emailVerified) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-posta zaten doğrulanmış 😊')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        return;
      }

      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doğrulama e-postası mail adresine gönderildi.'),
        ),
      );
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/verifyEmail', (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir sorun oluştu, tekrar dener misin?')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final logoWidth = (size.width * 0.55).clamp(160, 260).toDouble();

    InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
        InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          filled: true,
          fillColor: cs.surfaceVariant.withOpacity(.4),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: cs.outline.withOpacity(.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: cs.outline.withOpacity(.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: cs.primary, width: 1.6),
          ),
        );

    return Scaffold(
      body: Stack(
        children: [
          const PositionedFillBackground(),
          PositionedGradient(cs: cs),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _logoAsset,
                      width: logoWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Giriş Yap',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              validator: (v) => EmailPolicy.validate(
                                (v ?? '').trim(),
                                checkDomain: false,
                              ),
                              decoration: _dec('E-posta', Icons.email_outlined),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _pass,
                              obscureText: _obscure,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Lütfen şifreni gir.'
                                  : null,
                              decoration: _dec(
                                'Şifre',
                                Icons.lock_outline,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : _resetPassword,
                                child: const Text('Şifremi unuttum'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: cs.error),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: const StadiumBorder(),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Giriş Yap'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : _resendVerificationFromLogin,
                              child: const Text(
                                'E-posta gelmedi mi? Tekrar gönder',
                              ),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                              child: const Text('Hesabın yok mu? Kayıt ol'),
                            ),
                            const Divider(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _loginWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Google ile giriş'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Arka plan görseli
class PositionedFillBackground extends StatelessWidget {
  const PositionedFillBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/login_resmi.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.25),
              BlendMode.darken,
            ),
          ),
        ),
      ),
    );
  }
}

// Tema renkli gradient
class PositionedGradient extends StatelessWidget {
  final ColorScheme cs;
  const PositionedGradient({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withOpacity(0.14),
              Colors.transparent,
              cs.secondaryContainer.withOpacity(0.10),
            ],
          ),
        ),
      ),
    );
  }
}
