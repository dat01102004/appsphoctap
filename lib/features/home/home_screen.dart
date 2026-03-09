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

// ✅ draggable popup
import '../player/player_controller.dart';
import '../player/player_sliding_panel.dart';

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

  String _lastSpokenText = "";
  String _lastSpokenTitle = "TalkSight";

  VoiceController? _voiceRef;
  bool _voiceListenerAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_voiceListenerAttached) {
      _voiceRef = context.read<VoiceController>();
      _voiceRef!.addListener(_syncVoiceToPlayer);
      _voiceListenerAttached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncVoiceToPlayer());
    }

    if (_greeted) return;
    _greeted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _say(
        "Xin chào bạn! Hôm nay bạn muốn sử dụng tính năng gì? "
            "Bạn có thể nói: quét chữ, mô tả ảnh, đọc báo, lịch sử, cài đặt, tác vụ, chụp nhanh.",
        title: "TalkSight",
      );
      await _startVoiceOnce();
    });
  }

  @override
  void dispose() {
    if (_voiceListenerAttached && _voiceRef != null) {
      _voiceRef!.removeListener(_syncVoiceToPlayer);
    }
    super.dispose();
  }

  void _syncVoiceToPlayer() {
    if (!mounted) return;
    final v = context.read<VoiceController>();
    final pc = context.read<PlayerController>();

    pc.setListening(v.isListening);

    if (v.isListening) {
      final s = v.lastWords.trim().isEmpty ? "Đang nghe..." : "Đang nghe: ${v.lastWords}";
      pc.setNow(_lastSpokenTitle, s);
    } else {
      if (pc.subtitle.startsWith("Đang nghe")) {
        pc.setNow(_lastSpokenTitle, "Sẵn sàng");
      }
    }
  }

  Future<void> _say(String text, {String? title}) async {
    final tts = context.read<TtsService>();
    final pc = context.read<PlayerController>();

    _lastSpokenText = text;
    _lastSpokenTitle = title ?? _lastSpokenTitle;

    final preview = text.length > 80 ? "${text.substring(0, 80)}..." : text;
    pc.setNow(_lastSpokenTitle, preview);
    pc.setPlaying(true);

    try {
      await tts.speak(text);
    } finally {
      pc.setPlaying(false);
      final v = context.read<VoiceController>();
      if (!v.isListening) pc.setNow(_lastSpokenTitle, "Sẵn sàng");
    }
  }

  Future<void> _startVoiceOnce() async {
    final voice = context.read<VoiceController>();

    await Future.delayed(const Duration(milliseconds: 350));

    await voice.start(onFinal: (text) async {
      if (text.trim().isEmpty) {
        await _say("Mình chưa nghe rõ. Bạn nói lại giúp mình nhé.", title: "TalkSight");
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
    final news = context.read<NewsAssistantController>();

    final handledByNews = await news.handleUtterance(raw);
    if (handledByNews) return;

    await voice.stop();

    final text = _norm(raw);

    final isNewsCmd =
        text.contains("doc web") || text.contains("doc bao") || text.contains("tin tuc") || text.contains("bao moi") || text.contains("tin moi");

    if (isNewsCmd) {
      final topic = _extractTopic(text);
      await _say("Ok, mình mở trợ lý đọc báo.", title: "Đọc báo");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => NewsAssistantScreen(initialQuery: topic)));
      return;
    }

    if (text.contains("doc url") || text.contains("dan url") || text.contains("doc duong dan")) {
      await _say("Mở đọc URL.", title: "Đọc URL");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadUrlScreen()));
      return;
    }

    if (text.contains("lich su")) {
      setState(() => _index = 1);
      await _say("Mở lịch sử.", title: "Lịch sử");
      return;
    }

    if (text.contains("tac vu")) {
      setState(() => _index = 2);
      await _say("Mở tác vụ.", title: "Tác vụ");
      return;
    }

    if (text.contains("cai dat") || text.contains("setting")) {
      setState(() => _index = 3);
      await _say("Mở cài đặt.", title: "Cài đặt");
      return;
    }

    if (text.contains("home") || text.contains("trang chu")) {
      setState(() => _index = 0);
      await _say("Về trang chủ.", title: "Home");
      return;
    }

    if (text.contains("quet") || text.contains("o c r") || text.contains("ocr")) {
      await _say("Mở quét chữ.", title: "OCR");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen()));
      return;
    }

    if (text.contains("mo ta") || text.contains("caption") || text.contains("hinh anh")) {
      await _say("Mở mô tả ảnh.", title: "Mô tả ảnh");
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen()));
      return;
    }

    if (text.contains("chup") || text.contains("camera")) {
      await _say("Mở camera.", title: "Camera");
      await _onCameraPressed();
      return;
    }

    await _say("Mình chưa hiểu lệnh. Bạn thử nói: đọc báo, quét chữ, mô tả ảnh, hoặc chụp nhanh.", title: "TalkSight");
    await _startVoiceOnce();
  }

  String? _extractTopic(String text) {
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
      await _say(msg, title: "Camera");
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

    try {
      if (mode == VisionMode.ocr) {
        final res = await api.ocr(path);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => VisionResultScreen(title: "Kết quả OCR", content: res.text)));
        _lastSpokenTitle = "OCR";
        _lastSpokenText = res.text;
        context.read<PlayerController>().setNow("OCR", "Kết quả sẵn sàng");
      } else {
        final res = await api.caption(path);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => VisionResultScreen(title: "Kết quả mô tả ảnh", content: res.caption)));
        _lastSpokenTitle = "Mô tả ảnh";
        _lastSpokenText = res.caption;
        context.read<PlayerController>().setNow("Mô tả ảnh", "Kết quả sẵn sàng");
      }
    } catch (e) {
      setState(() => _loading = false);
      final msg = ErrorUtils.message(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await context.read<TtsService>().speak(msg);
    }
  }

  // ===== Panel callbacks =====
  Future<void> _onPlayPause() async {
    final pc = context.read<PlayerController>();
    final tts = context.read<TtsService>();

    if (pc.isPlaying) {
      await tts.stop();
      pc.setPlaying(false);
      pc.setNow(_lastSpokenTitle, "Đã dừng");
      return;
    }

    if (_lastSpokenText.trim().isEmpty) {
      await _say("Bạn chưa có nội dung để phát lại.", title: "TalkSight");
      return;
    }

    await _say(_lastSpokenText, title: _lastSpokenTitle);
  }

  Future<void> _onStopTts() async {
    final pc = context.read<PlayerController>();
    await context.read<TtsService>().stop();
    pc.setPlaying(false);
    pc.setNow(_lastSpokenTitle, "Đã dừng");
  }

  Future<void> _onMicFromPanel() async => _toggleMic();

  void _openList() => setState(() => _index = 1);

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

          // ✅ Panel kéo lên/kéo xuống: HẠ XUỐNG SÁT CAMERA
          // trước bạn để bottom 78 => bị cao, giờ hạ xuống đúng theo height bottom bar (66)
          Positioned.fill(
            bottom: 56, // ✅ hạ panel xuống sát khu vực camera/bottom bar như mock
            child: Align(
              alignment: Alignment.bottomCenter,
              child: PlayerSlidingPanel(
                onPlayPause: _onPlayPause,
                onStop: _onStopTts,
                onMic: _onMicFromPanel,
              ),
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        // ✅ kéo lên ít thôi để sát bottom bar
        offset: const Offset(0, -6),
        child: SizedBox(
          width: 72, // ✅ nhỏ lại
          height: 72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 7), // ✅ viền vừa
              boxShadow: const [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 6),
                  color: Colors.black26,
                ),
              ],
            ),
            child: FloatingActionButton(
              elevation: 0,
              backgroundColor: AppColors.brandBrown,
              onPressed: _onCameraPressed,
              child: const AppIcon(AppIcons.camera, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),

      bottomNavigationBar: TalkSightBottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }

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