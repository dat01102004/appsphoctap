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
            "Bạn có thể nói: quét chữ, mô tả ảnh, đọc web, lịch sử, cài đặt, tác vụ, chụp nhanh.",
      );

      // Sau khi chào thì tự bắt đầu nghe 1 lượt
      await _startVoiceOnce();
    });
  }

  Future<void> _startVoiceOnce() async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();

    await voice.start(onFinal: (text) async {
      if (text.isEmpty) {
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

    // tránh nghe lại chính tiếng TTS
    await voice.stop();

    final text = raw.toLowerCase();

    // Điều hướng tab
    if (text.contains("lịch sử")) {
      setState(() => _index = 1);
      return tts.speak("Mở lịch sử.");
    }
    if (text.contains("tác vụ")) {
      setState(() => _index = 2);
      return tts.speak("Mở tác vụ.");
    }
    if (text.contains("cài đặt") || text.contains("setting")) {
      setState(() => _index = 3);
      return tts.speak("Mở cài đặt.");
    }
    if (text.contains("home") || text.contains("trang chủ")) {
      setState(() => _index = 0);
      return tts.speak("Về trang chủ.");
    }

    // Mở màn chức năng
    if (text.contains("quét") || text.contains("o c r") || text.contains("ocr")) {
      tts.speak("Mở quét chữ.");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen()));
      return;
    }

    if (text.contains("mô tả") || text.contains("caption")) {
      tts.speak("Mở mô tả ảnh.");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen()));
      return;
    }

    if (text.contains("đọc web") || text.contains("url") || text.contains("đọc u r l")) {
      tts.speak("Mở đọc web. Bạn dán URL rồi nhấn đọc nhé.");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadUrlScreen()));
      return;
    }

    if (text.contains("chụp") || text.contains("camera")) {
      tts.speak("Mở camera.");
      return _onCameraPressed();
    }

    await tts.speak("Mình chưa hiểu lệnh. Bạn thử nói: quét chữ, mô tả ảnh, đọc web, hoặc chụp nhanh.");
    return _startVoiceOnce();
  }

  Future<void> _onCameraPressed() async {
    // ✅ Bấm là mở camera ngay
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      final msg = "Bạn cần cấp quyền camera để chụp ảnh.";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return context.read<TtsService>().speak(msg);
    }

    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (img == null) return;

    // Sau khi chụp xong mới hỏi chọn OCR/Caption
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
          MaterialPageRoute(builder: (_) => VisionResultScreen(title: "Kết quả OCR", content: res.text)),
        );
      } else {
        final res = await api.caption(path);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VisionResultScreen(title: "Kết quả mô tả ảnh", content: res.caption)),
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
      HomeTab(onOpenCameraSheet: _onCameraPressed), // ✅ tile “Chụp nhanh” cũng mở camera ngay
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
        width: 70, // ✅ lớn hơn chút
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6),
          ),
          child: FloatingActionButton(
            backgroundColor: AppColors.brandBrown,
            onPressed: _onCameraPressed, // ✅ bấm là mở camera ngay
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
}