import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak(String text) async {
    await _tts.setLanguage("tr-TR"); // Türkçe seslendirme
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }
}
