import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool initialized = false;
  bool isListening = false;
  String lastWords = '';

  String _localeId = 'vi_VN';
  double soundLevel = 0;
  int _sessionId = 0;

  Future<void> init() async {
    if (initialized) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      initialized = true;
      notifyListeners();
      return;
    }

    final ok = await _stt.initialize(
      onStatus: (status) {
        if (status.toLowerCase().contains('notlistening')) {
          isListening = false;
          notifyListeners();
        }
      },
      onError: (_) {
        isListening = false;
        notifyListeners();
      },
    );

    if (ok) {
      try {
        final locales = await _stt.locales();
        final vi = locales
            .where((l) => l.localeId.toLowerCase().startsWith('vi'))
            .toList();
        if (vi.isNotEmpty) {
          _localeId = vi.first.localeId;
        } else {
          final sys = await _stt.systemLocale();
          if (sys != null) _localeId = sys.localeId;
        }
      } catch (_) {}
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> start({
    required void Function(String finalText) onFinal,
  }) async {
    await init();
    if (!_stt.isAvailable) return;

    final sessionId = ++_sessionId;

    lastWords = '';
    soundLevel = 0;

    await _stt.stop();
    await Future.delayed(const Duration(milliseconds: 250));

    isListening = true;
    notifyListeners();

    await _stt.listen(
      localeId: _localeId,
      listenMode: ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      onSoundLevelChange: (lvl) {
        if (sessionId != _sessionId) return;
        soundLevel = lvl;
        notifyListeners();
      },
      onResult: (res) {
        if (sessionId != _sessionId) return;

        lastWords = res.recognizedWords;
        notifyListeners();

        if (res.finalResult) {
          isListening = false;
          notifyListeners();
          onFinal(res.recognizedWords.trim());
        }
      },
    );
  }

  Future<void> stop() async {
    _sessionId++;
    await _stt.stop();
    isListening = false;
    soundLevel = 0;
    notifyListeners();
  }
}
