// lib/theme_mode_notifier.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Uygulamanın tema modunu yöneten StateNotifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  // Belirli bir moda geç (light / dark / system)
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  // Sadece light <-> dark arasında geçiş yapmak istersen
  void toggleDarkLight() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }
}

// Riverpod provider: MyApp buradan ThemeMode okuyor
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
