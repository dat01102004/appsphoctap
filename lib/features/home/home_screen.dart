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
import '../player/player_controller.dart';
import '../player/player_sliding_panel.dart';
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
  static const double _fabSize = 66;
  static const double _bottomBarHeight = 72;
  static const double _playerBottomOffset = 74;

  final ImagePicker _picker = ImagePicker();

  int _index = 0;
  bool _loading = false;
  bool _greeted = false;

  String _lastSpokenText = '';
  String _lastSpokenTitle = 'TalkSight';

  VoiceController? _voiceRef;
  bool _voiceListenerAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_voiceListenerAttached) {
      _voiceRef = context.read<VoiceController>();
      _voiceRef!.addListener(_syncVoiceToPlayer);
      _voiceListenerAttached = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncVoiceToPlayer();
      });
    }

    if (_greeted) return;
    _greeted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _say(
        'Xin chào bạn! Hôm nay bạn muốn sử dụng tính năng gì? '
            'Bạn có thể nói: quét chữ, mô tả ảnh, đọc báo, lịch sử, cài đặt, tác vụ, chụp nhanh.',
        title: 'TalkSight',
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

    final voice = context.read<VoiceController>();
    final player = context.read<PlayerController>();

    player.setListening(voice.isListening);

    if (voice.isListening) {
      final text = voice.lastWords.trim().isEmpty
          ? 'Đang nghe...'
          : 'Đang nghe: ${voice.lastWords}';
      player.setNow(
        _lastSpokenTitle,
        text,
        newDetails: voice.lastWords.trim().isEmpty ? 'Đang nghe...' : voice.lastWords,
      );
      return;
    }

    if (player.subtitle.startsWith('Đang nghe')) {
      player.setNow(_lastSpokenTitle, 'Sẵn sàng');
    }
  }

  Future<void> _say(
      String text, {
        String? title,
      }) async {
    final tts = context.read<TtsService>();
    final player = context.read<PlayerController>();

    _lastSpokenText = text;
    _lastSpokenTitle = title ?? _lastSpokenTitle;

    final preview = text.length > 84 ? '${text.substring(0, 84)}...' : text;

    player.setNow(
      _lastSpokenTitle,
      preview,
      newDetails: text,
    );
    player.setPlaying(true);

    try {
      await tts.speak(text);
    } finally {
      player.setPlaying(false);
      final voice = context.read<VoiceController>();
      if (!voice.isListening) {
        player.setNow(_lastSpokenTitle, 'Sẵn sàng');
      }
    }
  }

  Future<void> _startVoiceOnce() async {
    final voice = context.read<VoiceController>();

    await Future.delayed(const Duration(milliseconds: 350));

    await voice.start(
      onFinal: (text) async {
        if (text.trim().isEmpty) {
          await _say(
            'Mình chưa nghe rõ. Bạn nói lại giúp mình nhé.',
            title: 'TalkSight',
          );
          await _startVoiceOnce();
          return;
        }

        await _handleVoiceCommand(text);
      },
    );
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

    final isNewsCmd = text.contains('doc web') ||
        text.contains('doc bao') ||
        text.contains('tin tuc') ||
        text.contains('bao moi') ||
        text.contains('tin moi');

    if (isNewsCmd) {
      final topic = _extractTopic(text);
      await _say('Ok, mình mở trợ lý đọc báo.', title: 'Đọc báo');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsAssistantScreen(
            initialQuery: topic,
            onGoHome: () async {
              if (!mounted) return;
              setState(() => _index = 0);
            },
            onGoHistory: () async {
              if (!mounted) return;
              setState(() => _index = 1);
            },
            onGoTasks: () async {
              if (!mounted) return;
              setState(() => _index = 2);
            },
            onGoSettings: () async {
              if (!mounted) return;
              setState(() => _index = 3);
            },
            onOpenOcr: () async {
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OcrScreen()),
              );
            },
            onOpenCaption: () async {
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CaptionScreen()),
              );
            },
            onOpenCamera: () async {
              if (!mounted) return;
              await _onCameraPressed();
            },
          ),
        ),
      );
      return;
    }

    if (text.contains('doc url') ||
        text.contains('dan url') ||
        text.contains('doc duong dan')) {
      await _say('Mở đọc URL.', title: 'Đọc URL');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReadUrlScreen()),
      );
      return;
    }

    if (text.contains('lich su')) {
      setState(() => _index = 1);
      await _say('Mở lịch sử.', title: 'Lịch sử');
      return;
    }

    if (text.contains('tac vu')) {
      setState(() => _index = 2);
      await _say('Mở tác vụ.', title: 'Tác vụ');
      return;
    }

    if (text.contains('cai dat') || text.contains('setting')) {
      setState(() => _index = 3);
      await _say('Mở cài đặt.', title: 'Cài đặt');
      return;
    }

    if (text.contains('home') || text.contains('trang chu')) {
      setState(() => _index = 0);
      await _say('Về trang chủ.', title: 'Home');
      return;
    }

    if (text.contains('quet') || text.contains('ocr') || text.contains('o c r')) {
      await _say('Mở quét chữ.', title: 'OCR');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OcrScreen()),
      );
      return;
    }

    if (text.contains('mo ta') ||
        text.contains('caption') ||
        text.contains('hinh anh')) {
      await _say('Mở mô tả ảnh.', title: 'Mô tả ảnh');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CaptionScreen()),
      );
      return;
    }

    if (text.contains('chup') || text.contains('camera')) {
      await _say('Mở camera.', title: 'Camera');
      await _onCameraPressed();
      return;
    }

    await _say(
      'Mình chưa hiểu lệnh. Bạn thử nói: đọc báo, quét chữ, mô tả ảnh, hoặc chụp nhanh.',
      title: 'TalkSight',
    );
    await _startVoiceOnce();
  }

  String? _extractTopic(String text) {
    final idx = text.indexOf('ve ');
    if (idx >= 0) return text.substring(idx + 3).trim();

    if (text.startsWith('doc bao')) {
      final value = text.replaceFirst('doc bao', '').trim();
      return value.isEmpty ? null : value;
    }

    if (text.startsWith('tin tuc')) {
      final value = text.replaceFirst('tin tuc', '').trim();
      return value.isEmpty ? null : value;
    }

    if (text.startsWith('doc web')) {
      final value = text.replaceFirst('doc web', '').trim();
      return value.isEmpty ? null : value;
    }

    return null;
  }

  Future<void> _onCameraPressed() async {
    final cameraPermission = await Permission.camera.request();

    if (!cameraPermission.isGranted) {
      const message = 'Bạn cần cấp quyền camera để chụp ảnh.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(message)),
        );
      }
      await _say(message, title: 'Camera');
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );

    if (image == null || !mounted) return;
    _openAfterShotSheet(image.path);
  }

  void _openAfterShotSheet(String imagePath) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const AppIcon(
                  AppIcons.ocr,
                  size: 24,
                  color: AppColors.brandBrown,
                ),
                title: const Text('Quét chữ (OCR)'),
                onTap: () {
                  Navigator.pop(context);
                  _processImage(imagePath, VisionMode.ocr);
                },
              ),
              ListTile(
                leading: const AppIcon(
                  AppIcons.image,
                  size: 24,
                  color: AppColors.brandBrown,
                ),
                title: const Text('Mô tả ảnh (Caption)'),
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
        if (!mounted) return;

        setState(() => _loading = false);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisionResultScreen(
              title: 'Kết quả OCR',
              content: res.text,
            ),
          ),
        );

        final preview =
        res.text.length > 84 ? '${res.text.substring(0, 84)}...' : res.text;

        context.read<PlayerController>().setNow(
          'OCR',
          preview,
          newDetails: res.text,
        );

        Future.microtask(() => _say(res.text, title: 'OCR'));
        return;
      }

      final res = await api.caption(path);
      if (!mounted) return;

      setState(() => _loading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisionResultScreen(
            title: 'Kết quả mô tả ảnh',
            content: res.caption,
          ),
        ),
      );

      final preview = res.caption.length > 84
          ? '${res.caption.substring(0, 84)}...'
          : res.caption;

      context.read<PlayerController>().setNow(
        'Mô tả ảnh',
        preview,
        newDetails: res.caption,
      );

      Future.microtask(() => _say(res.caption, title: 'Mô tả ảnh'));
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }

      final message = ErrorUtils.message(e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }

      await context.read<TtsService>().speak(message);
    }
  }

  Future<void> _onPlayPause() async {
    final player = context.read<PlayerController>();
    final tts = context.read<TtsService>();

    if (player.isPlaying) {
      await tts.stop();
      player.setPlaying(false);
      player.setNow(_lastSpokenTitle, 'Đã dừng');
      return;
    }

    if (_lastSpokenText.trim().isEmpty) {
      await _say('Bạn chưa có nội dung để phát lại.', title: 'TalkSight');
      return;
    }

    await _say(_lastSpokenText, title: _lastSpokenTitle);
  }

  Future<void> _onStopTts() async {
    final player = context.read<PlayerController>();
    await context.read<TtsService>().stop();
    player.setPlaying(false);
    player.setNow(_lastSpokenTitle, 'Đã dừng');
  }

  Future<void> _onMicFromPanel() async {
    await _toggleMic();
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
          SafeArea(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
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
                        Text('Đang xử lý...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            bottom: _playerBottomOffset,
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
        offset: const Offset(0, -8),
        child: SizedBox(
          width: _fabSize,
          height: _fabSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  color: Colors.black26,
                ),
              ],
            ),
            child: FloatingActionButton(
              elevation: 0,
              backgroundColor: AppColors.brandBrown,
              onPressed: _onCameraPressed,
              child: const AppIcon(
                AppIcons.camera,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: TalkSightBottomBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
      ),
    );
  }

  String _norm(String input) {
    var s = input.toLowerCase().trim();

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