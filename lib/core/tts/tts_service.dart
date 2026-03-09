import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  double rate = 0.45; // tốc độ đọc
  double pitch = 1.0; // ngữ điệu
  String language = "vi-VN";
  String? voiceName; // tên voice (optional)

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<List<dynamic>> getVoices() async {
    final v = await _tts.getVoices;
    return (v as List?) ?? [];
  }

  Future<void> setRate(double v) async {
    rate = v;
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double v) async {
    pitch = v;
    await _tts.setPitch(pitch);
  }

  Future<void> setVoice(Map<String, String> voice) async {
    // ví dụ {"name": "...", "locale": "vi-VN"}
    voiceName = voice["name"];
    await _tts.setVoice(voice);
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await _tts.stop();
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.speak(t);
  }

  Future<void> stop() => _tts.stop();

// pause/resume không hỗ trợ đồng nhất trên Android; dùng stop + speak lại
}