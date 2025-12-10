// lib/theme.dart
import 'package:flutter/material.dart';

const seed = Color(0xFF6750A4);
const surfaceLight = Color(0xFFFFFBFE);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: surfaceLight,
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: false,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  ),
  // Dark tarafta da arka planı netleştirelim
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: false,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
  ),
);
