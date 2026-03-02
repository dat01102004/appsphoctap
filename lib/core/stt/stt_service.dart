import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _stt = SpeechToText();

  Future<bool> init() => _stt.initialize();

  Future<void> listen({required void Function(String) onText}) async {
    await _stt.listen(
      localeId: "vi_VN",
      onResult: (res) => onText(res.recognizedWords),
    );
  }

  Future<void> stop() => _stt.stop();
}