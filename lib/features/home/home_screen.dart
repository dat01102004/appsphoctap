import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../caption/caption_screen.dart';
import '../news/news_assistant_controller.dart';
import '../news/news_assistant_screen.dart';
import '../ocr/ocr_screen.dart';
import '../player/player_controller.dart';
import '../player/player_sliding_panel.dart';
import '../read_url/read_url_screen.dart';
import '../vision/live_vision_screen.dart';
import '../voice/voice_controller.dart';
import 'tabs/history_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/tasks_tab.dart';
import 'widgets/talksight_app_bar.dart';
import 'widgets/talksight_bottom_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _fabSize = 66;
  static const double _playerBottomOffset = 88; // Đặt gần hơn với Bottom Bar để cân đối

  int _index = 0;
  bool _greeted = false;

  String _lastSpokenText = '';
  String _lastSpokenTitle = 'TalkSight';
  String _lastPromptNorm = '';

  int _listenEpoch = 0;

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
            'Bạn có thể nói: quét chữ, mô tả ảnh, đọc báo, lịch sử, cài đặt, tác vụ, chụp nhanh, đăng nhập hoặc đăng ký. '
            'Hoặc giữ màn hình khoảng 2 giây để bật mic nghe lệnh.',
        title: 'TalkSight',
      );
      await _startVoiceOnce();
    });
  }

  @override
  void dispose() {
    _listenEpoch++;
    if (_voiceListenerAttached && _voiceRef != null) {
      _voiceRef!.removeListener(_syncVoiceToPlayer);
    }
    context.read<VoiceController>().stop();
    context.read<TtsService>().stop();
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
        newDetails:
        voice.lastWords.trim().isEmpty ? 'Đang nghe...' : voice.lastWords,
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
    final voice = context.read<VoiceController>();
    final player = context.read<PlayerController>();

    _lastSpokenText = text;
    _lastSpokenTitle = title ?? _lastSpokenTitle;
    _lastPromptNorm = _norm(text);

    final preview = text.length > 84 ? '${text.substring(0, 84)}...' : text;

    player.setNow(
      _lastSpokenTitle,
      preview,
      newDetails: text,
    );
    player.setPlaying(true);

    try {
      await voice.stop();
      await tts.stop();
      await tts.speak(text);
    } finally {
      player.setPlaying(false);

      if (!voice.isListening) {
        player.setNow(_lastSpokenTitle, 'Sẵn sàng');
      }
    }
  }

  int _settleMs(String text) {
    final value = 900 + (text.length * 28);
    if (value < 1200) return 1200;
    if (value > 4200) return 4200;
    return value;
  }

  Future<void> _announceAfterReturn(
      String text, {
        String title = 'TalkSight',
        bool resumeVoiceIfHome = true,
      }) async {
    await _say(text, title: title);

    if (!mounted) return;

    await Future.delayed(Duration(milliseconds: _settleMs(text)));

    if (!mounted) return;
    if (resumeVoiceIfHome && _index == 0) {
      await _startVoiceOnce();
    }
  }

  Future<void> _startVoiceOnce() async {
    if (!mounted) return;

    final voice = context.read<VoiceController>();
    final epoch = ++_listenEpoch;

    await voice.stop();
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted || epoch != _listenEpoch) return;

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;

        final raw = text.trim();
        final normalized = _norm(raw);

        if (raw.isEmpty) {
          await _say(
            'Mình chưa nghe rõ. Bạn nói lại giúp mình nhé.',
            title: 'TalkSight',
          );
          if (!mounted || epoch != _listenEpoch) return;
          await _startVoiceOnce();
          return;
        }

        if (_isPromptEcho(normalized)) {
          if (!mounted || epoch != _listenEpoch) return;
          await _startVoiceOnce();
          return;
        }

        await _handleVoiceCommand(raw);
      },
    );
  }

  bool _isPromptEcho(String normalized) {
    if (normalized.isEmpty || _lastPromptNorm.isEmpty) return false;
    if (normalized == _lastPromptNorm) return true;
    if (normalized.length >= 24 && _lastPromptNorm.contains(normalized)) {
      return true;
    }
    return false;
  }

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceController>();

    if (voice.isListening) {
      _listenEpoch++;
      await voice.stop();
    } else {
      await _startVoiceOnce();
    }
  }

  Future<void> _onHoldToListen() async {
    if (!mounted) return;

    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();final player = context.read<PlayerController>();

    if (voice.isListening) return;

    await tts.stop();
    player.setNow(
      _lastSpokenTitle,
      'Đang nghe...',
      newDetails: 'Đang nghe...',
    );

    await _startVoiceOnce();
  }

  Future<void> _resumeHomeVoice({bool speakPrompt = false}) async {
    if (!mounted || _index != 0) return;

    if (speakPrompt) {
      await _say(
        'Bạn muốn làm gì tiếp theo? Bạn có thể nói quét chữ, mô tả ảnh, đọc báo, lịch sử, cài đặt, tác vụ, chụp nhanh, đăng nhập hoặc đăng ký. '
            'Hoặc giữ màn hình khoảng 2 giây để bật mic.',
        title: 'TalkSight',
      );
    }

    if (!mounted || _index != 0) return;
    await _startVoiceOnce();
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    setState(() => _index = 0);
    await _resumeHomeVoice();
  }

  Future<void> _goHistory() async {
    if (!mounted) return;
    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
    setState(() => _index = 1);
  }

  Future<void> _goTasks() async {
    if (!mounted) return;
    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
    setState(() => _index = 2);
  }

  Future<void> _goSettings() async {
    if (!mounted) return;
    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
    setState(() => _index = 3);
  }

  Future<void> _openLoginScreen({bool resumeHomeVoiceIfReturn = true}) async {
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (!mounted) return;
    if (_index == 0 && resumeHomeVoiceIfReturn) {
      await _resumeHomeVoice(speakPrompt: true);
    }
  }

  Future<void> _openRegisterScreen({bool resumeHomeVoiceIfReturn = true}) async {
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (!mounted) return;
    if (_index == 0 && resumeHomeVoiceIfReturn) {
      await _resumeHomeVoice(speakPrompt: true);
    }
  }

  Future<void> _openNewsScreen({String? initialQuery}) async {
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsAssistantScreen(
          initialQuery: initialQuery,
          onGoHome: _goHome,
          onGoHistory: _goHistory,
          onGoTasks: _goTasks,
          onGoSettings: _goSettings,
          onOpenOcr: _openOcrScreen,
          onOpenCaption: _openCaptionScreen,
          onOpenCamera: _onCameraPressed,
        ),
      ),
    );

    if (!mounted) return;
    if (_index == 0) {
      await _resumeHomeVoice(speakPrompt: true);
    }
  }

  Future<void> _openOcrScreen() async {
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OcrScreen(
          onGoHome: _goHome,
          onGoHistory: _goHistory,
          onGoTasks: _goTasks,
          onGoSettings: _goSettings,
          onOpenNews: () => _openNewsScreen(),
          onOpenCaption: _openCaptionScreen,
        ),
      ),
    );

    if (!mounted) return;
    if (_index == 0) {
      await _resumeHomeVoice(speakPrompt: true);
    }
  }

  Future<void> _openCaptionScreen() async {
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptionScreen(
          onGoHome: _goHome,
          onGoHistory: _goHistory,
          onGoTasks: _goTasks,
          onGoSettings: _goSettings,
          onOpenNews: () => _openNewsScreen(),
          onOpenOcr: _openOcrScreen,
        ),
      ),
    );

    if (!mounted) return;
    if (_index == 0) {
      await _resumeHomeVoice(speakPrompt: true);
    }
  }

  Future<void> _openReadUrlScreen() async {
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReadUrlScreen()),
    );

    if (!mounted) return;
    if (_index == 0) {
      await _resumeHomeVoice(speakPrompt: true);
    }
  }

  Future<void> _handleLiveVisionAction(String? action) async {
    if (!mounted) return;

    switch (action) {
      case LiveVisionAction.news:
        await _openNewsScreen();
        return;

      case LiveVisionAction.ocr:
        await _openOcrScreen();
        return;

      case LiveVisionAction.history:
        setState(() => _index = 1);
        if (context.read<AuthController>().loggedIn) {
          await _announceAfterReturn(
            'Đã mở lịch sử.',
            title: 'Lịch sử',
            resumeVoiceIfHome: false,
          );
        } else {
          await _announceAfterReturn(
            'Bạn cần đăng nhập để xem lịch sử. Mình đã chuyển bạn tới lịch sử để chọn đăng nhập hoặc đăng ký.',
            title: 'Lịch sử',
            resumeVoiceIfHome: false,
          );
        }
        return;

      case LiveVisionAction.tasks:
        setState(() => _index = 2);
        await _announceAfterReturn(
          'Đã mở tác vụ.',
          title: 'Tác vụ',
          resumeVoiceIfHome: false,
        );
        return;

      case LiveVisionAction.settings:
        setState(() => _index = 3);
        await _announceAfterReturn(
          'Đã mở cài đặt.',
          title: 'Cài đặt',
          resumeVoiceIfHome: false,
        );
        return;

      case LiveVisionAction.home:
      default:
        setState(() => _index = 0);
        await _announceAfterReturn(
          'Đã về trang chủ. Bạn có thể nói đọc báo, quét chữ, mô tả ảnh, lịch sử, cài đặt, tác vụ, chụp nhanh, đăng nhập hoặc đăng ký.',
          title: 'TalkSight',
          resumeVoiceIfHome: true,
        );
        return;
    }
  }

  bool _isLoginCommand(String text) {
    return text.contains('dang nhap') ||
        text.contains('login') ||
        text.contains('log in') ||
        text.contains('vao tai khoan');
  }

  bool _isRegisterCommand(String text) {
    return text.contains('dang ky') ||
        text.contains('tao tai khoan') ||
        text.contains('lap tai khoan') ||
        text.contains('register') ||
        text.contains('sign up');
  }

  bool _isLogoutCommand(String text) {
    return text.contains('dang xuat') ||
        text.contains('log out') ||
        text.contains('logout') ||
        text.contains('thoat tai khoan');
  }

  Future<void> _handleVoiceCommand(String raw) async {
    final news = context.read<NewsAssistantController>();
    final auth = context.read<AuthController>();
    final text = _norm(raw);

    final handledByNews = await news.handleUtterance(raw);
    if (handledByNews) return;

    if (_isLogoutCommand(text)) {
      if (!auth.loggedIn) {
        await _say(
          'Bạn đang ở chế độ khách nên chưa có tài khoản nào đang đăng nhập.',
          title: 'Tài khoản',
        );
        if (!mounted) return;
        await _startVoiceOnce();
        return;
      }

      await auth.logout();
      if (!mounted) return;
      await _say(
        'Bạn đã đăng xuất. Hiện tại bạn đang ở chế độ khách.',
        title: 'Tài khoản',
      );
      if (!mounted) return;
      await _resumeHomeVoice(speakPrompt: true);
      return;
    }

    if (_isRegisterCommand(text)) {
      if (auth.loggedIn) {
        await _say(
          'Bạn đang đăng nhập bằng ${auth.displayName}. Nếu muốn tạo tài khoản khác, bạn có thể đăng xuất trước.',
          title: 'Đăng ký',
        );
        if (!mounted) return;
        await _resumeHomeVoice(speakPrompt: true);
        return;
      }

      await _say('Ok, mình mở màn hình đăng ký tài khoản.', title: 'Đăng ký');
      if (!mounted) return;
      await _openRegisterScreen();
      return;
    }

    if (_isLoginCommand(text)) {
      if (auth.loggedIn) {
        await _say(
          'Bạn đã đăng nhập rồi. Tài khoản hiện tại là ${auth.displayName}.',
          title: 'Đăng nhập',
        );
        if (!mounted) return;
        await _resumeHomeVoice(speakPrompt: true);
        return;
      }

      await _say('Ok, mình mở màn hình đăng nhập tài khoản.', title: 'Đăng nhập');
      if (!mounted) return;
      await _openLoginScreen();
      return;
    }

    final isNewsCmd = text.contains('doc web') ||
        text.contains('doc bao') ||
        text.contains('tin tuc') ||
        text.contains('bao moi') ||
        text.contains('tin moi');

    if (isNewsCmd) {
      final topic = _extractTopic(text);
      await _say('Ok, mình mở trợ lý đọc báo.', title: 'Đọc báo');
      if (!mounted) return;
      await _openNewsScreen(initialQuery: topic);
      return;
    }

    if (text.contains('doc url') ||
        text.contains('dan url') ||
        text.contains('doc duong dan')) {
      await _say('Mở đọc URL.', title: 'Đọc URL');
      if (!mounted) return;
      await _openReadUrlScreen();
      return;
    }

    if (text.contains('xem lich su') ||
        text.contains('mo lich su') ||
        text.contains('vao lich su') ||
        text.contains('lich su')) {
      setState(() => _index = 1);

      if (!auth.loggedIn) {
        await _say(
          'Bạn cần đăng nhập để xem lịch sử đã lưu. Mình chuyển bạn tới lịch sử để bạn chọn đăng nhập hoặc đăng ký.',
          title: 'Lịch sử',
        );
        return;
      }

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
      if (!mounted) return;
      await _resumeHomeVoice();
      return;
    }

    if (text.contains('quet') ||
        text.contains('ocr') ||
        text.contains('o c r') ||
        text.contains('doc chu')) {
      await _say('Mở quét chữ.', title: 'OCR');
      if (!mounted) return;
      await _openOcrScreen();
      return;
    }

    if (text.contains('mo ta') ||
        text.contains('caption') ||
        text.contains('hinh anh')) {
      await _say('Mở mô tả ảnh.', title: 'Mô tả ảnh');
      if (!mounted) return;
      await _openCaptionScreen();
      return;
    }

    if (text.contains('chup nhanh') ||
        text.contains('chup') ||
        text.contains('camera')) {
      await _say('Mở chụp nhanh trực tiếp.', title: 'Chụp nhanh');
      if (!mounted) return;
      await _onCameraPressed();
      return;
    }

    await _say(
      'Mình chưa hiểu lệnh. Bạn thử nói: đăng nhập, đăng ký, đọc báo, quét chữ, mô tả ảnh, xem lịch sử hoặc chụp nhanh.',
      title: 'TalkSight',
    );

    if (!mounted) return;
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
    if (!mounted) return;

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const LiveVisionScreen(),
      ),
    );

    if (!mounted) return;
    await _handleLiveVisionAction(action);
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

  Future<void> _onBottomBarTap(int value) async {
    if (!mounted) return;

    setState(() => _index = value);

    if (value == 0) {
      await _resumeHomeVoice();
      return;
    }

    _listenEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
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
      HistoryTab(isActive: _index == 1),
      const TasksTab(),
      const SettingsTab(),
    ];

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _onHoldToListen,
      child: Scaffold(
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
          offset: const Offset(0, 32), // Hạ thấp nút Camera xuống đúng vị trí trung tâm notch
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
          onTap: _onBottomBarTap,
        ),
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