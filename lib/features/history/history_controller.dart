import 'package:flutter/material.dart';

import '../../core/tts/tts_service.dart';
import '../../data/models/history_models.dart';
import '../../data/services/history_api.dart';

class HistoryController extends ChangeNotifier {
  final HistoryApi api;
  final TtsService tts;

  bool loading = false;
  List<HistoryItem> items = [];

  HistoryController(this.api, this.tts);

  Future<void> load({
    String? type,
    bool announce = false,
  }) async {
    loading = true;
    notifyListeners();

    try {
      items = await api.list(type: type, limit: 100);
      if (announce) {
        await tts.speak("Đã tải lịch sử.");
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reloadReadUrl() async {
    await load(type: "read_url", announce: false);
  }

  Future<void> speakItem(String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      await tts.speak("Mục lịch sử này chưa có nội dung.");
      return;
    }
    await tts.speak(value);
  }

  Future<void> remove(int id) async {
    await api.delete(id);
    items.removeWhere((e) => e.id == id);
    notifyListeners();
    await tts.speak("Đã xoá mục lịch sử.");
  }
}