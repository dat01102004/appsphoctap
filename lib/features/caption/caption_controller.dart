import 'package:flutter/material.dart';
import '../../core/tts/tts_service.dart';
import '../../data/services/vision_api.dart';

class CaptionController extends ChangeNotifier {
  final VisionApi api;
  final TtsService tts;

  bool loading = false;
  String caption = "";

  CaptionController(this.api, this.tts);

  Future<void> runCaption(String filePath) async {
    loading = true;
    notifyListeners();
    try {
      final res = await api.caption(filePath);
      caption = res.caption;
      await tts.speak(caption);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}