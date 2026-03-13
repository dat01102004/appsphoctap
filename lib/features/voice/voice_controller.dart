import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  int _sessionId = 0;
  bool initialized = false;
  bool isListening = false;
  String lastWords = "";
  String _localeId = "vi_VN";
  double soundLevel = 0;

  Future<void> init() async {
    if (initialized) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      initialized = true;
      notifyListeners();
      return;
    }

    initialized = await _stt.initialize(
      onStatus: (status) {
        final s = status.toLowerCase();
        if (s.contains('not listening') ||
            s.contains('notlistening') ||
            s.contains('done')) {
          isListening = false;
          notifyListeners();
        }
      },
      onError: (_) {
        isListening = false;
        notifyListeners();
      },
      debugLogging: false,
    );

    if (initialized) {
      try {
        final locales = await _stt.locales();
        final vi = locales
            .where((l) => l.localeId.toLowerCase().startsWith('vi'))
            .toList();

        if (vi.isNotEmpty) {
          _localeId = vi.first.localeId;
        } else {
          final sys = await _stt.systemLocale();
          if (sys != null) {
            _localeId = sys.localeId;
          }
        }
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> start({
    required void Function(String finalText) onFinal,
  }) async {
    await init();
    if (!_stt.isAvailable) return;

    final sessionId = ++_sessionId;
    bool delivered = false;

    lastWords = "";
    soundLevel = 0;

    await _stt.stop();
    await Future.delayed(const Duration(milliseconds: 250));

    isListening = true;
    notifyListeners();

    void deliverFinal(String value) {
      if (delivered) return;
      delivered = true;

      final text = value.trim();
      isListening = false;
      notifyListeners();

      if (text.isNotEmpty) {
        onFinal(text);
      }
    }

    await _stt.listen(
      localeId: _localeId,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: (lvl) {
        if (sessionId != _sessionId) return;
        soundLevel = lvl;
        notifyListeners();
      },
      onResult: (SpeechRecognitionResult res) {
        if (sessionId != _sessionId) return;

        lastWords = res.recognizedWords.trim();
        notifyListeners();

        if (res.finalResult) {
          deliverFinal(lastWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (sessionId != _sessionId) return;
      if (!delivered && lastWords.trim().isNotEmpty && !isListening) {
        deliverFinal(lastWords);
      }
    });
  }

  Future<void> stop() async {
    _sessionId++;
    await _stt.stop();
    isListening = false;
    soundLevel = 0;
    notifyListeners();
  }
}