import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../../data/services/read_api.dart';
import '../auth/auth_controller.dart';
import '../history/history_controller.dart';
import '../voice/voice_controller.dart';
import 'news_article_payload.dart';
import 'news_article_screen.dart';
import 'news_assistant_controller.dart';

class NewsAssistantScreen extends StatefulWidget {
  final String? initialQuery;
  final Future Function()? onGoHome;
  final Future Function()? onGoHistory;
  final Future Function()? onGoTasks;
  final Future Function()? onGoSettings;
  final Future Function()? onOpenOcr;
  final Future Function()? onOpenCaption;
  final Future Function()? onOpenCamera;

  const NewsAssistantScreen({
    super.key,
    this.initialQuery,
    this.onGoHome,
    this.onGoHistory,
    this.onGoTasks,
    this.onGoSettings,
    this.onOpenOcr,
    this.onOpenCaption,
    this.onOpenCamera,
  });

  @override
  State<NewsAssistantScreen> createState() => _NewsAssistantScreenState();
}

class _NewsAssistantScreenState extends State<NewsAssistantScreen> {
  final _q = TextEditingController();
  final _url = TextEditingController();

  int _tab = 0;

  late final NewsAssistantController _news;

  @override
  void initState() {
    super.initState();
    _news = context.read<NewsAssistantController>();

    _q.text = widget.initialQuery ?? '';

    _news.bindOpenArticle(_openArticle);
    _news.bindAppIntentHandler(_handleAppIntent);
    _news.bindOnHistorySaved(_handleHistorySaved);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if ((widget.initialQuery ?? '').trim().isNotEmpty) {
        await _news.startSearch(widget.initialQuery!.trim());
      } else {
        await _news.startTop();
      }
    });
  }

  @override
  void dispose() {
    _news.unbindOpenArticle();
    _news.unbindAppIntentHandler();
    _news.unbindOnHistorySaved();
    _q.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _openArticle(NewsArticlePayload article) async {
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsArticleScreen(article: article),
      ),
    );

    if (!mounted) return;

    if (result == 'askNextAction' || result == true) {
      await Future.delayed(const Duration(milliseconds: 650));
      await _news.onArticleFinished();
    }
  }

  Future<void> _handleHistorySaved(int historyId) async {
    if (!mounted) return;

    try {
      await context.read<HistoryController>().load(
        type: 'read_url',
        announce: false,
      );
    } catch (_) {}
  }

  Future<void> _popToRoot() async {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await Future.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _handleAppIntent(AppVoiceIntent intent) async {
    if (!mounted) return;

    switch (intent) {
      case AppVoiceIntent.home:
        await _popToRoot();
        if (widget.onGoHome != null) {
          await widget.onGoHome!();
        }
        break;
      case AppVoiceIntent.history:
        await _popToRoot();
        if (widget.onGoHistory != null) {
          await widget.onGoHistory!();
        }
        break;
      case AppVoiceIntent.tasks:
        await _popToRoot();
        if (widget.onGoTasks != null) {
          await widget.onGoTasks!();
        }
        break;
      case AppVoiceIntent.settings:
        await _popToRoot();
        if (widget.onGoSettings != null) {
          await widget.onGoSettings!();
        }
        break;
      case AppVoiceIntent.ocr:
        await _popToRoot();
        if (widget.onOpenOcr != null) {
          await widget.onOpenOcr!();
        }
        break;
      case AppVoiceIntent.caption:
        await _popToRoot();
        if (widget.onOpenCaption != null) {
          await widget.onOpenCaption!();
        }
        break;
      case AppVoiceIntent.camera:
        await _popToRoot();
        if (widget.onOpenCamera != null) {
          await widget.onOpenCamera!();
        }
        break;
      case AppVoiceIntent.stop:
        break;
    }
  }

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceController>();
    if (voice.isListening) {
      await voice.stop();
      return;
    }
    await _news.listenForCurrentStage(force: true);
  }

  Future<void> _onHoldToListen() async {
    final voice = context.read<VoiceController>();
    if (voice.isListening) return;
    await _news.listenForCurrentStage(force: true);
  }

  Future<void> _search() async {
    final news = context.read<NewsAssistantController>();
    final tts = context.read<TtsService>();
    final q = _q.text.trim();

    if (q.isEmpty) {
      await tts.speak('Bạn nhập chủ đề trước nhé.');
      return;
    }

    await news.startSearch(q);
  }

  Future<void> _top() async {
    final news = context.read<NewsAssistantController>();
    await news.startTop();
  }

  Future<void> _readUrlManual() async {
    final url = _url.text.trim();
    final tts = context.read<TtsService>();

    if (url.isEmpty) {
      await tts.speak('Bạn dán URL trước nhé.');
      return;
    }

    try {
      await tts.speak('Ok, mình tóm tắt bài viết.');

      final api = context.read<ReadApi>();
      final res = await api.readUrl(url, summary: true);

      final speakText = (res.summary ?? '').trim().isNotEmpty
          ? res.summary!
          : (res.summaryTts ?? '').trim().isNotEmpty
          ? res.summaryTts!
          : (res.ttsText ?? '').trim().isNotEmpty
          ? res.ttsText!
          : res.text;

      await tts.speak(speakText);
    } catch (_) {
      await tts.speak('Có lỗi khi đọc URL.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsAssistantController>();
    final voice = context.watch<VoiceController>();

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _onHoldToListen,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trợ lý đọc báo'),
          actions: [
            IconButton(
              onPressed: _toggleMic,
              icon: Icon(
                voice.isListening
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Tin mới'),
                        selected: _tab == 0,
                        onSelected: (_) => setState(() => _tab = 0),
                        selectedColor:
                        AppColors.cardStroke.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Dán URL'),
                        selected: _tab == 1,
                        onSelected: (_) => setState(() => _tab = 1),
                        selectedColor:
                        AppColors.cardStroke.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (_tab == 0) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _q,
                          decoration: InputDecoration(
                            hintText:
                            'Tìm tin theo chủ đề (VD: bóng đá, kinh tế...)',
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color:
                                AppColors.cardStroke.withValues(alpha: 0.7),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color:
                                AppColors.cardStroke.withValues(alpha: 0.7),
                              ),
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Tìm',
                        onPressed: _search,
                        icon: const Icon(Icons.send_rounded),
                      ),
                      IconButton(
                        tooltip: 'Tin mới',
                        onPressed: _top,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.magic,
                            size: 20,
                            color: AppColors.brandBrown,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              voice.isListening
                                  ? 'Đang nghe: ${voice.lastWords}'
                                  : 'Gợi ý: nói “bài 1”, “đọc lại danh sách”, “quét chữ”, “mô tả ảnh”, “lịch sử”, “tác vụ”, “cài đặt”, “camera”. Hoặc giữ màn hình 2 giây để bật mic.',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: news.items.length,
                    itemBuilder: (_, i) {
                      final it = news.items[i];
                      final subtitleParts = [
                        if ((it.source ?? '').trim().isNotEmpty) it.source!,
                        if ((it.published ?? '').trim().isNotEmpty)
                          it.published!,
                      ];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                            AppColors.cardStroke.withValues(alpha: 0.5),
                            child: Text(
                              '${i + 1}',
                              style:
                              const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(
                            news.displayTitle(it),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: subtitleParts.isEmpty
                              ? null
                              : Text(subtitleParts.join(' • ')),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => news.readIndex(i),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dán URL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _url,
                                decoration: InputDecoration(
                                  hintText: 'https://...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandBrown,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _readUrlManual,
                                  icon: const Icon(Icons.volume_up_rounded),
                                  label: const Text('Tóm tắt & Đọc'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Bạn cũng có thể giữ màn hình 2 giây để bật mic và ra lệnh bằng giọng nói.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}