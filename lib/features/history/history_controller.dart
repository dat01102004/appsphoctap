import 'package:flutter/material.dart';
import '../../data/models/history_models.dart';
import '../../data/services/history_api.dart';
import '../../core/tts/tts_service.dart';
import '../../core/errors/error_utils.dart';

class HistoryController extends ChangeNotifier {
  final HistoryApi api;
  final TtsService tts;

  bool loading = false;
  List<HistoryItem> items = [];
  String? lastError;

  HistoryController(this.api, this.tts);

  Future<void> load({String? type, int limit = 100}) async {
    if (loading) return; // ✅ đặt ngay đầu hàm

    loading = true;
    lastError = null;
    notifyListeners();

    try {
      items = await api.list(type: type, limit: limit);
    } catch (e) {
      lastError = ErrorUtils.message(e);
      await tts.speak(lastError!);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> remove(int id) async {
    try {
      await api.delete(id);
      items.removeWhere((e) => e.id == id);
      notifyListeners();
      await tts.speak("Đã xoá mục lịch sử.");
    } catch (e) {
      final msg = ErrorUtils.message(e);
      await tts.speak(msg);
    }
  }

  Future<void> speakItem(String text) => tts.speak(text);
}