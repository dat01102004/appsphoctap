import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/result_card.dart';
import '../../core/tts/tts_service.dart';
import 'read_url_controller.dart';

class ReadUrlScreen extends StatefulWidget {
  const ReadUrlScreen({super.key});

  @override
  State<ReadUrlScreen> createState() => _ReadUrlScreenState();
}

class _ReadUrlScreenState extends State<ReadUrlScreen> {
  final _url = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("Màn hình đọc đường dẫn. Dán link bài viết và bấm đọc.");
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReadUrlController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Đọc URL")),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: "Nhập URL bài viết",
                  hintText: "https://...",
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: c.loading ? null : () async => c.submit(_url.text.trim()),
                  child: const Text("Đọc & Tóm tắt"),
                ),
              ),
              const SizedBox(height: 12),
              if (c.result != null) ...[
                if ((c.result!.summaryTts ?? "").isNotEmpty)
                  ResultCard(
                    title: "Tóm tắt (TTS)",
                    content: c.result!.summaryTts!,
                    onSpeak: () => context.read<TtsService>().speak(c.result!.summaryTts!),
                  ),
                const SizedBox(height: 12),
                ResultCard(
                  title: "Nội dung (TTS)",
                  content: c.result!.ttsText ?? c.result!.text,
                  onSpeak: () => context.read<TtsService>().speak(c.result!.ttsText ?? c.result!.text),
                ),
              ],
            ],
          ),
          LoadingOverlay(show: c.loading),
        ],
      ),
    );
  }
}