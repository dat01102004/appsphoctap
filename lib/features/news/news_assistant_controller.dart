import 'package:flutter/material.dart';

import '../../core/errors/error_utils.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/news_models.dart';
import '../../data/services/news_api.dart';
import '../../data/services/read_api.dart';
import '../voice/voice_controller.dart';

enum NewsStage { idle, listing, waitingChoice, reading }

class NewsAssistantController extends ChangeNotifier {
  final NewsApi newsApi;
  final ReadApi readApi;
  final TtsService tts;
  final VoiceController voice;

  NewsStage stage = NewsStage.idle;
  List<NewsItem> items = [];

  NewsAssistantController(this.newsApi, this.readApi, this.tts, this.voice);

  bool get active => stage != NewsStage.idle;

  Future<void> startTop() async {
    stage = NewsStage.listing;
    notifyListeners();

    try {
      items = await newsApi.top(limit: 6);
      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak("Mình chưa lấy được tin mới. Bạn thử lại sau nhé.");
        return;
      }

      await _speakHeadlines();
      await _askChoice();
    } catch (e) {
      stage = NewsStage.idle;
      notifyListeners();
      await tts.speak(ErrorUtils.message(e));
    }
  }

  Future<void> startSearch(String q) async {
    stage = NewsStage.listing;
    notifyListeners();

    try {
      items = await newsApi.search(q, limit: 6);
      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak("Mình không thấy tin phù hợp. Bạn thử nói chủ đề khác nhé.");
        return;
      }

      await tts.speak("Ok, mình tìm tin về $q.");
      await _speakHeadlines();
      await _askChoice();
    } catch (e) {
      stage = NewsStage.idle;
      notifyListeners();
      await tts.speak(ErrorUtils.message(e));
    }
  }

  Future<void> stop() async {
    stage = NewsStage.idle;
    items = [];
    notifyListeners();
    await voice.stop();
    await tts.speak("Ok, mình dừng đọc báo nhé.");
  }

  Future<void> _speakHeadlines() async {
    // đọc tiêu đề dạng 1..6, có nguồn
    final lines = <String>[];
    for (int i = 0; i < items.length; i++) {
      final title = _short(items[i].title, 95);
      final src = (items[i].source != null && items[i].source!.isNotEmpty) ? " (${items[i].source})" : "";
      lines.add("${i + 1}. $title$src");
    }

    await tts.speak("Mình có ${items.length} tin mới. " + lines.join(". "));
  }

  Future<void> _askChoice() async {
    stage = NewsStage.waitingChoice;
    notifyListeners();

    await tts.speak("Bạn muốn nghe bài số mấy? Bạn có thể nói: bài 1, bài 2... hoặc nói: đọc lại danh sách, hoặc thoát.");
    await _listenChoice();
  }

  Future<void> _listenChoice() async {
    await voice.stop(); // tránh dính TTS
    await voice.start(onFinal: (text) async {
      final ok = await handleUtterance(text);
      if (!ok && stage == NewsStage.waitingChoice) {
        await tts.speak("Mình chưa hiểu. Bạn nói lại số bài nhé.");
        await _listenChoice();
      }
    });
  }

  /// Trả true nếu câu nói thuộc chế độ đọc báo và đã xử lý.
  Future<bool> handleUtterance(String raw) async {
    if (!active) return false;

    final text = raw.toLowerCase().trim();
    if (text.isEmpty) return true; // đã vào mode thì coi như handled

    if (text.contains("thoát") || text.contains("dừng") || text.contains("kết thúc")) {
      await stop();
      return true;
    }

    if (text.contains("đọc lại") || text.contains("danh sách")) {
      await _speakHeadlines();
      await _askChoice();
      return true;
    }

    // chọn bài theo số
    if (stage == NewsStage.waitingChoice) {
      final idx = _parseIndex(text);
      if (idx == null) return false;
      if (idx < 1 || idx > items.length) return false;

      await _readArticle(idx - 1);
      return true;
    }

    return false;
  }
  Future<void> readIndex(int i) async {
    if (i < 0 || i >= items.length) return;
    await _readArticle(i);
  }
  Future<void> _readArticle(int i) async {
    stage = NewsStage.reading;
    notifyListeners();

    try {
      final url = items[i].link;
      await tts.speak("Ok, mình tóm tắt bài số ${i + 1}.");

      final res = await readApi.readUrl(url, summary: true);

      // Ưu tiên summary_tts, fallback summary, fallback tts_text, fallback text
      final speakText = (res.summaryTts != null && res.summaryTts!.trim().isNotEmpty)
          ? res.summaryTts!
          : (res.summary != null && res.summary!.trim().isNotEmpty)
          ? res.summary!
          : (res.ttsText != null && res.ttsText!.trim().isNotEmpty)
          ? res.ttsText!
          : res.text;

      await tts.speak(speakText);

      stage = NewsStage.waitingChoice;
      notifyListeners();

      await tts.speak("Bạn muốn nghe bài khác không? Nếu có, nói số bài. Nếu không, nói thoát.");
      await _listenChoice();
    } catch (e) {
      stage = NewsStage.waitingChoice;
      notifyListeners();
      await tts.speak("Có lỗi khi đọc bài. " + ErrorUtils.message(e));
      await _listenChoice();
    }
  }

  int? _parseIndex(String text) {
    // bắt số: "bài 2", "số 3", "2"
    final m = RegExp(r'(\d+)').firstMatch(text);
    if (m != null) return int.tryParse(m.group(1)!);

    // bắt chữ số VN cơ bản (1..6)
    const map = {
      "một": 1,
      "hai": 2,
      "ba": 3,
      "bốn": 4,
      "tư": 4,
      "năm": 5,
      "sáu": 6,
    };
    for (final e in map.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return null;
  }

  String _short(String s, int n) => s.length <= n ? s : "${s.substring(0, n).trim()}...";
}