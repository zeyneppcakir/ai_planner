// lib/services/ollama_service.dart
import 'dart:async'; // TimeoutException
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class OllamaService {
  static const int _port = 11434;

  // Platforma göre doğru host
  static String get _baseUrl {
    // Web debug'da da çoğunlukla 127.0.0.1 güvenli tercih
    if (kIsWeb) return 'http://127.0.0.1:$_port';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_port'; // Android emülatör
    return 'http://127.0.0.1:$_port'; // Windows/macOS/Linux, iOS sim
  }

  static String get baseUrl => _baseUrl;

  /// Basit generate endpoint'i
  static Future<String> generate(
    String prompt, {
    String model = 'qwen3b-cpu',
    Map<String, dynamic>? options, // örn. {'num_ctx': 2048}
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final uri = Uri.parse('$_baseUrl/api/generate');

    // Güvenli varsayılanlar: CPU-only ve makul context
    final mergedOptions = {
      'num_gpu': 0, // GPU kesin kapalı
      'num_ctx': 1024, // RAM güvenliği (gerekirse çağrıda büyütebilirsin)
      ...?options, // çağrıda gelen değerler bunları override eder
    };

    final body = jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': false,
      'options': mergedOptions,
    });

    try {
      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception('Ollama ${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['response'] ?? '').toString().trim();
    } on SocketException {
      throw Exception(
        'Ollama sunucusuna bağlanılamadı. "ollama serve" açık mı?',
      );
    } on TimeoutException {
      throw Exception('Ollama isteği zaman aşımına uğradı.');
    }
  }

  // GÖREV İÇİN OTOMATİK ETİKET ÜRETME
  // Örnek çıktı: ["spor", "koşu", "sağlık"]
  static Future<List<String>> generateTagsForTask({
    required String title,
    String? notes, // şu an kullanılmıyor ama imza bozulmasın diye duruyor
    String? category, // eğitim / yaşam / kariyer (opsiyonel)
  }) async {
    // Sadece başlık + kategori kullanıyoruz
    final buffer = StringBuffer()..writeln('Görev başlığı: "$title"');
    if (category != null && category.trim().isNotEmpty) {
      buffer.writeln('Kategori: "$category"'); // eğitim / kariyer / yaşam
    }

    final prompt = '''
Sen bir görev planlama (to-do / takvim) uygulaması için akıllı etiket üreten asistansın.

Kullanıcı görevler ekliyor. Senin görevin:
- Görev başlığını ve kategorisini anlamak,
- Bu görevi temsil eden **en fazla 3 adet** kısa ve anlamlı etiket önermek.

Kurallar:
- Etiketler TÜRKÇE olacak.
- Etiketler tamamen küçük harf olsun.
- Türkçe karakterleri mutlaka kullan (ç, ğ, ı, ö, ş, ü).
- Kısaltma kullanma. Örneğin:
  - "mat" yerine "matematik",
  - "yasam" yerine "yaşam",
  - "say" yerine "sayı".
- 1 veya 2 kelimeden oluşsun.
- Noktalama, # gibi semboller kullanma.
- Aynı anlama gelen veya aynı kökten gelen etiketleri tekrar etme:
  - "yasam" ve "yaşam" → sadece "yaşam" yaz.
  - "say" ve "sayı" → sadece "sayı" yaz.
- **En fazla 3 etiket üret.**
- SADECE bir JSON dizisi döndür.
  Örnek: ["spor","sağlık","yaşam"]

Anlam genelleme örnekleri:
- "yoga", "koşu", "yürüyüş", "pilates", "fitness" → "spor", "sağlık", "yaşam"
- "spor salonu", "gym" → "spor", "sağlık"
- "final", "vize", "quiz" → "sınav"
- "ödev", "assignment" → "ödev"
- "proje", "project" → "proje"
- "toplantı", "meeting" → "toplantı"
- "mülakat", "iş görüşmesi" → "mülakat", "kariyer"
- "staj" → "staj", "kariyer"
- "tez", "bitirme projesi" → "tez", "eğitim"
- "doktor", "randevu" → "sağlık"
- Eğer başlık çok genel ise, kategoriye uygun genel etiketler kullan:
  - kategori "eğitim" ise: "eğitim", "ders", "çalışma"
  - kategori "kariyer" ise: "kariyer", "iş"
  - kategori "yaşam" ise: "yaşam", "kişisel"

Görev:
${buffer.toString()}
''';

    final raw = await generate(
      prompt,
      model: 'qwen3b-cpu',
      options: {
        'temperature': 0.3, // daha tutarlı etiketler
        'num_ctx': 1024,
      },
    );

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        final rawTags = decoded.whereType<String>().toList();

        //  LLM den gelen etiketleri temizle + normalize et
        final cleanedTags = _normalizeTags(rawTags);

        // Son olarak en fazla 3 tanesini kullan
        return cleanedTags.take(3).toList();
      }
    } catch (_) {
      // JSON düzgün değilse aldırma, aşağıda boş liste döneriz
    }

    return [];
  }

  /// /api/chat (istemiyorsan silebilirsin)
  static Future<String> chat(
    List<Map<String, String>> messages, {
    String model = 'qwen3b-cpu',
    Map<String, dynamic>? options,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse('$_baseUrl/api/chat');

    final mergedOptions = {
      'num_gpu': 0,
      'num_ctx': 1024,
      ...?options,
    };

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': false,
      'options': mergedOptions,
    });

    try {
      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);

      if (res.statusCode != 200) {
        throw Exception('Ollama ${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = (data['message'] as Map?) ?? {};
      return (msg['content'] ?? '').toString().trim();
    } on SocketException {
      throw Exception(
        'Ollama sunucusuna bağlanılamadı. "ollama serve" açık mı?',
      );
    } on TimeoutException {
      throw Exception('Ollama isteği zaman aşımına uğradı.');
    }
  }

  //  ETİKET TEMİZLEME ARAÇLARI
  // LLM den gelen etiketleri temizleyip normalize eder:
  // - trim + lowercase
  // - çok kısa (3 harften kısa) kısaltmaları at
  // - Türkçe karakterleri göz ardı ederek tekrar edenleri birleştir
  static List<String> _normalizeTags(List<String> input) {
    final cleaned = <String>[];
    final seenKeys = <String>{};

    for (var tag in input) {
      var t = tag.trim().toLowerCase();

      if (t.isEmpty) continue;

      // "mat", "say" gibi çok kısa ve anlamsız kısaltmaları ele
      if (t.length < 4) continue;

      final key = _baseTagKey(t);
      if (seenKeys.contains(key)) {
        // aynı kökten gelen (yasam / yaşam gibi) etiketleri at
        continue;
      }

      seenKeys.add(key);
      cleaned.add(t);
    }

    return cleaned;
  }

  // Türkçe karakterleri sadeleştirerek karşılaştırma anahtarı üretir
  static String _baseTagKey(String s) {
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'İ': 'i',
      'I': 'i',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };

    final buffer = StringBuffer();
    for (final code in s.runes) {
      final ch = String.fromCharCode(code);
      buffer.write(map[ch] ?? ch);
    }
    return buffer.toString();
  }
}
