import 'package:flutter/material.dart';
import '../../core/errors/error_utils.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/read_url_models.dart';
import '../../data/services/read_api.dart';

class ReadUrlController extends ChangeNotifier {
  final ReadApi api;
  final TtsService tts;

  bool loading = false;
  ReadUrlResponse? result;
  String? errorMessage;

  ReadUrlController(this.api, this.tts);

  Future<void> submit(String url) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      result = await api.readUrl(url, summary: true);
      final speakText =
          result!.summaryTts ??
          result!.ttsText ??
          result!.summary ??
          result!.text;
      await tts.speak(speakText);
    } catch (e) {
      final message = friendlyApiMessage(e, feature: 'read_url');
      errorMessage = message;
      notifyListeners();
      await tts.speak(message);
      throw FriendlyError(message);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
