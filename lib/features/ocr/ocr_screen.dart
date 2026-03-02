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
    context.read<TtsService>().speak("Màn hình OCR. Chọn ảnh để trích xuất văn bản.");
  }

  Future<void> pickAndOcr() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    await context.read<OcrController>().runOcr(img.path);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OcrController>();

    return Scaffold(
      appBar: AppBar(title: const Text("OCR ảnh")),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: c.loading ? null : pickAndOcr,
                  child: const Text("Chọn ảnh & OCR"),
                ),
              ),
              const SizedBox(height: 12),
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