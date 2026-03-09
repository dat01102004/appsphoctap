import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/app_icon.dart';
import '../../data/services/read_api.dart';
import '../voice/voice_controller.dart';
import 'news_article_payload.dart';
import 'news_article_screen.dart';
import 'news_assistant_controller.dart';

class NewsAssistantScreen extends StatefulWidget {
  final String? initialQuery;

  const NewsAssistantScreen({
    super.key,
    this.initialQuery,
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
    _q.text = widget.initialQuery ?? "";

    _news.bindOpenArticle(_openArticle);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if ((widget.initialQuery ?? "").trim().isNotEmpty) {
        await _news.startSearch(widget.initialQuery!.trim());
      } else {
        await _news.startTop();
      }
    });
  }

  @override
  void dispose() {
    _news.unbindOpenArticle();
    _q.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _openArticle(NewsArticlePayload article) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsArticleScreen(article: article),
      ),
    );
  }

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();
    final news = context.read<NewsAssistantController>();

    if (voice.isListening) {
      await voice.stop();
      return;
    }

    await tts.speak(
      "Bạn muốn làm gì? Bạn có thể nói: bài 1, bài 2, đọc lại danh sách, hoặc thoát.",
    );

    await voice.start(
      onFinal: (text) async {
        final handled = await news.handleUtterance(text);
        if (!handled) {
          await tts.speak("Mình chưa hiểu. Bạn nói: bài số mấy, hoặc đọc lại danh sách.");
        }
      },
    );
  }

  Future<void> _search() async {
    final news = context.read<NewsAssistantController>();
    final tts = context.read<TtsService>();
    final q = _q.text.trim();

    if (q.isEmpty) {
      await tts.speak("Bạn nhập chủ đề trước nhé.");
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
      await tts.speak("Bạn dán URL trước nhé.");
      return;
    }

    try {
      await tts.speak("Ok, mình tóm tắt bài viết.");
      final api = context.read<ReadApi>();
      final res = await api.readUrl(url, summary: true);

      final speakText = (res.summary ?? "").trim().isNotEmpty
          ? res.summary!
          : (res.summaryTts ?? "").trim().isNotEmpty
          ? res.summaryTts!
          : (res.ttsText ?? "").trim().isNotEmpty
          ? res.ttsText!
          : res.text;

      await tts.speak(speakText);
    } catch (_) {
      await tts.speak("Có lỗi khi đọc URL.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsAssistantController>();
    final voice = context.watch<VoiceController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trợ lý đọc báo"),
        actions: [
          IconButton(
            onPressed: _toggleMic,
            icon: Icon(
              voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
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
                      label: const Text("Tin mới"),
                      selected: _tab == 0,
                      onSelected: (_) => setState(() => _tab = 0),
                      selectedColor: AppColors.cardStroke.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Dán URL"),
                      selected: _tab == 1,
                      onSelected: (_) => setState(() => _tab = 1),
                      selectedColor: AppColors.cardStroke.withOpacity(0.55),
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
                          hintText: "Tìm tin theo chủ đề (VD: bóng đá, kinh tế...)",
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.cardStroke.withOpacity(0.7),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.cardStroke.withOpacity(0.7),
                            ),
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: "Tìm",
                      onPressed: _search,
                      icon: const Icon(Icons.send_rounded),
                    ),
                    IconButton(
                      tooltip: "Tin mới",
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
                                ? "Đang nghe: ${voice.lastWords}"
                                : "Gợi ý: nói “bài 1”, “đọc lại danh sách”, “thoát”",
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
                    final subtitleParts = <String>[
                      if ((it.source ?? "").trim().isNotEmpty) it.source!,
                      if ((it.published ?? "").trim().isNotEmpty) it.published!,
                    ];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                          AppColors.cardStroke.withOpacity(0.5),
                          child: Text(
                            "${i + 1}",
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          news.displayTitle(it),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(subtitleParts.join(" • ")),
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
                              "Dán URL",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _url,
                              decoration: InputDecoration(
                                hintText: "https://...",
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
                                label: const Text("Tóm tắt & Đọc"),
                              ),
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
    );
  }
}