import 'package:flutter/material.dart';

import '../../core/errors/error_utils.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/news_models.dart';
import '../../data/models/read_url_models.dart';
import '../../data/services/news_api.dart';
import '../../data/services/read_api.dart';
import '../voice/voice_controller.dart';
import 'news_article_payload.dart';

typedef OpenNewsArticle = Future<dynamic> Function(NewsArticlePayload article);
typedef OnHistorySaved = Future<void> Function(int historyId);
enum NewsStage {
  idle,
  listing,
  waitingChoice,
  reading,
  waitingNextAction,
}

enum AppVoiceIntent {
  home,
  ocr,
  caption,
  history,
  tasks,
  settings,
  camera,
  stop,
}

typedef HandleAppVoiceIntent = Future<void> Function(AppVoiceIntent intent);

class NewsAssistantController extends ChangeNotifier {
  final NewsApi newsApi;
  final ReadApi readApi;
  final TtsService tts;
  final VoiceController voice;

  OnHistorySaved? _onHistorySaved;
  NewsStage stage = NewsStage.idle;
  List<NewsItem> items = [];
  bool micArmed = false;

  String _lastPromptNorm = '';
  bool _openingArticle = false;
  int _listenEpoch = 0;

  OpenNewsArticle? _openArticle;
  HandleAppVoiceIntent? _onAppIntent;

  NewsAssistantController(
      this.newsApi,
      this.readApi,
      this.tts,
      this.voice,
      );

  bool get active => stage != NewsStage.idle;

  void bindOnHistorySaved(OnHistorySaved callback) {
    _onHistorySaved = callback;
  }

  void unbindOnHistorySaved() {
    _onHistorySaved = null;
  }
  void bindOpenArticle(OpenNewsArticle callback) {
    _openArticle = callback;
  }

  void unbindOpenArticle() {
    _openArticle = null;
  }

  void bindAppIntentHandler(HandleAppVoiceIntent callback) {
    _onAppIntent = callback;
  }

  void unbindAppIntentHandler() {
    _onAppIntent = null;
  }

  String displayTitle(NewsItem item) {
    return _cleanHeadline(item.title, item.source);
  }

  Future<void> startTop() async {
    stage = NewsStage.listing;
    micArmed = false;
    notifyListeners();

    try {
      _invalidateListening();
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
      _invalidateListening();
      await voice.stop();
      await tts.stop();

      items = await newsApi.search(q, limit: 6);
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 120));

      if (items.isEmpty) {
        stage = NewsStage.idle;
        notifyListeners();
        await tts.speak('Mình không thấy tin phù hợp. Bạn thử nói chủ đề khác nhé.');
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
    _invalidateListening();
    stage = NewsStage.idle;
    items = [];
    micArmed = false;
    _openingArticle = false;
    notifyListeners();

    await voice.stop();
    await tts.stop();
    await tts.speak('Ok, mình dừng đọc báo nhé.');
  }

  void _invalidateListening() {
    _listenEpoch++;
  }

  Future<void> _promptAndListen({
    required String prompt,
    required NewsStage expectedStage,
    required Future<void> Function(int epoch) listenFn,
    int settleMs = 1200,
  }) async {
    final int epoch = ++_listenEpoch;

    micArmed = false;
    notifyListeners();

    await voice.stop();
    await tts.stop();

    _lastPromptNorm = _norm(prompt);
    await tts.speak(prompt);

    await Future.delayed(Duration(milliseconds: settleMs));

    if (epoch != _listenEpoch) return;
    if (stage != expectedStage) return;

    await listenFn(epoch);
  }

  Future<void> _speakHeadlinesAndThenListen() async {
    await _speakHeadlines();

    stage = NewsStage.waitingChoice;
    micArmed = false;
    notifyListeners();

    await _promptAndListen(
      prompt:
      'Bạn muốn nghe bài số mấy? Bạn có thể nói: bài 1, bài 2, đọc lại danh sách, hoặc thoát.',
      expectedStage: NewsStage.waitingChoice,
      listenFn: _listenChoiceWithEpoch,
      settleMs: 1300,
    );
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

  Future<void> onArticleFinished() async {
    stage = NewsStage.waitingNextAction;
    micArmed = false;
    notifyListeners();

    await _promptAndListen(
      prompt:
      'Bạn muốn làm gì tiếp theo? Bạn có thể nói: bài 1, đọc lại danh sách, quét chữ, mô tả ảnh, lịch sử, tác vụ, cài đặt, camera, trang chủ hoặc thoát.',
      expectedStage: NewsStage.waitingNextAction,
      listenFn: _listenNextActionWithEpoch,
      settleMs: 1500,
    );
  }

  Future<void> listenForCurrentStage({bool force = false}) async {
    if (voice.isListening) {
      await voice.stop();
      return;
    }

    if (force) {
      if (stage == NewsStage.waitingChoice) {
        final epoch = ++_listenEpoch;
        await _listenChoiceWithEpoch(epoch);
        return;
      }

      if (stage == NewsStage.waitingNextAction) {
        final epoch = ++_listenEpoch;
        await _listenNextActionWithEpoch(epoch);
        return;
      }
    }

    if (stage == NewsStage.waitingChoice) {
      await _promptAndListen(
        prompt:
        'Bạn muốn nghe bài số mấy? Bạn có thể nói: bài 1, bài 2, đọc lại danh sách, hoặc thoát.',
        expectedStage: NewsStage.waitingChoice,
        listenFn: _listenChoiceWithEpoch,
      );
      return;
    }

    if (stage == NewsStage.waitingNextAction) {
      await _promptAndListen(
        prompt:
        'Bạn muốn làm gì tiếp theo? Bạn có thể nói: bài 1, đọc lại danh sách, quét chữ, mô tả ảnh, lịch sử, tác vụ, cài đặt, camera, trang chủ hoặc thoát.',
        expectedStage: NewsStage.waitingNextAction,
        listenFn: _listenNextActionWithEpoch,
      );
    }
  }

  Future<void> _listenChoiceWithEpoch(int epoch) async {
    if (epoch != _listenEpoch) return;
    if (stage != NewsStage.waitingChoice) return;

    micArmed = true;
    notifyListeners();

    await voice.stop();

    await voice.start(
      onFinal: (text) async {
        if (epoch != _listenEpoch) return;
        if (stage != NewsStage.waitingChoice) return;

        final raw = text.trim();
        final n = _norm(raw);

        if (n.isEmpty || n.length < 2) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (epoch == _listenEpoch && stage == NewsStage.waitingChoice) {
            await _listenChoiceWithEpoch(epoch);
          }
          return;
        }

        if (_isEchoFromTts(n)) {
          await Future.delayed(const Duration(milliseconds: 450));
          if (epoch == _listenEpoch && stage == NewsStage.waitingChoice) {
            await _listenChoiceWithEpoch(epoch);
          }
          return;
        }

        final ok = await handleUtterance(raw);

        if (!ok && epoch == _listenEpoch && stage == NewsStage.waitingChoice) {
          await tts.speak('Mình chưa hiểu. Bạn nói số bài nhé.');
          await Future.delayed(const Duration(milliseconds: 500));
          if (epoch == _listenEpoch && stage == NewsStage.waitingChoice) {
            await _listenChoiceWithEpoch(epoch);
          }
        }
      },
    );
  }

  Future<void> _listenNextActionWithEpoch(int epoch) async {
    if (epoch != _listenEpoch) return;
    if (stage != NewsStage.waitingNextAction) return;

    micArmed = true;
    notifyListeners();

    await voice.stop();

    await voice.start(
      onFinal: (text) async {
        if (epoch != _listenEpoch) return;
        if (stage != NewsStage.waitingNextAction) return;

        final raw = text.trim();
        final n = _norm(raw);

        if (n.isEmpty || n.length < 2) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (epoch == _listenEpoch && stage == NewsStage.waitingNextAction) {
            await _listenNextActionWithEpoch(epoch);
          }
          return;
        }

        if (_isEchoFromTts(n)) {
          await Future.delayed(const Duration(milliseconds: 450));
          if (epoch == _listenEpoch && stage == NewsStage.waitingNextAction) {
            await _listenNextActionWithEpoch(epoch);
          }
          return;
        }

        final ok = await handleUtterance(raw);

        if (!ok &&
            epoch == _listenEpoch &&
            stage == NewsStage.waitingNextAction) {
          await tts.speak(
            'Mình chưa hiểu. Bạn có thể nói quét chữ, mô tả ảnh, lịch sử, tác vụ, cài đặt, camera, trang chủ hoặc bài 1.',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (epoch == _listenEpoch && stage == NewsStage.waitingNextAction) {
            await _listenNextActionWithEpoch(epoch);
          }
        }
      },
    );
  }

  bool _isEchoFromTts(String n) {
    if (_lastPromptNorm.isEmpty) return false;

    if (n.contains('ban muon nghe bai so may')) return true;
    if (n.contains('ban muon lam gi tiep theo')) return true;
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

    final idx = _parseIndex(normalized);
    if (idx != null && idx >= 1 && idx <= items.length) {
      await _readArticle(idx - 1);
      return true;
    }

    final appIntent = _parseAppIntent(normalized);
    if (appIntent != null) {
      _invalidateListening();
      await voice.stop();
      await tts.stop();

      switch (appIntent) {
        case AppVoiceIntent.ocr:
          await tts.speak('Ok, mình chuyển sang quét chữ.');
          break;
        case AppVoiceIntent.caption:
          await tts.speak('Ok, mình chuyển sang mô tả ảnh.');
          break;
        case AppVoiceIntent.history:
          await tts.speak('Ok, mình mở lịch sử.');
          break;
        case AppVoiceIntent.tasks:
          await tts.speak('Ok, mình mở tác vụ.');
          break;
        case AppVoiceIntent.settings:
          await tts.speak('Ok, mình mở cài đặt.');
          break;
        case AppVoiceIntent.home:
          await tts.speak('Ok, mình về trang chủ.');
          break;
        case AppVoiceIntent.camera:
          await tts.speak('Ok, mình mở camera.');
          break;
        case AppVoiceIntent.stop:
          await stop();
          return true;
      }

      if (_onAppIntent != null) {
        await _onAppIntent!(appIntent);
      }
      return true;
    }

    return false;
  }

  AppVoiceIntent? _parseAppIntent(String n) {
    if (n.contains('quet chu') || n.contains('ocr') || n.contains('o c r')) {
      return AppVoiceIntent.ocr;
    }
    if (n.contains('mo ta anh') || n.contains('caption')) {
      return AppVoiceIntent.caption;
    }
    if (n.contains('lich su')) {
      return AppVoiceIntent.history;
    }
    if (n.contains('tac vu')) {
      return AppVoiceIntent.tasks;
    }
    if (n.contains('cai dat')) {
      return AppVoiceIntent.settings;
    }
    if (n.contains('trang chu') || n == 'home') {
      return AppVoiceIntent.home;
    }
    if (n.contains('camera') || n.contains('chup nhanh') || n.contains('chup')) {
      return AppVoiceIntent.camera;
    }
    return null;
  }

  Future<void> readIndex(int i) async {
    if (i < 0 || i >= items.length) return;
    await _readArticle(i);
  }

  Future<void> _readArticle(int i) async {
    if (_openingArticle) return;

    _openingArticle = true;
    _invalidateListening();

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
      if (res.historyId != null && _onHistorySaved != null) {
        await _onHistorySaved!(res.historyId!);
      }

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
        await onArticleFinished();
      }
    } catch (e) {
      stage = NewsStage.waitingChoice;
      micArmed = false;
      notifyListeners();

      await tts.speak('Có lỗi khi mở bài. ${ErrorUtils.message(e)}');
      await Future.delayed(const Duration(milliseconds: 600));

      if (stage == NewsStage.waitingChoice) {
        await _promptAndListen(
          prompt:
          'Bạn muốn nghe bài số mấy? Bạn có thể nói: bài 1, bài 2, đọc lại danh sách, hoặc thoát.',
          expectedStage: NewsStage.waitingChoice,
          listenFn: _listenChoiceWithEpoch,
          settleMs: 1300,
        );
      }
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
        RegExp(r'\s*[-–—|•]\s*' + escaped + r'\s*$', caseSensitive: false),
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