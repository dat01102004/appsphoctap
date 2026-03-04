import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/tts/tts_service.dart';

class VisionResultScreen extends StatefulWidget {
  final String title;
  final String content;
  final String? imagePath;
  final bool autoSpeak;

  const VisionResultScreen({
    super.key,
    required this.title,
    required this.content,
    this.imagePath,
    this.autoSpeak = true,
  });

  @override
  State<VisionResultScreen> createState() => _VisionResultScreenState();
}

class _VisionResultScreenState extends State<VisionResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoSpeak) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TtsService>().speak(widget.content);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                widget.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                widget.content.isEmpty ? "(Trống)" : widget.content,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => tts.speak(widget.content),
                  icon: const Icon(Icons.volume_up),
                  label: const Text("Đọc"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.content));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Đã copy nội dung")),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => tts.stop(),
            icon: const Icon(Icons.stop),
            label: const Text("Dừng đọc"),
          ),
        ],
      ),
    );
  }
}