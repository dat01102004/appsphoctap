import 'package:flutter/material.dart';
import '../../data/models/history_models.dart';
import '../../data/services/history_api.dart';
import '../../core/tts/tts_service.dart';

class HistoryController extends ChangeNotifier {
  final HistoryApi api;
  final TtsService tts;

  bool loading = false;
  List<HistoryItem> items = [];

  HistoryController(this.api, this.tts);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      items = await api.list(limit: 100);
      await tts.speak("Đã tải lịch sử.");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> remove(int id) async {
    await api.delete(id);
    items.removeWhere((e) => e.id == id);
    notifyListeners();
    await tts.speak("Đã xoá mục lịch sử.");
  }
}