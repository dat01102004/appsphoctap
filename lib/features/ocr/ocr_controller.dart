import 'package:flutter/material.dart';
import '../../core/tts/tts_service.dart';
import '../../data/services/vision_api.dart';

class OcrController extends ChangeNotifier {
  final VisionApi api;
  final TtsService tts;

  bool loading = false;
  String text = "";

  OcrController(this.api, this.tts);

  Future<void> runOcr(String filePath) async {
    loading = true;
    notifyListeners();
    try {
      final res = await api.ocr(filePath);
      text = res.text;
      await tts.speak(text);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}