// lib/app.dart
import 'package:flutter/material.dart';
// AuthGate artık şurada: lib/screens/home/widgets/auth_gate.dart
import 'screens/home/widgets/auth_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Planlayıcı',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      // Uygulama açılınca:
      // - user yoksa -> Login
      // - user var, mail doğrulanmamış -> VerifyEmail
      // - user var, doğrulanmış -> HomeScreen
      home: const AuthGate(),
    );
  }
}
