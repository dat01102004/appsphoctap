import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsProgress {
  final String text;
  final int start;
  final int end;
  final String word;

  const TtsProgress({
    required this.text,
    required this.start,
    required this.end,
    required this.word,
  });
}

class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _inited = false;

  double rate = 0.5;
  double pitch = 1.0;
  double volume = 1.0;
  String language = "vi-VN";
  String? voiceName;

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<TtsProgress?> progress = ValueNotifier<TtsProgress?>(
    null,
  );

  String _lastText = "";
  String get lastText => _lastText;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      isSpeaking.value = true;
      progress.value = null;
    });

    _tts.setCompletionHandler(() {
      isSpeaking.value = false;
      progress.value = null;
    });

    _tts.setCancelHandler(() {
      isSpeaking.value = false;
      progress.value = null;
    });

    _tts.setErrorHandler((_) {
      isSpeaking.value = false;
      progress.value = null;
    });

    _tts.setProgressHandler((text, start, end, word) {
      progress.value = TtsProgress(
        text: text,
        start: start,
        end: end,
        word: word,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getVoices() async {
    await init();

    final v = await _tts.getVoices;

    return ((v as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> setRate(double v) async {
    await init();
    rate = v.clamp(0.1, 1.0).toDouble();
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double v) async {
    await init();
    pitch = v;
    await _tts.setPitch(pitch);
  }

  Future<void> setVolume(double v) async {
    await init();
    volume = v.clamp(0.0, 1.0).toDouble();
    await _tts.setVolume(volume);
  }

  Future<void> setLanguage(String v) async {
    await init();
    final next = v.trim().isEmpty ? 'vi-VN' : v.trim();
    language = next;
    await _tts.setLanguage(language);
  }

  Future<void> setVoice(Map<dynamic, dynamic> voice) async {
    await init();

    final mappedVoice = <String, String>{
      'name': (voice['name'] ?? '').toString(),
      'locale': (voice['locale'] ?? language).toString(),
    };

    voiceName = mappedVoice['name'];

    await _tts.setVoice(mappedVoice);
  }

  Future<void> setVoiceName(String? name) async {
    await init();

    final value = name?.trim();
    if (value == null || value.isEmpty) {
      voiceName = null;
      await _tts.setLanguage(language);
      return;
    }

    final voices = await getVoices();
    final matched = voices.cast<Map<dynamic, dynamic>>().firstWhere(
      (voice) => (voice['name'] ?? '').toString() == value,
      orElse: () => {'name': value, 'locale': language},
    );

    await setVoice(matched);
  }

  Future<void> configure({
    String? voice,
    required double rate,
    required double volume,
    required String language,
  }) async {
    await setLanguage(language);
    await setRate(rate);
    await setVolume(volume);
    await setVoiceName(voice);
  }

  Future<void> speak(String text) async {
    await init();

    final t = text.trim();
    if (t.isEmpty) return;

    _lastText = t;
    progress.value = null;

    await _tts.stop();
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.speak(t);
  }

  Future<void> stop() async {
    await init();
    await _tts.stop();
    isSpeaking.value = false;
    progress.value = null;
  }
}
