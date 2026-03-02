import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/result_card.dart';
import '../../core/tts/tts_service.dart';
import 'caption_controller.dart';

class CaptionScreen extends StatefulWidget {
  const CaptionScreen({super.key});

  @override
  State<CaptionScreen> createState() => _CaptionScreenState();
}

class _CaptionScreenState extends State<CaptionScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("Màn hình mô tả ảnh. Chọn ảnh để nghe mô tả.");
  }

  Future<void> pickAndCaption() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    await context.read<CaptionController>().runCaption(img.path);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaptionController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Mô tả ảnh")),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: c.loading ? null : pickAndCaption,
                  child: const Text("Chọn ảnh & Mô tả"),
                ),
              ),
              const SizedBox(height: 12),
              ResultCard(
                title: "Kết quả mô tả",
                content: c.caption,
                onSpeak: () => context.read<TtsService>().speak(c.caption),
              ),
            ],
          ),
          LoadingOverlay(show: c.loading),
        ],
      ),
    );
  }
}