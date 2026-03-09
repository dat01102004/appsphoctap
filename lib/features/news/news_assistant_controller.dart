import 'package:flutter/material.dart';

import '../../core/errors/error_utils.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/news_models.dart';
import '../../data/models/read_url_models.dart';
import '../../data/services/news_api.dart';
import '../../data/services/read_api.dart';
import '../voice/voice_controller.dart';
import 'news_article_payload.dart';

typedef OpenNewsArticle = Future<void> Function(NewsArticlePayload article);

enum NewsStage { idle, listing, waitingChoice, reading }

class NewsAssistantController extends ChangeNotifier {
  final NewsApi newsApi;
  final ReadApi readApi;
  final TtsService tts;
  final VoiceController voice;

  NewsStage stage = NewsStage.idle;
  List<NewsItem> items = [];

  bool micArmed = false;
  String _lastPromptNorm = '';
  bool _openingArticle = false;

  OpenNewsArticle? _openArticle;

  NewsAssistantController(
      this.newsApi,
      this.readApi,
      this.tts,
      this.voice,
      );

  bool get active => stage != NewsStage.idle;

  void bindOpenArticle(OpenNewsArticle callback) {
    _openArticle = callback;
  }

  void unbindOpenArticle() {
    _openArticle = null;
  }

  String displayTitle(NewsItem item) {
    return _cleanHeadline(item.title, item.source);
  }

  Future<void> startTop() async {
    stage = NewsStage.listing;
    micArmed = false;
    notifyListeners();

    try {
      await voice.stop();
      await tts.stop();

      items = await newsApi.top(limit: 6);
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 120));

      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak('Mình chưa lấy được tin mới. Bạn thử lại sau nhé.');
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
      await voice.stop();
      await tts.stop();

      items = await newsApi.search(q, limit: 6);
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 120));

      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak(
          'Mình không thấy tin phù hợp. Bạn thử nói chủ đề khác nhé.',
        );
        return;
      }

      await tts.speak('Ok, mình tìm tin về $q.');
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
    _openingArticle = false;
    notifyListeners();

    await voice.stop();
    await tts.stop();
    await tts.speak('Ok, mình dừng đọc báo nhé.');
  }

  Future<void> _speakHeadlinesAndThenListen() async {
    await _speakHeadlines();

    stage = NewsStage.waitingChoice;
    micArmed = true;
    notifyListeners();

    const prompt =
        'Bạn muốn nghe bài số mấy? Bạn có thể nói: bài 1, bài 2, đọc lại danh sách, hoặc thoát.';

    _lastPromptNorm = _norm(prompt);
    await tts.speak(prompt);

    await Future.delayed(const Duration(milliseconds: 500));
    await _listenChoice();
  }

  Future<void> _speakHeadlines() async {
    final lines = <String>[];

    for (int i = 0; i < items.length; i++) {
      final cleanTitle = _cleanPlainText(displayTitle(items[i]));
      final shortTitle = _short(cleanTitle, 95);
      lines.add('${i + 1}. $shortTitle');
    }

    await tts.speak('Mình có ${items.length} tin mới. ${lines.join('. ')}');
  }

  Future<void> _listenChoice() async {
    if (stage != NewsStage.waitingChoice) return;

    micArmed = true;
    notifyListeners();

    await voice.stop();

    await voice.start(
      onFinal: (text) async {
        final raw = text.trim();
        final n = _norm(raw);

        if (n.isEmpty || n.length < 2) {
          await Future.delayed(const Duration(milliseconds: 250));
          if (stage == NewsStage.waitingChoice) {
            await _listenChoice();
          }
          return;
        }

        if (_isEchoFromTts(n)) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (stage == NewsStage.waitingChoice) {
            await _listenChoice();
          }
          return;
        }

        final ok = await handleUtterance(raw);

        if (!ok && stage == NewsStage.waitingChoice) {
          await tts.speak('Mình chưa hiểu. Bạn nói số bài nhé.');
          await Future.delayed(const Duration(milliseconds: 350));
          await _listenChoice();
        }
      },
    );
  }

  bool _isEchoFromTts(String n) {
    if (_lastPromptNorm.isEmpty) return false;
    if (n.contains('ban muon nghe bai so may')) return true;
    if (n.contains('hay noi') && n.contains('bai')) return true;
    if (_lastPromptNorm.contains(n) && n.length > 8) return true;
    if (n.contains('doc lai danh sach')) return false;
    return false;
  }

  Future<bool> handleUtterance(String raw) async {
    if (!active) return false;

    final normalized = _norm(raw);
    if (normalized.isEmpty) return true;

    if (normalized.contains('thoat') ||
        normalized.contains('dung') ||
        normalized.contains('ket thuc')) {
      await stop();
      return true;
    }

    if (normalized.contains('doc lai') || normalized.contains('danh sach')) {
      micArmed = false;
      notifyListeners();
      await _speakHeadlinesAndThenListen();
      return true;
    }

    if (stage == NewsStage.waitingChoice) {
      final idx = _parseIndex(normalized);
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
    if (_openingArticle) return;
    _openingArticle = true;

    stage = NewsStage.reading;
    micArmed = false;
    notifyListeners();

    try {
      await voice.stop();
      await tts.stop();

      final item = items[i];
      final fallbackTitle = _cleanPlainText(displayTitle(item));

      await tts.speak('Ok, mình mở bài số ${i + 1}.');

      final ReadUrlResponse res = await readApi.readUrl(
        item.link,
        summary: true,
      );

      final rawTitle = _cleanPlainText((res.title ?? '').trim());
      final finalTitle =
      _shouldUseFallbackTitle(rawTitle) ? fallbackTitle : rawTitle;

      final summaryText = _cleanSummaryText(_pickSummaryText(res));

      if (_looksLikeGoogleNewsBoilerplate(finalTitle, summaryText)) {
        throw Exception('Chưa lấy được nội dung gốc của bài báo này');
      }

      final article = NewsArticlePayload(
        title: finalTitle,
        url: item.link,
        summary: summaryText,
        source: item.source,
        published: item.published,
      );

      if (_openArticle != null) {
        await _openArticle!(article);
      } else {
        await tts.speak(summaryText);
      }

      stage = NewsStage.waitingChoice;
      micArmed = false;
      notifyListeners();
    } catch (e) {
      stage = NewsStage.waitingChoice;
      micArmed = true;
      notifyListeners();

      await tts.speak('Có lỗi khi mở bài. ${ErrorUtils.message(e)}');
      await Future.delayed(const Duration(milliseconds: 500));
      await _listenChoice();
    } finally {
      _openingArticle = false;
    }
  }

  String _pickSummaryText(ReadUrlResponse res) {
    if ((res.summary ?? '').trim().isNotEmpty) {
      return res.summary!.trim();
    }
    if ((res.summaryTts ?? '').trim().isNotEmpty) {
      return res.summaryTts!.trim();
    }
    if ((res.ttsText ?? '').trim().isNotEmpty) {
      return res.ttsText!.trim();
    }
    return res.text.trim();
  }

  bool _shouldUseFallbackTitle(String title) {
    if (title.trim().isEmpty) return true;

    final n = _norm(title);
    return n == 'google news' ||
        n == 'news' ||
        n == 'bai bao' ||
        n == 'tin tuc' ||
        n.contains('google news');
  }

  bool _looksLikeGoogleNewsBoilerplate(String title, String summary) {
    final hay = '$title\n$summary'.toLowerCase();

    const signals = [
      'google news',
      'dịch vụ tập hợp',
      'hàng nghìn nguồn tin',
      'top stories',
      'cập nhật liên tục',
      'cá nhân hóa',
    ];

    int matched = 0;
    for (final s in signals) {
      if (hay.contains(s)) matched++;
    }
    return matched >= 2;
  }

  String _cleanPlainText(String input) {
    var s = input;

    s = s.replaceAll(RegExp(r'\*\*?'), '');
    s = s.replaceAll(RegExp(r'__?'), '');
    s = s.replaceAll(RegExp(r'`+'), '');
    s = s.replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1');
    s = s.replaceAll(RegExp(r'#+\s*'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  String _cleanSummaryText(String input) {
    var s = input;

    s = s.replaceAll(RegExp(r'\r\n'), '\n');
    s = s.replaceAll(RegExp(r'\*\*?'), '');
    s = s.replaceAll(RegExp(r'__?'), '');
    s = s.replaceAll(RegExp(r'`+'), '');
    s = s.replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1');
    s = s.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*[-*•]+\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return s.trim();
  }

  int? _parseIndex(String text) {
    final m = RegExp(r'(\d+)').firstMatch(text);
    if (m != null) return int.tryParse(m.group(1)!);

    const map = {
      'mot': 1,
      'hai': 2,
      'ba': 3,
      'bon': 4,
      'tu': 4,
      'nam': 5,
      'sau': 6,
    };

    for (final e in map.entries) {
      if (text.contains(e.key)) return e.value;
    }

    return null;
  }

  String _cleanHeadline(String raw, String? source) {
    var title = raw.trim();
    final src = (source ?? '').trim();

    if (src.isNotEmpty) {
      final escaped = RegExp.escape(src);

      final patterns = [
        RegExp(
          r'\s*[-–—|•]\s*' + escaped + r'\s*$',
          caseSensitive: false,
        ),
        RegExp(
          r'\s*[-–—|•]\s*Báo điện tử\s+' + escaped + r'\s*$',
          caseSensitive: false,
        ),
        RegExp(
          r'\s*[-–—|•]\s*' + escaped + r'\s*online\s*$',
          caseSensitive: false,
        ),
      ];

      for (final p in patterns) {
        title = title.replaceFirst(p, '').trim();
      }
    }

    final genericSplit = RegExp(r'\s[-–—|•]\s');
    final parts = title.split(genericSplit);

    if (parts.length > 1) {
      final tail = parts.last.trim();

      final looksLikeSource = tail.length <= 24 &&
          !tail.contains(',') &&
          !tail.contains('.') &&
          !tail.contains('?') &&
          !tail.contains('!');

      if (looksLikeSource) {
        title = parts.sublist(0, parts.length - 1).join(' - ').trim();
      }
    }

    return title;
  }

  String _short(String s, int n) {
    return s.length <= n ? s : '${s.substring(0, n).trim()}...';
  }

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