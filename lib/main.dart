// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme.dart'; // lightTheme / darkTheme burada
import 'theme_mode_notifier.dart'; // 🔹 ThemeMode provider'ını burada tanımlayacağız

// Ekranlar (named route'lar için)
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verify_email.dart';

// Auth durumuna göre Login / VerifyEmail / Home döndüren widget
import 'screens/home/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase başlatma + hata yakalama
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase başarıyla başlatıldı.");
  } catch (e, st) {
    debugPrint("🔥 Firebase başlatılamadı: $e");
    debugPrintStack(stackTrace: st);
  }

  // Flutter genel hata yakalayıcı (debug için)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('⚠️ Flutter Hatası: ${details.exception}');
  };

  runApp(const ProviderScope(child: MyApp()));
}

//  Artık ConsumerWidget, çünkü themeModeProviderı izleyeceğiz
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //  Riverpod üzerinden anlık tema modunu alıyoruz
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Planner',
      theme: lightTheme,
      darkTheme: darkTheme,

      // Eskiden: ThemeMode.system
      // Artık: kullanıcının seçtiği mode (system / light / dark)
      themeMode: themeMode,

      // Giriş / ana ekran akışı tamamen AuthGate içinde
      home: const AuthGate(),

      // İsimli rotalar
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/verifyEmail': (_) => const VerifyEmailScreen(),
      },
    );
  }
}
