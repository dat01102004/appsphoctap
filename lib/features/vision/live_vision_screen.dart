import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../../data/services/vision_api.dart';
import '../auth/auth_controller.dart';
import '../history/history_controller.dart';
import '../player/player_controller.dart';
import '../voice/voice_controller.dart';

class LiveVisionAction {
  static const String home = 'home';
  static const String news = 'news';
  static const String ocr = 'ocr';
  static const String history = 'history';
  static const String tasks = 'tasks';
  static const String settings = 'settings';
}

class LiveVisionScreen extends StatefulWidget {
  const LiveVisionScreen({super.key});

  @override
  State<LiveVisionScreen> createState() => _LiveVisionScreenState();
}

class _LiveVisionScreenState extends State<LiveVisionScreen> {
  static const Duration _immediateScanDelay = Duration(milliseconds: 350);
  static const Duration _freshScanDelay = Duration(seconds: 5);
  static const Duration _repeatOnceDelay = Duration(seconds: 12);
  static const Duration _repeatTwiceDelay = Duration(seconds: 20);
  static const Duration _repeatManyDelay = Duration(seconds: 30);

  CameraController? _camera;
  Timer? _scanTimer;

  bool _initializing = true;
  bool _busy = false;
  bool _scanEnabled = false;
  bool _autoSpeak = true;

  int _listenEpoch = 0;
  int _requestCount = 0;

  String _lastPromptNorm = '';
  String _lastAutoSpeakNorm = '';
  String _lastResultNorm = '';

  int _sameResultStreak = 0;

  String _focusHint = 'cảnh vật trước mặt';
  String _overlayText = 'Đưa camera vào vật bạn muốn xem';
  String _statusText = 'Đang mở camera...';

  DateTime? _lastAutoSpeakAt;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _listenEpoch++;
    _scanTimer?.cancel();
    context.read<VoiceController>().stop();
    context.read<TtsService>().stop();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (!mounted) return;
        await _speak(
          'Bạn cần cấp quyền camera để dùng mô tả trực tiếp.',
          title: _screenTitle,
        );
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        await _speak(
          'Thiết bị này chưa có camera khả dụng.',
          title: _screenTitle,
        );
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final selected = cameras.firstWhere(
            (e) => e.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _camera = controller;
        _initializing = false;
        _statusText = 'Sẵn sàng';
        _overlayText = 'Đưa camera vào vật bạn muốn xem';
      });

      await _announceAndStart();
    } catch (_) {
      if (!mounted) return;
      await _speak(
        'Không mở được camera.',
        title: _screenTitle,
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _announceAndStart() async {
    _stopScanLoop(reason: 'Đang chuẩn bị');

    const prompt =
        'Đã mở mô tả trực tiếp. Tự đọc đang bật. '
        'Bạn chỉ cần đưa camera vào cảnh vật. '
        'Nếu muốn ra lệnh mà không cần nhìn màn hình, hãy nhấn giữ ở bất kỳ đâu. '
        'Nếu muốn nghe lại hướng dẫn, hãy chạm nhanh hai lần ở bất kỳ đâu. '
        'Bạn có thể nói: về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ hoặc cài đặt.';

    _lastPromptNorm = _norm(prompt);

    if (mounted) {
      setState(() {
        _statusText = 'Đang hướng dẫn';
      });
    }

    await _speak(prompt, title: _screenTitle);

    if (!mounted) return;
    _startScanLoop(immediate: true, forceSpeak: true);
  }

  Future<void> _speakQuickHelp() async {
    const help =
        'Đây là chế độ mô tả trực tiếp. '
        'Nhấn giữ ở bất kỳ đâu để ra lệnh. '
        'Bạn có thể nói: đọc lại, tạm dừng, tiếp tục, về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ hoặc cài đặt.';
    _lastPromptNorm = _norm(help);
    await _speak(help, title: _screenTitle);
  }

  Future<void> _listenOnce(
      Future<void> Function(String raw) onFinal,
      ) async {
    final epoch = ++_listenEpoch;
    final voice = context.read<VoiceController>();

    await voice.stop();

    if (!mounted || epoch != _listenEpoch) return;

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;

        final raw = text.trim();
        final normalized = _norm(raw);

        if (raw.isEmpty || _isPromptEcho(normalized)) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted || epoch != _listenEpoch) return;
          await _listenOnce(onFinal);
          return;
        }

        await onFinal(raw);
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

  String _extractFocusHint(String raw) {
    var value = raw.trim();

    final patterns = <RegExp>[
      RegExp(r'^\s*mô tả\s+', caseSensitive: false),
      RegExp(r'^\s*mo ta\s+', caseSensitive: false),
      RegExp(r'^\s*tìm\s+', caseSensitive: false),
      RegExp(r'^\s*tim\s+', caseSensitive: false),
      RegExp(r'^\s*nhìn\s+', caseSensitive: false),
      RegExp(r'^\s*nhin\s+', caseSensitive: false),
      RegExp(r'^\s*xem\s+', caseSensitive: false),
      RegExp(r'^\s*giúp mình\s+', caseSensitive: false),
      RegExp(r'^\s*giup minh\s+', caseSensitive: false),
      RegExp(r'^\s*cho mình biết\s+', caseSensitive: false),
      RegExp(r'^\s*cho minh biet\s+', caseSensitive: false),
      RegExp(r'^\s*đây là\s+', caseSensitive: false),
      RegExp(r'^\s*day la\s+', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      value = value.replaceFirst(pattern, '');
    }

    return value.trim();
  }

  Future<void> _analyzeCurrentFrame({required bool forceSpeak}) async {
    final camera = _camera;
    if (!_scanEnabled || _busy || camera == null || !camera.value.isInitialized) {
      return;
    }

    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();

    if (voice.isListening || tts.isSpeaking.value) {
      if (mounted && !_busy) {
        setState(() {
          _statusText = voice.isListening ? 'Đang nghe lệnh' : 'Đang đọc kết quả';
        });
      }
      _scheduleNextScan();
      return;
    }

    _busy = true;
    if (mounted) {
      setState(() {
        _statusText = 'Đang mô tả...';
      });
    }

    XFile? shot;
    try {
      shot = await camera.takePicture();
      _requestCount++;

      final api = context.read<VisionApi>();
      final res = await api.caption(shot.path);

      final resultText = _cleanResult(
        res.caption,
        fallback: 'Mình chưa mô tả rõ được khung hình này.',
      );

      final normalizedResult = _norm(resultText);
      if (_isSimilarToPreviousResult(normalizedResult)) {
        _sameResultStreak++;
      } else {
        _sameResultStreak = 0;
      }
      _lastResultNorm = normalizedResult;

      if (!mounted) return;

      setState(() {
        _overlayText = resultText;
        _statusText = _sameResultStreak == 0
            ? 'Đã cập nhật'
            : 'Kết quả gần giống trước, đang giảm tần suất gửi';
      });

      context.read<PlayerController>().setNow(
        _screenTitle,
        _preview(resultText),
        newDetails: resultText,
      );

      if (res.historyId != null) {
        final auth = context.read<AuthController>();
        if (auth.loggedIn) {
          unawaited(
            context.read<HistoryController>().load(
              type: 'caption',
              announce: false,
            ),
          );
        }
      }

      if (forceSpeak || (_autoSpeak && _shouldAutoSpeak(resultText))) {
        await _speak(
          resultText,
          title: _screenTitle,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusText = 'Có lỗi khi phân tích khung hình';
        });
      }
    } finally {
      if (shot != null) {
        try {
          final file = File(shot.path);
          if (file.existsSync()) {
            await file.delete();
          }
        } catch (_) {}
      }

      _busy = false;

      if (_scanEnabled) {
        _scheduleNextScan();
      }
    }
  }

  bool _shouldAutoSpeak(String text) {
    final normalized = _norm(text);
    if (normalized.isEmpty) return false;
    if (normalized == _lastAutoSpeakNorm) return false;

    final now = DateTime.now();
    if (_lastAutoSpeakAt != null &&
        now.difference(_lastAutoSpeakAt!) < const Duration(seconds: 4)) {
      return false;
    }

    _lastAutoSpeakNorm = normalized;
    _lastAutoSpeakAt = now;
    return true;
  }

  bool _isSimilarToPreviousResult(String nextNorm) {
    final prevNorm = _lastResultNorm;
    if (prevNorm.isEmpty || nextNorm.isEmpty) return false;
    if (prevNorm == nextNorm) return true;
    if (prevNorm.contains(nextNorm) || nextNorm.contains(prevNorm)) {
      return true;
    }

    final prevWords = prevNorm
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.length >= 3)
        .toSet();

    final nextWords = nextNorm
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.length >= 3)
        .toSet();

    if (prevWords.isEmpty || nextWords.isEmpty) return false;

    final intersection = prevWords.intersection(nextWords).length;
    final union = {...prevWords, ...nextWords}.length;

    if (union == 0) return false;

    final similarity = intersection / union;
    return similarity >= 0.72;
  }

  String _cleanResult(String raw, {required String fallback}) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return fallback;
    return value;
  }

  void _resetAdaptiveScan() {
    _sameResultStreak = 0;
    _lastResultNorm = '';
  }

  Duration _nextScanDelay() {
    if (_sameResultStreak >= 3) return _repeatManyDelay;
    if (_sameResultStreak == 2) return _repeatTwiceDelay;
    if (_sameResultStreak == 1) return _repeatOnceDelay;
    return _freshScanDelay;
  }

  void _queueImmediateScan({required bool forceSpeak}) {
    if (!_scanEnabled) return;

    _scanTimer?.cancel();

    if (mounted && !_busy) {
      setState(() {
        _statusText = 'Sẵn sàng quét';
      });
    }

    _scanTimer = Timer(_immediateScanDelay, () {
      if (!mounted || !_scanEnabled) return;
      unawaited(_analyzeCurrentFrame(forceSpeak: forceSpeak));
    });
  }

  void _scheduleNextScan() {
    if (!_scanEnabled) return;

    _scanTimer?.cancel();
    final delay = _nextScanDelay();

    if (mounted && !_busy) {
      setState(() {
        _statusText = 'Đợi ${delay.inSeconds}s để tiết kiệm lượt';
      });
    }

    _scanTimer = Timer(delay, () {
      if (!mounted || !_scanEnabled) return;
      unawaited(_analyzeCurrentFrame(forceSpeak: false));
    });
  }

  void _startScanLoop({
    bool immediate = true,
    bool forceSpeak = false,
  }) {
    _scanEnabled = true;

    if (mounted && !_busy) {
      setState(() {
        _statusText = 'Đang quét trực tiếp';
      });
    }

    if (immediate) {
      _queueImmediateScan(forceSpeak: forceSpeak);
    } else {
      _scheduleNextScan();
    }
  }

  void _stopScanLoop({String reason = 'Đã tạm dừng'}) {
    _scanEnabled = false;
    _scanTimer?.cancel();

    if (mounted) {
      setState(() {
        _statusText = reason;
      });
    }
  }

  Future<void> _toggleScan() async {
    if (_scanEnabled) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      await _speak('Đã tạm dừng mô tả trực tiếp.', title: _screenTitle);
      return;
    }

    _resetAdaptiveScan();
    _startScanLoop(immediate: true, forceSpeak: false);
    await _speak('Đã tiếp tục mô tả trực tiếp.', title: _screenTitle);
  }

  Future<void> _listenCommand() async {
    if (_initializing) return;

    HapticFeedback.mediumImpact();

    final prompt =
        'Mình đang nghe lệnh. Bạn có thể nói: về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ, cài đặt, đọc lại, tạm dừng hoặc tiếp tục.';
    _lastPromptNorm = _norm(prompt);

    if (mounted) {
      setState(() {
        _statusText = 'Đang nghe lệnh';
      });
    }

    await _speak(prompt, title: _screenTitle);

    if (!mounted) return;
    await Future.delayed(Duration(milliseconds: _settleMs(prompt)));

    if (!mounted) return;
    await _listenOnce(_handleRuntimeCommand);
  }

  Future<void> _handleRuntimeCommand(String raw) async {
    final n = _norm(raw);

    final navAction = _matchNavigationAction(n);
    if (navAction != null) {
      await _goToAction(navAction);
      return;
    }

    if (_isPauseCommand(n)) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      await _speak('Đã tạm dừng mô tả trực tiếp.', title: _screenTitle);
      return;
    }

    if (_isResumeCommand(n)) {
      _resetAdaptiveScan();
      _startScanLoop(immediate: true, forceSpeak: false);
      await _speak('Đã tiếp tục mô tả trực tiếp.', title: _screenTitle);
      return;
    }

    if (_isSpeakAgainCommand(n)) {
      await _speak(_overlayText, title: _screenTitle);
      return;
    }

    if (n.contains('bat doc tu dong')) {
      setState(() {
        _autoSpeak = true;
      });
      await _speak('Đã bật tự đọc.', title: _screenTitle);
      return;
    }

    if (n.contains('tat doc tu dong')) {
      setState(() {
        _autoSpeak = false;
      });
      await _speak('Đã tắt tự đọc.', title: _screenTitle);
      return;
    }

    if (n.contains('huong dan') || n.contains('tro giup') || n.contains('giup do')) {
      await _speakQuickHelp();
      return;
    }

    final hint = _extractFocusHint(raw);
    if (hint.isNotEmpty) {
      setState(() {
        _focusHint = hint;
      });
      _resetAdaptiveScan();
      await _speak(
        'Mình sẽ ưu tiên mô tả $hint.',
        title: _screenTitle,
      );
      _startScanLoop(immediate: true, forceSpeak: true);
      return;
    }

    await _speak(
      'Mình chưa hiểu. Bạn có thể nói: về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ, cài đặt, đọc lại, tạm dừng hoặc tiếp tục.',
      title: _screenTitle,
    );
  }

  String? _matchNavigationAction(String n) {
    if (n.contains('ve trang chu') ||
        n == 'thoat' ||
        n == 'dong' ||
        n.contains('quay lai')) {
      return LiveVisionAction.home;
    }

    if (n.contains('doc bao') || n.contains('tin tuc')) {
      return LiveVisionAction.news;
    }

    if (n.contains('quet chu') ||
        n.contains('doc chu') ||
        n.contains('ocr') ||
        n.contains('van ban')) {
      return LiveVisionAction.ocr;
    }

    if (n.contains('lich su')) {
      return LiveVisionAction.history;
    }

    if (n.contains('tac vu')) {
      return LiveVisionAction.tasks;
    }

    if (n.contains('cai dat')) {
      return LiveVisionAction.settings;
    }

    return null;
  }

  Future<void> _goToAction(String action) async {
    String message;
    switch (action) {
      case LiveVisionAction.news:
        message = 'Đang chuyển sang đọc báo.';
        break;
      case LiveVisionAction.ocr:
        message = 'Đang chuyển sang quét chữ.';
        break;
      case LiveVisionAction.history:
        message = 'Đang quay về để mở lịch sử.';
        break;
      case LiveVisionAction.tasks:
        message = 'Đang quay về để mở tác vụ.';
        break;
      case LiveVisionAction.settings:
        message = 'Đang quay về để mở cài đặt.';
        break;
      default:
        message = 'Đang quay về trang chủ.';
        break;
    }

    _stopScanLoop(reason: 'Đang chuyển màn hình');
    await _speak(message, title: _screenTitle);

    if (!mounted) return;
    Navigator.pop(context, action);
  }

  bool _isPauseCommand(String n) {
    return n.contains('tam dung') || n.contains('dung lai') || n == 'dung';
  }

  bool _isResumeCommand(String n) {
    return n.contains('tiep tuc') ||
        n.contains('mo lai') ||
        n.contains('quet tiep');
  }

  bool _isSpeakAgainCommand(String n) {
    return n.contains('doc lai') ||
        n.contains('noi lai') ||
        n.contains('phat lai');
  }

  Future<void> _speak(String text, {required String title}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final player = context.read<PlayerController>();
    player.setNow(
      title,
      _preview(trimmed),
      newDetails: trimmed,
    );

    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
    await context.read<TtsService>().speak(trimmed);
  }

  int _settleMs(String text) {
    final value = 900 + (text.length * 28);
    if (value < 1200) return 1200;
    if (value > 4200) return 4200;
    return value;
  }

  String _preview(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  String get _screenTitle => 'Mô tả trực tiếp';

  String get _statusChipLabel {
    final countText = '$_requestCount lượt';
    if (_busy) {
      return 'Đang xử lý · $countText';
    }
    return '$_statusText · $countText';
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

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();
    final camera = _camera;

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _listenCommand,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: _speakQuickHelp,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (camera != null && camera.value.isInitialized)
                CameraPreview(camera)
              else
                Container(color: Colors.black),

              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x22000000),
                      Color(0x22000000),
                      Color(0xB3000000),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back,
                            onTap: () => _goToAction(LiveVisionAction.home),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const _ModeChip(
                                  label: 'Mô tả',
                                  selected: true,
                                ),
                                _SmallStatusChip(
                                  label: _statusChipLabel,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_focusHint.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.center_focus_strong,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đang ưu tiên: $_focusHint',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (voice.isListening)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandBrown.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            voice.lastWords.trim().isEmpty
                                ? 'Đang nghe...'
                                : 'Đang nghe: ${voice.lastWords}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mô tả trực tiếp',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _overlayText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _BottomActionButton(
                                    icon: _scanEnabled
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    label: _scanEnabled ? 'Tạm dừng' : 'Tiếp tục',
                                    onTap: _toggleScan,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _BottomActionButton(
                                    icon: Icons.mic_rounded,
                                    label: voice.isListening
                                        ? 'Đang nghe'
                                        : 'Ra lệnh',
                                    onTap: _listenCommand,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _BottomActionButton(
                                    icon: Icons.volume_up_rounded,
                                    label: 'Đọc lại',
                                    onTap: () => _speak(
                                      _overlayText,
                                      title: _screenTitle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _BottomActionButton(
                                    icon: _autoSpeak
                                        ? Icons.record_voice_over_rounded
                                        : Icons.voice_over_off_rounded,
                                    label: _autoSpeak
                                        ? 'Tắt tự đọc'
                                        : 'Bật tự đọc',
                                    onTap: () async {
                                      setState(() {
                                        _autoSpeak = !_autoSpeak;
                                      });
                                      await _speak(
                                        _autoSpeak
                                            ? 'Đã bật tự đọc.'
                                            : 'Đã tắt tự đọc.',
                                        title: _screenTitle,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Giữ ở bất kỳ đâu khoảng 2 giây để ra lệnh. Nhấn hai lần ở bất kỳ đâu để nghe lại hướng dẫn.',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Lệnh gợi ý: về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ, cài đặt, đọc lại, tạm dừng, tiếp tục',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_initializing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _ModeChip({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandBrown : Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SmallStatusChip extends StatelessWidget {
  final String label;

  const _SmallStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBrown.withOpacity(0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}