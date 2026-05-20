import 'package:flutter/material.dart';

import '../../core/errors/error_utils.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/ocr_models.dart';
import '../../data/services/vision_api.dart';

class OcrController extends ChangeNotifier {
  final VisionApi api;
  final TtsService tts;

  bool loading = false;
  String text = "";
  String imagePath = "";
  String? errorMessage;
  int? historyId;

  OcrController(this.api, this.tts);

  Future<OcrResponse> runOcr(
    String filePath, {
    bool speakResult = false,
  }) async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final res = await api.ocr(filePath);
      imagePath = filePath;
      text = (res.text).trim();
      historyId = res.historyId;

      if (speakResult) {
        final value = text.trim().isEmpty
            ? "Mình chưa nhận diện được văn bản rõ ràng."
            : text;
        await tts.speak(value);
      }

      return res;
    } catch (e) {
      final message = friendlyApiMessage(e, feature: 'ocr');
      errorMessage = message;
      notifyListeners();
      await tts.speak(message);
      throw FriendlyError(message);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    text = "";
    imagePath = "";
    errorMessage = null;
    historyId = null;
    notifyListeners();
  }
}
