import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    await _tts.setLanguage("vi-VN");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _tts.stop();
    await _tts.speak(t);
  }

  Future<void> stop() => _tts.stop();
}