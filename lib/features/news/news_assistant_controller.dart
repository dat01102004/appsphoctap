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

  // ✅ UI: hiển thị "Mic đang nghe" ngay sau khi đọc xong câu hỏi
  bool micArmed = false; // true = chuẩn bị/đang nghe lựa chọn
  String _lastPromptNorm = "";

  NewsAssistantController(this.newsApi, this.readApi, this.tts, this.voice);

  bool get active => stage != NewsStage.idle;

  Future<void> startTop() async {
    stage = NewsStage.listing;
    micArmed = false;
    notifyListeners();

    try {
      items = await newsApi.top(limit: 6);

      // ✅ render list ngay
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 120));

      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak("Mình chưa lấy được tin mới. Bạn thử lại sau nhé.");
        return;
      }

      await _speakHeadlinesAndThenListen();
    } catch (e) {
      stage = NewsStage.idle;
      notifyListeners();
      await tts.speak(ErrorUtils.message(e));
    }
  }

  Future<void> startSearch(String q) async {
    stage = NewsStage.listing;
    micArmed = false;
    notifyListeners();

    try {
      items = await newsApi.search(q, limit: 6);

      // ✅ render list ngay
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 120));

      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak("Mình không thấy tin phù hợp. Bạn thử nói chủ đề khác nhé.");
        return;
      }

      await tts.speak("Ok, mình tìm tin về $q.");
      await _speakHeadlinesAndThenListen();
    } catch (e) {
      stage = NewsStage.idle;
      notifyListeners();
      await tts.speak(ErrorUtils.message(e));
    }
  }

  Future<void> stop() async {
    stage = NewsStage.idle;
    items = [];
    micArmed = false;
    notifyListeners();
    await voice.stop();
    await tts.speak("Ok, mình dừng đọc báo nhé.");
  }

  // =============================
  // MAIN FLOW: đọc headlines -> hỏi -> bật nghe
  // =============================
  Future<void> _speakHeadlinesAndThenListen() async {
    // 1) Đọc 6 tiêu đề
    await _speakHeadlines();

    // 2) Hỏi chọn bài
    stage = NewsStage.waitingChoice;
    micArmed = true; // ✅ UI thể hiện mic sẽ nghe ngay sau câu hỏi
    notifyListeners();

    final prompt =
        "Bạn muốn nghe bài số mấy? Bạn có thể nói: bài 1, bài 2... hoặc nói: đọc lại danh sách, hoặc thoát.";

    _lastPromptNorm = _norm(prompt);

    await tts.speak(prompt);

    // 3) Sau khi TTS nói xong -> bật nghe ngay
    // (đợi chút để tránh echo)
    await Future.delayed(const Duration(milliseconds: 500));
    await _listenChoice();
  }

  Future<void> _speakHeadlines() async {
    final lines = <String>[];
    for (int i = 0; i < items.length; i++) {
      final title = _short(items[i].title, 95);
      final src = (items[i].source != null && items[i].source!.isNotEmpty)
          ? " (${items[i].source})"
          : "";
      lines.add("${i + 1}. $title$src");
    }

    // ✅ nói 1 đoạn dài
    await tts.speak("Mình có ${items.length} tin mới. " + lines.join(". "));
  }

  // =============================
  // LISTEN CHOICE: mic bật -> nghe -> xử lý ngay
  // =============================
  Future<void> _listenChoice() async {
    // đảm bảo mic trạng thái "đang nghe"
    micArmed = true;
    notifyListeners();

    await voice.stop();

    await voice.start(onFinal: (text) async {
      final raw = text.trim();
      final n = _norm(raw);

      // 1) rỗng/quá ngắn: nghe lại, KHÔNG mắng
      if (n.isEmpty || n.length < 2) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (stage == NewsStage.waitingChoice) await _listenChoice();
        return;
      }

      // 2) echo từ TTS: bỏ qua và nghe lại
      if (_isEchoFromTts(n)) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (stage == NewsStage.waitingChoice) await _listenChoice();
        return;
      }

      // 3) xử lý ngay yêu cầu user
      final ok = await handleUtterance(raw);
      if (!ok && stage == NewsStage.waitingChoice) {
        await tts.speak("Mình chưa hiểu. Bạn nói số bài nhé.");
        await Future.delayed(const Duration(milliseconds: 350));
        await _listenChoice();
      }
    });
  }

  bool _isEchoFromTts(String n) {
    if (_lastPromptNorm.isEmpty) return false;

    if (n.contains("ban muon nghe bai so may")) return true;
    if (n.contains("hay noi") && n.contains("bai")) return true;

    if (_lastPromptNorm.contains(n) && n.length > 8) return true;
    if (n.contains("doc lai danh sach")) return false;

    return false;
  }

  // =============================
  // HANDLE UTTERANCE
  // =============================
  Future<bool> handleUtterance(String raw) async {
    if (!active) return false;

    final text = raw.toLowerCase().trim();
    if (text.isEmpty) return true;

    if (text.contains("thoát") || text.contains("dừng") || text.contains("kết thúc")) {
      await stop();
      return true;
    }

    if (text.contains("đọc lại") || text.contains("danh sách")) {
      micArmed = false;
      notifyListeners();

      await _speakHeadlinesAndThenListen();
      return true;
    }

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

  // =============================
  // READ ARTICLE -> summarize -> ask next
  // =============================
  Future<void> _readArticle(int i) async {
    stage = NewsStage.reading;
    micArmed = false;
    notifyListeners();

    try {
      final url = items[i].link;
      _lastPromptNorm = _norm("ok, minh tom tat bai so ${i + 1}");

      await tts.speak("Ok, mình tóm tắt bài số ${i + 1}.");

      final res = await readApi.readUrl(url, summary: true);

      final speakText = (res.summaryTts != null && res.summaryTts!.trim().isNotEmpty)
          ? res.summaryTts!
          : (res.summary != null && res.summary!.trim().isNotEmpty)
          ? res.summary!
          : (res.ttsText != null && res.ttsText!.trim().isNotEmpty)
          ? res.ttsText!
          : res.text;

      await tts.speak(speakText);

      // hỏi tiếp
      stage = NewsStage.waitingChoice;
      micArmed = true;
      notifyListeners();

      final prompt = "Bạn muốn nghe bài khác không? Nếu có, nói số bài. Nếu không, nói thoát.";
      _lastPromptNorm = _norm(prompt);

      await tts.speak(prompt);
      await Future.delayed(const Duration(milliseconds: 500));
      await _listenChoice();
    } catch (e) {
      stage = NewsStage.waitingChoice;
      micArmed = true;
      notifyListeners();

      await tts.speak("Có lỗi khi đọc bài. " + ErrorUtils.message(e));
      await Future.delayed(const Duration(milliseconds: 500));
      await _listenChoice();
    }
  }

  int? _parseIndex(String text) {
    final m = RegExp(r'(\d+)').firstMatch(text);
    if (m != null) return int.tryParse(m.group(1)!);

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

  String _norm(String s) {
    s = s.toLowerCase().trim();
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const without =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], without[i]);
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }
}