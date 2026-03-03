import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../widgets/loading_overlay.dart';
import '../../widgets/result_card.dart';
import '../../core/tts/tts_service.dart';
import 'ocr_controller.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("Màn hình quét chữ. Bạn có thể chụp ảnh hoặc chọn ảnh.");
  }

  Future<void> cameraOcr() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (img == null) return;
    await context.read<OcrController>().runOcr(img.path);
  }

  Future<void> galleryOcr() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (img == null) return;
    await context.read<OcrController>().runOcr(img.path);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OcrController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Quét chữ (OCR)")),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: c.loading ? null : cameraOcr,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Chụp ảnh để quét"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: c.loading ? null : galleryOcr,
                  icon: const Icon(Icons.photo),
                  label: const Text("Chọn ảnh từ thư viện"),
                ),
              ),
              const SizedBox(height: 16),
              ResultCard(
                title: "Kết quả OCR",
                content: c.text,
                onSpeak: () => context.read<TtsService>().speak(c.text),
              ),
            ],
          ),
          LoadingOverlay(show: c.loading),
        ],
      ),
    );
  }
}