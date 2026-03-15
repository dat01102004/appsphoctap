import 'package:flutter/material.dart';

import '../../core/tts/tts_service.dart';
import '../../data/services/vision_api.dart';

class CaptionController extends ChangeNotifier {
  final VisionApi api;
  final TtsService tts;

  bool loading = false;
  String caption = "";
  String imagePath = "";
  int? historyId;

  CaptionController(this.api, this.tts);

  Future<dynamic> runCaption(
      String filePath, {
        bool speakResult = false,
      }) async {
    loading = true;
    notifyListeners();

    try {
      final res = await api.caption(filePath);
      imagePath = filePath;
      caption = (res.caption ?? "").trim();
      historyId = res.historyId;

      if (speakResult) {
        final value = caption.trim().isEmpty
            ? "Mình chưa mô tả được ảnh rõ ràng."
            : caption;
        await tts.speak(value);
      }

      return res;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    caption = "";
    imagePath = "";
    historyId = null;
    notifyListeners();
  }
}