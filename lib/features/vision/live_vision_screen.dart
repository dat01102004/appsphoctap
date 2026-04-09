import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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

enum _LiveVisionMode { caption, ocr }

class LiveVisionScreen extends StatefulWidget {
  const LiveVisionScreen({super.key});

  @override
  State<LiveVisionScreen> createState() => _LiveVisionScreenState();
}

class _LiveVisionScreenState extends State<LiveVisionScreen> {
  static const Duration _scanInterval = Duration(milliseconds: 1800);

  CameraController? _camera;
  Timer? _scanTimer;

  bool _initializing = true;
  bool _busy = false;
  bool _scanEnabled = false;
  bool _autoSpeak = true;
  bool _speaking = false;

  int _listenEpoch = 0;

  String _lastPromptNorm = '';
  String _lastAutoSpeakNorm = '';

  _LiveVisionMode _mode = _LiveVisionMode.caption;

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
    context.read<TtsService>().stop();
    context.read<VoiceController>().stop();
    context.read<PlayerController>().setPlaying(false);
    _camera?.dispose();
    super.dispose();
  }

  String get _screenTitle =>
      _mode == _LiveVisionMode.ocr ? 'Đọc chữ trực tiếp' : 'Mô tả trực tiếp';

  String get _modeChipLabel =>
      _mode == _LiveVisionMode.ocr ? 'Quét chữ' : 'Mô tả';

  String get _helpText =>
      'Giữ ở bất kỳ đâu khoảng 2 giây để ra lệnh. Nhấn hai lần ở bất kỳ đâu để nghe lại hướng dẫn.\n\n'
          'Lệnh gợi ý: về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ, cài đặt, đọc lại, tạm dừng, tiếp tục.';

  Future<void> _initCamera() async {
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (!mounted) return;
        await _speak(
          'Bạn cần cấp quyền camera để dùng chụp nhanh.',
          title: 'Chụp nhanh',
        );
        if (!mounted) return;
        Navigator.pop(context, LiveVisionAction.home);
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        await _speak(
          'Thiết bị này chưa có camera khả dụng.',
          title: 'Chụp nhanh',
        );
        if (!mounted) return;
        Navigator.pop(context, LiveVisionAction.home);
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
        _mode = _LiveVisionMode.caption;
        _statusText = 'Sẵn sàng';
        _overlayText = 'Đưa camera vào vùng bạn muốn mô tả';
      });

      await _announceAndStart();
    } catch (_) {
      if (!mounted) return;
      await _speak(
        'Không mở được camera.',
        title: 'Chụp nhanh',
      );
      if (!mounted) return;
      Navigator.pop(context, LiveVisionAction.home);
    }
  }

  Future<void> _announceAndStart() async {
    _stopScanLoop(reason: 'Đang hướng dẫn');
    const prompt =
        'Đã mở mô tả trực tiếp. Tự đọc đang bật. Bạn chỉ cần đưa camera vào cảnh vật. '
        'Nếu muốn ra lệnh, hãy nhấn giữ ở bất kỳ đâu. '
        'Nếu muốn nghe lại hướng dẫn, hãy chạm nhanh hai lần ở bất kỳ đâu. '
        'Bạn có thể nói: về trang chủ, đọc báo, quét chữ, lịch sử, tác vụ hoặc cài đặt.';
    _lastPromptNorm = _norm(prompt);

    if (mounted) {
      setState(() {
        _statusText = 'Đang hướng dẫn';
        _mode = _LiveVisionMode.caption;
        _overlayText = 'Đưa camera vào vùng bạn muốn mô tả';
      });
    }

    await _speak(prompt, title: 'Chụp nhanh');
    if (!mounted) return;

    _startScanLoop();
    unawaited(_analyzeCurrentFrame(forceSpeak: false));
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
          await Future.delayed(const Duration(milliseconds: 250));
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

  Future<bool> _handleNavigationCommand(String raw) async {
    final n = _norm(raw);

    if (_isExitCommand(n)) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.home);
      return true;
    }

    if (n.contains('trang chu') || n == 'home' || n.contains('ve home')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.home);
      return true;
    }

    if (n.contains('doc bao') ||
        n.contains('tin tuc') ||
        n.contains('bao moi') ||
        n.contains('tin moi')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.news);
      return true;
    }

    if (n.contains('xem lich su') ||
        n.contains('mo lich su') ||
        n.contains('vao lich su') ||
        n == 'lich su') {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.history);
      return true;
    }

    if (n.contains('tac vu')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.tasks);
      return true;
    }

    if (n.contains('cai dat') || n.contains('setting')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.settings);
      return true;
    }

    if (_looksLikeOcrIntent(n) &&
        (n.contains('mo ') ||
            n.contains('chuyen') ||
            n.contains('vao ') ||
            n.contains('man hinh'))) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.ocr);
      return true;
    }

    return false;
  }

  Future<void> _analyzeCurrentFrame({required bool forceSpeak}) async {
    final camera = _camera;
    if (!_scanEnabled || _busy || camera == null || !camera.value.isInitialized) {
      return;
    }

    _busy = true;

    if (mounted) {
      setState(() {
        _statusText =
        _mode == _LiveVisionMode.ocr ? 'Đang đọc chữ...' : 'Đang mô tả...';
      });
    }

    XFile? shot;
    try {
      shot = await camera.takePicture();
      final api = context.read<VisionApi>();

      String resultText = '';
      int? historyId;

      if (_mode == _LiveVisionMode.ocr) {
        final res = await api.ocr(shot.path);
        resultText = _cleanResult(
          res.text,
          fallback: 'Chưa thấy chữ rõ để đọc.',
        );
        historyId = res.historyId;
      } else {
        final res = await api.caption(shot.path);
        resultText = _cleanResult(
          res.caption,
          fallback: 'Mình chưa mô tả rõ được khung hình này.',
        );
        historyId = res.historyId;
      }

      if (!mounted) return;

      setState(() {
        _overlayText = resultText;
        _statusText = 'Đã cập nhật';
      });

      context.read<PlayerController>().setNow(
        _screenTitle,
        _preview(resultText),
        newDetails: resultText,
      );

      if (historyId != null) {
        final auth = context.read<AuthController>();
        if (auth.loggedIn) {
          final type = _mode == _LiveVisionMode.ocr ? 'ocr' : 'caption';
          unawaited(
            context.read<HistoryController>().load(
              type: type,
              announce: false,
            ),
          );
        }
      }

      if (forceSpeak || (_autoSpeak && _shouldAutoSpeak(resultText))) {
        await _speak(resultText, title: _screenTitle);
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

  String _cleanResult(String raw, {required String fallback}) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return fallback;
    return value;
  }

  void _startScanLoop() {
    _scanEnabled = true;
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(_scanInterval, (_) {
      unawaited(_analyzeCurrentFrame(forceSpeak: false));
    });

    if (mounted) {
      setState(() {
        _statusText = 'Đang quét trực tiếp';
      });
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
    await _stopSpeechImmediate();

    if (_scanEnabled) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      return;
    }

    _startScanLoop();
    unawaited(_analyzeCurrentFrame(forceSpeak: false));
  }

  Future<void> _listenCommandImmediately() async {
    if (_initializing) return;

    await _stopSpeechImmediate();
    _stopScanLoop(reason: 'Đang nghe lệnh');
    _lastPromptNorm = '';

    if (mounted) {
      setState(() {
        _statusText = 'Đang nghe lệnh';
      });
    }

    await _listenOnce(_handleRuntimeCommand);
  }

  Future<void> _handleRuntimeCommand(String raw) async {
    if (await _handleNavigationCommand(raw)) return;

    final n = _norm(raw);

    if (_isPauseCommand(n)) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      return;
    }

    if (_isResumeCommand(n)) {
      _startScanLoop();
      unawaited(_analyzeCurrentFrame(forceSpeak: false));
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

    if (_looksLikeOcrIntent(n)) {
      setState(() {
        _mode = _LiveVisionMode.ocr;
        _statusText = 'Đang quét trực tiếp';
        _overlayText = 'Đưa camera gần vùng có chữ';
      });
      _startScanLoop();
      unawaited(_analyzeCurrentFrame(forceSpeak: true));
      return;
    }

    if (_looksLikeCaptionIntent(n)) {
      setState(() {
        _mode = _LiveVisionMode.caption;
        _statusText = 'Đang quét trực tiếp';
        _overlayText = 'Đưa camera vào vùng bạn muốn mô tả';
      });
      _startScanLoop();
      unawaited(_analyzeCurrentFrame(forceSpeak: true));
      return;
    }

    _startScanLoop();
    unawaited(_analyzeCurrentFrame(forceSpeak: true));
  }

  Future<void> _stopSpeechImmediate() async {
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
    context.read<PlayerController>().setPlaying(false);

    if (mounted && _speaking) {
      setState(() {
        _speaking = false;
      });
    }
  }

  Future<void> _speak(
      String text, {
        required String title,
      }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final player = context.read<PlayerController>();
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();

    final preview =
    value.length > 88 ? '${value.substring(0, 88)}...' : value;

    player.setNow(
      title,
      preview,
      newDetails: value,
    );
    player.setPlaying(true);

    if (mounted) {
      setState(() {
        _speaking = true;
      });
    }

    try {
      await voice.stop();
      await tts.stop();
      await tts.speak(value);
    } finally {
      player.setPlaying(false);
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  Future<void> _speakHelp() async {
    await _speak(_helpText, title: 'Chụp nhanh');
  }

  Future<void> _onHoldToListen() async {
    await _listenCommandImmediately();
  }

  bool _isExitCommand(String n) {
    return n.contains('thoat') ||
        n.contains('dong') ||
        n.contains('tat camera') ||
        n.contains('dung chup nhanh');
  }

  bool _isPauseCommand(String n) {
    return n.contains('tam dung') ||
        n.contains('dung lai') ||
        n == 'dung';
  }

  bool _isResumeCommand(String n) {
    return n.contains('tiep tuc') ||
        n.contains('quet tiep') ||
        n.contains('bat lai');
  }

  bool _isSpeakAgainCommand(String n) {
    return n.contains('doc lai') ||
        n.contains('nghe lai') ||
        n.contains('lap lai');
  }

  bool _looksLikeOcrIntent(String n) {
    return n.contains('quet chu') ||
        n.contains('doc chu') ||
        n.contains('o c r') ||
        n.contains('ocr') ||
        n.contains('van ban') ||
        n.contains('doc bien') ||
        n.contains('doc bang');
  }

  bool _looksLikeCaptionIntent(String n) {
    return n.contains('mo ta') ||
        n.contains('canh vat') ||
        n.contains('do vat') ||
        n.contains('xem giup') ||
        n.contains('nhin giup') ||
        n.contains('tim do');
  }

  String _preview(String text) {
    final value = text.trim();
    if (value.isEmpty) return '(Trống)';
    if (value.length <= 80) return value;
    return '${value.substring(0, 80)}...';
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
    final camera = _camera;
    final voice = context.watch<VoiceController>();

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _onHoldToListen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _speakHelp,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _initializing || camera == null || !camera.value.isInitialized
              ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
              : Stack(
            children: [
              Positioned.fill(
                child: CameraPreview(camera),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.30),
                        Colors.black.withOpacity(0.12),
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _RoundTopButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () =>
                                Navigator.pop(context, LiveVisionAction.home),
                          ),
                          const SizedBox(width: 10),
                          _TopChip(
                            label: _modeChipLabel,
                            active: true,
                          ),
                          const SizedBox(width: 8),
                          _TopChip(
                            label: _autoSpeak ? 'Tự đọc' : 'Không tự đọc',
                            active: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              voice.isListening
                                  ? Icons.mic_rounded
                                  : (_scanEnabled
                                  ? Icons.visibility_rounded
                                  : Icons.pause_circle_outline_rounded),
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                voice.isListening
                                    ? (voice.lastWords.trim().isEmpty
                                    ? 'Đang nghe lệnh'
                                    : 'Đang nghe: ${voice.lastWords}')
                                    : _statusText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.42),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _screenTitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 110,
                                maxHeight: 190,
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  _overlayText.trim().isEmpty
                                      ? '(Trống)'
                                      : _overlayText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _VisionActionButton(
                                    icon: _scanEnabled
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    label: _scanEnabled
                                        ? 'Tạm dừng'
                                        : 'Tiếp tục',
                                    onTap: _toggleScan,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VisionActionButton(
                                    icon: Icons.mic_rounded,
                                    label: 'Ra lệnh',
                                    onTap: _listenCommandImmediately,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _VisionActionButton(
                                    icon: Icons.volume_up_rounded,
                                    label: 'Đọc lại',
                                    onTap: () =>
                                        _speak(_overlayText, title: _screenTitle),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VisionActionButton(
                                    icon: _autoSpeak
                                        ? Icons.hearing_disabled_rounded
                                        : Icons.record_voice_over_rounded,
                                    label: _autoSpeak
                                        ? 'Tắt tự đọc'
                                        : 'Bật tự đọc',
                                    onTap: () async {
                                      await _stopSpeechImmediate();
                                      if (!mounted) return;
                                      setState(() {
                                        _autoSpeak = !_autoSpeak;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _helpText,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_busy)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.06),
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

class _TopChip extends StatelessWidget {
  final String label;
  final bool active;

  const _TopChip({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.brandBrown
            : Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(active ? 1 : 0.92),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoundTopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundTopButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.28),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _VisionActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;

  const _VisionActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBrown,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap == null ? null : () => onTap!.call(),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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