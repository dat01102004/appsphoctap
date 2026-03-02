import 'package:flutter/material.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/read_url_models.dart';
import '../../data/services/read_api.dart';

class ReadUrlController extends ChangeNotifier {
  final ReadApi api;
  final TtsService tts;

  bool loading = false;
  ReadUrlResponse? result;

  ReadUrlController(this.api, this.tts);

  Future<void> submit(String url) async {
    loading = true;
    notifyListeners();
    try {
      result = await api.readUrl(url, summary: true);
      final speakText = result!.summaryTts ?? result!.ttsText ?? result!.summary ?? result!.text;
      await tts.speak(speakText);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}