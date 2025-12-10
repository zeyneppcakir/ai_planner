// lib/screens/verify_email.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_planner/screens/home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  // Durum
  bool _sending = false;
  bool _checking = false;
  bool _sentOnce = false;

  // 15 dakikalık süre sınırı
  late DateTime _deadline;

  // Timer lar
  Timer? _pollTimer; // Her 6 saniyede otomatik kontrol
  Timer? _cooldownTimer; // 30 sn tekrar gönderme bekleme
  Timer? _tickTimer; // Geri sayım göstergesi için

  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _deadline = DateTime.now().add(const Duration(minutes: 15));

    _startAutoCheck();
    _startTickTimer();

    // Ekran açılır açılmaz ilk maili gönder
    _sendVerificationEmail();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  // OTOMATİK KONTROL (6 saniyede bir)
  void _startAutoCheck() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkVerified(auto: true),
    );
  }

  // 15 dakikalık geri sayımı göstermek için
  void _startTickTimer() {
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        setState(() {}); // sadece kalan süreyi yeniden çizdiriyoruz
      },
    );
  }

  // DOĞRULAMA E-POSTASI GÖNDER
  Future<void> _sendVerificationEmail() async {
    if (_sending || _cooldown > 0) return;

    setState(() {
      _sending = true;
      _cooldown = 30; // arkadaşının koyduğu 30 sn bekleme
    });

    // Cooldown geri sayımı
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });

    try {
      await _auth.currentUser?.sendEmailVerification();

      if (!mounted) return;
      _sentOnce = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Doğrulama e-postasını gönderdik. '
            'Gelen kutunu ve Spam klasörünü kontrol etmeyi unutma.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-posta gönderilemedi. Birazdan tekrar dener misin?'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // DOĞRULANDI MI KONTROL ET

  Future<void> _checkVerified({bool auto = false}) async {
    if (_checking) return;

    // 15 dakika geçtiyse -> çıkış + logine dönüş
    if (DateTime.now().isAfter(_deadline)) {
      await _auth.signOut();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Süre doldu. Lütfen tekrar giriş yap.'),
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() => _checking = true);

    try {
      await _auth.currentUser?.reload();
      _user = _auth.currentUser;

      final verified = _user?.emailVerified ?? false;

      if (verified) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-posta doğrulandı! Giriş yapılıyor...'),
          ),
        );

        await Future.delayed(const Duration(seconds: 1));

        // Kullanıcı doğrulanmış -> HomeScreene gönder
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
            settings: const RouteSettings(
              arguments: {'fromVerification': true},
            ),
          ),
          (route) => false,
        );
      } else {
        // Manuel kontrol butonundan geldiyse uyarı ver
        if (!auto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Henüz doğrulanmamış. Gelen kutunu ve Spam klasörünü kontrol et.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // KALAN SÜRE (15 dk)
  String _formatRemainingTime() {
    Duration diff = _deadline.difference(DateTime.now());
    if (diff.isNegative) diff = Duration.zero;

    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;

    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    _user ??= _auth.currentUser;
    final email = _user?.email ?? '-';
    final verified = _user?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('E-posta Doğrulaması')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  verified
                      ? Icons.mark_email_read_rounded
                      : Icons.mail_outline_rounded,
                  size: 80,
                ),
                const SizedBox(height: 12),
                Text(
                  'Merhaba $email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  verified
                      ? 'Hesabın doğrulandı. Uygulamayı kullanmaya devam edebilirsin.'
                      : 'Hesabını kullanabilmek için e-postanı doğrulaman gerekiyor.\n'
                          'Gelen kutunu ve Spam klasörünü kontrol etmeyi unutma.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!verified) ...[
                  // Doğrulama e-postası gönder / tekrar gönder
                  FilledButton.icon(
                    onPressed: (_cooldown == 0 && !_sending)
                        ? _sendVerificationEmail
                        : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _cooldown > 0
                          ? 'Tekrar gönder (${_cooldown}s)'
                          : (_sentOnce
                              ? 'Tekrar gönder'
                              : 'Doğrulama e-postası gönder'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Manuel kontrol butonu
                  OutlinedButton.icon(
                    onPressed:
                        _checking ? null : () => _checkVerified(auto: false),
                    icon: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Doğruladım, kontrol et'),
                  ),
                ],
                if (verified) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(),
                          settings: const RouteSettings(
                            arguments: {'fromVerification': true},
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Uygulamaya devam et'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Kalan süre: ${_formatRemainingTime()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    await _auth.signOut();
                    if (!mounted) return;
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (_) => false);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Çıkış yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
