// lib/core/utils/progress.dart
import 'package:flutter/material.dart';

// p: 0..1 arası ilerleme (0 = %0, 1 = %100).
// Renkler Material ColorScheme den alındığı için tema (light/dark) ile uyumludur
Color progressColor(BuildContext context, double p) {
  final cs = Theme.of(context).colorScheme;

  // %100 - birincil vurgu (tema rengi)
  if (p >= 1.0) return cs.primary;

  // Üç renk mantığı:
  //  - 0..0.49 - kırmızı (hata)
  //  - 0.50..0.89 - sarı/amber benzeri (errorContainer'i daha yumuşak ton)
  //  - 0.90..0.99 - yeşil (secondary/tertiary tonları)
  if (p < 0.50) return cs.error;
  if (p < 0.90) {
    // Light/Dark'ta okunaklı, orta sıcak bir ton:
    // errorContainer koyu temada daha koyu, açık temada daha açık çalışır.
    return cs.errorContainer;
  }
  // 0.90..0.99
  return cs.tertiary; // genelde başarı/pozitif için hoş bir yeşil/teal tonu
}

// İlerleme çubuğunun arkadaki (track) rengini verir
// Light/Dark’ta yeterli kontrast için surfaceVariant baz alınır
Color progressTrackColor(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return cs.surfaceVariant.withOpacity(0.45);
}
