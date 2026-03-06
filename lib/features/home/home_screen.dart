import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/errors/error_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/app_icon.dart';
import '../../data/services/vision_api.dart';

import '../caption/caption_screen.dart';
import '../news/news_assistant_controller.dart';
import '../news/news_assistant_screen.dart';
import '../ocr/ocr_screen.dart';
import '../read_url/read_url_screen.dart';
import '../vision/vision_result_screen.dart';
import '../voice/voice_controller.dart';

import 'tabs/history_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/tasks_tab.dart';
import 'widgets/talksight_app_bar.dart';
import 'widgets/talksight_bottom_bar.dart';

enum VisionMode { ocr, caption }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();

  int _index = 0;
  bool _loading = false;
  bool _greeted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_greeted) return;
    _greeted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tts = context.read<TtsService>();
      await tts.speak(
        "Xin chào bạn! Hôm nay bạn muốn sử dụng tính năng gì? "
            "Bạn có thể nói: quét chữ, mô tả ảnh, đọc báo, lịch sử, cài đặt, tác vụ, chụp nhanh.",
      );

      await _startVoiceOnce();
    });
  }

  Future<void> _startVoiceOnce() async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();

    // tránh dính TTS
    await Future.delayed(const Duration(milliseconds: 350));

    await voice.start(onFinal: (text) async {
      if (text.trim().isEmpty) {
        await tts.speak("Mình chưa nghe rõ. Bạn nói lại giúp mình nhé.");
        return _startVoiceOnce();
      }
      await _handleVoiceCommand(text);
    });
  }

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceController>();
    if (voice.isListening) {
      await voice.stop();
    } else {
      await _startVoiceOnce();
    }
  }

  Future<void> _handleVoiceCommand(String raw) async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();
    final news = context.read<NewsAssistantController>();

    // Nếu đang ở "chế độ đọc báo" => ưu tiên xử lý chọn bài trước
    final handledByNews = await news.handleUtterance(raw);
    if (handledByNews) return;

    // stop mic trước khi điều hướng
    await voice.stop();

    final text = _norm(raw);

    debugPrint("VOICE RAW: $raw");
    debugPrint("VOICE NORM: $text");

    // ========= 1) ĐỌC BÁO / TIN TỨC =========
    final isNewsCmd =
        text.contains("doc web") ||
            text.contains("doc bao") ||
            text.contains("tin tuc") ||
            text.contains("bao moi") ||
            text.contains("tin moi");

    if (isNewsCmd) {
      final topic = _extractTopic(text);
      await tts.speak("Ok, mình mở trợ lý đọc báo.");
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsAssistantScreen(initialQuery: topic),
        ),
      );
      return;
    }

    // ========= 1.1) ĐỌC URL THỦ CÔNG =========
    if (text.contains("doc url") || text.contains("dan url") || text.contains("doc duong dan")) {
      await tts.speak("Mở đọc URL.");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadUrlScreen()));
      return;
    }

    // ========= 2) ĐIỀU HƯỚNG TAB =========
    if (text.contains("lich su")) {
      setState(() => _index = 1);
      await tts.speak("Mở lịch sử.");
      return;
    }

    if (text.contains("tac vu")) {
      setState(() => _index = 2);
      await tts.speak("Mở tác vụ.");
      return;
    }

    if (text.contains("cai dat") || text.contains("setting")) {
      setState(() => _index = 3);
      await tts.speak("Mở cài đặt.");
      return;
    }

    if (text.contains("home") || text.contains("trang chu")) {
      setState(() => _index = 0);
      await tts.speak("Về trang chủ.");
      return;
    }

    // ========= 3) MỞ CHỨC NĂNG =========
    if (text.contains("quet") || text.contains("o c r") || text.contains("ocr")) {
      await tts.speak("Mở quét chữ.");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen()));
      return;
    }

    // ✅ fix trường hợp bạn nói "mô tả hình ảnh" => STT ra "mo ta hinh anh"
    if (text.contains("mo ta") || text.contains("caption") || text.contains("hinh anh")) {
      await tts.speak("Mở mô tả ảnh.");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen()));
      return;
    }

    if (text.contains("chup") || text.contains("camera")) {
      await tts.speak("Mở camera.");
      await _onCameraPressed();
      return;
    }

    // ========= FALLBACK =========
    await tts.speak("Mình chưa hiểu lệnh. Bạn thử nói: đọc báo, quét chữ, mô tả ảnh, hoặc chụp nhanh.");
    await _startVoiceOnce();
  }

  String? _extractTopic(String text) {
    // text là không dấu
    final idx = text.indexOf("ve ");
    if (idx >= 0) return text.substring(idx + 3).trim();

    if (text.startsWith("doc bao")) return text.replaceFirst("doc bao", "").trim();
    if (text.startsWith("tin tuc")) return text.replaceFirst("tin tuc", "").trim();
    if (text.startsWith("doc web")) return text.replaceFirst("doc web", "").trim();

    return null;
  }

  Future<void> _onCameraPressed() async {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      final msg = "Bạn cần cấp quyền camera để chụp ảnh.";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await context.read<TtsService>().speak(msg);
      return;
    }

    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (img == null) return;

    if (!mounted) return;
    _openAfterShotSheet(img.path);
  }

  void _openAfterShotSheet(String imagePath) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const AppIcon(AppIcons.ocr, size: 24, color: AppColors.brandBrown),
                title: const Text("Quét chữ (OCR)"),
                onTap: () {
                  Navigator.pop(context);
                  _processImage(imagePath, VisionMode.ocr);
                },
              ),
              ListTile(
                leading: const AppIcon(AppIcons.image, size: 24, color: AppColors.brandBrown),
                title: const Text("Mô tả ảnh (Caption)"),
                onTap: () {
                  Navigator.pop(context);
                  _processImage(imagePath, VisionMode.caption);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processImage(String path, VisionMode mode) async {
    setState(() => _loading = true);
    final api = context.read<VisionApi>();
    final tts = context.read<TtsService>();

    try {
      if (mode == VisionMode.ocr) {
        final res = await api.ocr(path);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisionResultScreen(title: "Kết quả OCR", content: res.text),
          ),
        );
      } else {
        final res = await api.caption(path);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisionResultScreen(title: "Kết quả mô tả ảnh", content: res.caption),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      final msg = ErrorUtils.message(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await tts.speak(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();

    final pages = [
      HomeTab(
        onOpenCameraSheet: _onCameraPressed,
        isListening: voice.isListening,
        lastWords: voice.lastWords,
        onMicTap: _toggleMic,
      ),
      const HistoryTab(),
      const TasksTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: TalkSightAppBar(
        isListening: voice.isListening,
        onMicPressed: _toggleMic,
      ),
      body: Stack(
        children: [
          SafeArea(child: IndexedStack(index: _index, children: pages)),
          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 12),
                        Text("Đang xử lý..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6),
          ),
          child: FloatingActionButton(
            backgroundColor: AppColors.brandBrown,
            onPressed: _onCameraPressed,
            child: const AppIcon(AppIcons.camera, color: Colors.white, size: 30),
          ),
        ),
      ),
      bottomNavigationBar: TalkSightBottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }

  // ===== Helpers =====
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