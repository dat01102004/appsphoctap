import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool initialized = false;
  bool isListening = false;
  String lastWords = "";

  Future<void> init() async {
    if (initialized) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      initialized = true;
      notifyListeners();
      return;
    }

    await _stt.initialize(
      onStatus: (s) {},
      onError: (e) {},
    );

    initialized = true;
    notifyListeners();
  }

  Future<void> start({
    required void Function(String finalText) onFinal,
  }) async {
    await init();
    if (!_stt.isAvailable) return;

    lastWords = "";
    isListening = true;
    notifyListeners();

    await _stt.listen(
      localeId: 'vi_VN',
      listenMode: ListenMode.confirmation,
      partialResults: true,
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 1),
      onResult: (res) {
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
    await _stt.stop();
    isListening = false;
    notifyListeners();
  }
}