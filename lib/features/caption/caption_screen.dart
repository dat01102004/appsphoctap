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
    context.read<TtsService>().speak("Màn hình mô tả ảnh. Bạn có thể chụp ảnh hoặc chọn ảnh.");
  }

  Future<void> cameraCaption() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (img == null) return;
    await context.read<CaptionController>().runCaption(img.path);
  }

  Future<void> galleryCaption() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
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
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: c.loading ? null : cameraCaption,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Chụp ảnh để mô tả"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: c.loading ? null : galleryCaption,
                  icon: const Icon(Icons.photo),
                  label: const Text("Chọn ảnh từ thư viện"),
                ),
              ),
              const SizedBox(height: 16),
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