// lib/screens/register_screen.dart

import 'package:ai_planner/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ai_planner/core/validation/email_validator.dart';
import 'package:ai_planner/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static const String _logoAsset = 'assets/branding/branding.png';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // Kullanıcı dostu hata mesajları
  String _friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-posta adresini kontrol edelim; küçük bir yazım hatası olabilir.';
        case 'email-already-in-use':
          return 'Bu e-posta ile zaten bir hesap var.';
        case 'weak-password':
          return 'Şifreni biraz güçlendirelim (en az 6 karakter).';
        case 'network-request-failed':
          return 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dener misin?';
        default:
          return e.message ??
              'Beklenmeyen bir durum oluştu. Birazdan yeniden dener misin?';
      }
    }
    return 'Bir şeyler ters gitti. Lütfen tekrar dener misin?';
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;

    // Ek politika kontrolü
    final policyErr = EmailPolicy.validate(email, checkDomain: false);
    if (policyErr != null) {
      setState(() => _error = policyErr);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Kullanıcıyı oluştur
      final cred = await AuthService().registerWithEmail(
        email: email,
        password: pass,
      );

      // 2) Görünür isim güncelle
      if (cred.user != null) {
        try {
          await cred.user!.updateDisplayName(name);
        } catch (_) {}
      }

      // 3) Doğrulama e-postası gönder
      try {
        await cred.user?.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Doğrulama e-postasını gönderdik. '
                'Gelen kutunu ve Spam klasörünü kontrol etmeyi unutma.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Doğrulama e-postasını şu an gönderemedik. '
                'Birazdan tekrar dener misin?',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      // 4) Başarılı kayıt → bilgi ver ve login ekranına dön
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kayıt tamam 🎉 E-postanı doğruladıktan sonra giriş yapabilirsin.',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // E-posta zaten kayıtlı ise alt sheet aç
      if (e.code == 'email-already-in-use' && mounted) {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text('Bu e-posta zaten kayıtlı'),
                  subtitle: Text('Nasıl devam etmek istersin?'),
                ),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Giriş yap'),
                  onTap: () => Navigator.pop(ctx, 'login'),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Şifre sıfırla'),
                  onTap: () => Navigator.pop(ctx, 'reset'),
                ),
              ],
            ),
          ),
        );

        if (action == 'reset') {
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Şifre sıfırlama bağlantısını e-postana gönderdik. '
                    'Gelen kutunu ve Spam klasörünü kontrol etmeyi unutma.',
                  ),
                ),
              );
            }
          } catch (_) {}
        } else if (action == 'login') {
          if (mounted) Navigator.pop(context); // Login ekranına dön
        }
      }

      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
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
          // Arka plan görseli
          Positioned.fill(
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
          ),

          // Gradyen
          Positioned.fill(
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
          ),

          // İçerik
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
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kayıt Ol',
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
                        child: AutofillGroup(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'İsim gerekli.'
                                    : null,
                                decoration: _dec(
                                  'Kullanıcı adı',
                                  Icons.person_outline,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                      RegExp(r'\s')),
                                ],
                                validator: (v) => EmailPolicy.validate(
                                  (v ?? '').trim(),
                                  checkDomain: false,
                                ),
                                decoration: _dec(
                                  'E-posta',
                                  Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _pass,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (v) => v == null || v.length < 6
                                    ? 'Şifre en az 6 karakter.'
                                    : null,
                                decoration: _dec(
                                  'Şifre (min 6)',
                                  Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
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
                                  onPressed: _loading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.4),
                                        )
                                      : const Text('Kayıt ol'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text(
                                  'Zaten hesabın var mı? Giriş yap',
                                ),
                              ),
                            ],
                          ),
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
