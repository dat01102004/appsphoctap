import '../../features/settings/settings_controller.dart';
import '../../data/models/settings_model.dart';
import '../tts/tts_service.dart';
import 'global_voice_intent.dart';

typedef GlobalVoiceSpeaker = Future<void> Function(String text, String title);

class GlobalVoiceCommandService {
  final SettingsController settings;
  final TtsService tts;

  static const double rateStep = 0.1;
  static const double largerRateStep = 0.2;

  GlobalVoiceCommandService(this.settings, this.tts);

  Future<bool> handle(
    String raw, {
    GlobalVoiceSpeaker? speak,
    bool replayCurrentText = false,
  }) async {
    final intent = GlobalVoiceIntentParser.parse(raw);

    switch (intent) {
      case GlobalVoiceIntent.speedUp:
        await adjustSpeechRate(
          delta: _rateDelta(raw, direction: 1),
          spokenMessage: 'Đã tăng tốc độ đọc',
          speak: speak,
          replayCurrentText: replayCurrentText,
        );
        return true;
      case GlobalVoiceIntent.speedDown:
        await adjustSpeechRate(
          delta: _rateDelta(raw, direction: -1),
          spokenMessage: 'Đã giảm tốc độ đọc',
          speak: speak,
          replayCurrentText: replayCurrentText,
        );
        return true;
      case GlobalVoiceIntent.speedDefault:
        await setDefaultSpeechRate(
          speak: speak,
          replayCurrentText: replayCurrentText,
        );
        return true;
      case GlobalVoiceIntent.home:
      case GlobalVoiceIntent.back:
      case GlobalVoiceIntent.stopReading:
      case GlobalVoiceIntent.repeatReading:
      case GlobalVoiceIntent.settings:
      case GlobalVoiceIntent.history:
      case GlobalVoiceIntent.caption:
      case GlobalVoiceIntent.ocr:
      case GlobalVoiceIntent.news:
      case GlobalVoiceIntent.camera:
      case GlobalVoiceIntent.none:
        return false;
    }
  }

  Future<void> setDefaultSpeechRate({
    GlobalVoiceSpeaker? speak,
    bool replayCurrentText = false,
  }) async {
    await settings.setRate(SettingsModel.defaults.rate);

    try {
      await settings.saveCurrent();
    } catch (_) {
      // The command still applies locally when the user is offline or not signed in.
    }

    if (replayCurrentText && tts.lastText.trim().isNotEmpty) {
      await tts.speak(tts.lastText);
      return;
    }

    const message = 'Đã đưa tốc độ đọc về mặc định';

    if (speak != null) {
      await speak(message, 'Cài đặt');
      return;
    }

    await tts.speak(message);
  }

  Future<void> adjustSpeechRate({
    required double delta,
    required String spokenMessage,
    GlobalVoiceSpeaker? speak,
    bool replayCurrentText = false,
  }) async {
    final nextRate = settings.current.rate + delta;

    await settings.setRate(nextRate);

    try {
      await settings.saveCurrent();
    } catch (_) {
      // The command still applies locally when the user is offline or not signed in.
    }

    if (replayCurrentText && tts.lastText.trim().isNotEmpty) {
      await tts.speak(tts.lastText);
      return;
    }

    if (speak != null) {
      await speak(spokenMessage, 'Cài đặt');
      return;
    }

    await tts.speak(spokenMessage);
  }

  double _rateDelta(String raw, {required int direction}) {
    final normalized = GlobalVoiceIntentParser.normalize(raw);
    final step = _usesLargerStep(normalized) ? largerRateStep : rateStep;
    return direction * step;
  }

  bool _usesLargerStep(String normalized) {
    return _hasPhrase(normalized, 'mot xiu') ||
        _hasPhrase(normalized, '1 xiu') ||
        _hasPhrase(normalized, 'chut xiu') ||
        _hasPhrase(normalized, 'mot chut') ||
        _hasPhrase(normalized, '1 chut') ||
        _hasPhrase(normalized, 'nhe') ||
        _hasPhrase(normalized, 'ti') ||
        _hasPhrase(normalized, 'ty');
  }

  bool _hasPhrase(String text, String phrase) {
    return ' $text '.contains(' $phrase ');
  }
}
