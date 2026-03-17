import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../data/services/vision_api.dart';
import '../auth/auth_controller.dart';
import '../history/history_controller.dart';
import '../player/player_controller.dart';
import '../voice/voice_controller.dart';

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
  bool _autoSpeak = false;

  int _listenEpoch = 0;
  String _lastPromptNorm = '';
  String _lastAutoSpeakNorm = '';

  _LiveVisionMode _mode = _LiveVisionMode.caption;

  String _focusHint = '';
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
          'Bạn cần cấp quyền camera để dùng chụp nhanh.',
          title: 'Chụp nhanh',
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
          title: 'Chụp nhanh',
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

      await _askInitialIntent();
    } catch (_) {
      if (!mounted) return;
      await _speak(
        'Không mở được camera.',
        title: 'Chụp nhanh',
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _askInitialIntent() async {
    _stopScanLoop(reason: 'Đang chờ yêu cầu');
    final prompt =
        'Bạn muốn mình mô tả gì? Bạn có thể nói mô tả cảnh vật, tìm đồ vật, hoặc đọc chữ.';

    _lastPromptNorm = _norm(prompt);

    if (mounted) {
      setState(() {
        _statusText = 'Đang nghe yêu cầu ban đầu';
      });
    }

    await _speak(prompt, title: 'Chụp nhanh');

    if (!mounted) return;
    await Future.delayed(Duration(milliseconds: _settleMs(prompt)));

    if (!mounted) return;
    await _listenOnce(_handleInitialIntent);
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

  Future<void> _handleInitialIntent(String raw) async {
    final n = _norm(raw);

    if (_isExitCommand(n)) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    _applyIntent(raw);

    final confirm = _mode == _LiveVisionMode.ocr
        ? 'Đã chuyển sang đọc chữ trực tiếp.'
        : 'Đã chuyển sang mô tả trực tiếp.';

    await _speak(confirm, title: _screenTitle);

    if (!mounted) return;
    _startScanLoop();
    unawaited(_analyzeCurrentFrame(forceSpeak: false));
  }

  void _applyIntent(String raw) {
    final n = _norm(raw);

    if (_looksLikeOcrIntent(n)) {
      _mode = _LiveVisionMode.ocr;
      _focusHint = _extractFocusHint(raw, removeTextWords: true);
      if (_focusHint.isEmpty) {
        _focusHint = 'văn bản trước mặt';
      }
    } else {
      _mode = _LiveVisionMode.caption;
      _focusHint = _extractFocusHint(raw, removeTextWords: false);
      if (_focusHint.isEmpty) {
        _focusHint = 'cảnh trước mặt';
      }
    }

    if (mounted) {
      setState(() {
        _statusText = 'Sẵn sàng quét';
        _overlayText = _mode == _LiveVisionMode.ocr
            ? 'Đưa camera gần vùng có chữ'
            : 'Di camera tới vùng bạn muốn mô tả';
      });
    }
  }

  String _extractFocusHint(String raw, {required bool removeTextWords}) {
    var value = raw.trim();

    final patterns = <RegExp>[
      RegExp(r'^\s*mô tả\s+', caseSensitive: false),
      RegExp(r'^\s*mo ta\s+', caseSensitive: false),
      RegExp(r'^\s*tìm\s+', caseSensitive: false),
      RegExp(r'^\s*tim\s+', caseSensitive: false),
      RegExp(r'^\s*nhìn\s+', caseSensitive: false),
      RegExp(r'^\s*nhin\s+', caseSensitive: false),
      RegExp(r'^\s*xem\s+', caseSensitive: false),
      RegExp(r'^\s*đọc\s+', caseSensitive: false),
      RegExp(r'^\s*doc\s+', caseSensitive: false),
      RegExp(r'^\s*giúp mình\s+', caseSensitive: false),
      RegExp(r'^\s*giup minh\s+', caseSensitive: false),
      RegExp(r'^\s*cho mình biết\s+', caseSensitive: false),
      RegExp(r'^\s*cho minh biet\s+', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      value = value.replaceFirst(pattern, '');
    }

    if (removeTextWords) {
      final textPatterns = <RegExp>[
        RegExp(r'\bchữ\b', caseSensitive: false),
        RegExp(r'\bchu\b', caseSensitive: false),
        RegExp(r'\bvăn bản\b', caseSensitive: false),
        RegExp(r'\bvan ban\b', caseSensitive: false),
        RegExp(r'\bbiển\b', caseSensitive: false),
        RegExp(r'\bbien\b', caseSensitive: false),
        RegExp(r'\bbảng\b', caseSensitive: false),
        RegExp(r'\bbang\b', caseSensitive: false),
      ];

      for (final pattern in textPatterns) {
        value = value.replaceAll(pattern, '');
      }
    }

    return value.trim();
  }

  Future<void> _analyzeCurrentFrame({required bool forceSpeak}) async {
    final camera = _camera;
    if (!_scanEnabled || _busy || camera == null || !camera.value.isInitialized) {
      return;
    }

    _busy = true;
    if (mounted) {
      setState(() {
        _statusText = _mode == _LiveVisionMode.ocr
            ? 'Đang đọc chữ...'
            : 'Đang mô tả...';
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
    if (_scanEnabled) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      await _speak('Đã tạm dừng quét.', title: _screenTitle);
      return;
    }

    _startScanLoop();
    await _speak('Đã tiếp tục quét.', title: _screenTitle);
    if (!mounted) return;
    unawaited(_analyzeCurrentFrame(forceSpeak: false));
  }

  Future<void> _listenCommand() async {
    if (_initializing) return;

    final prompt = 'Mình đang nghe lệnh.';
    _lastPromptNorm = _norm(prompt);

    if (mounted) {
      setState(() {
        _statusText = 'Đang nghe lệnh';
      });
    }

    await _listenOnce(_handleRuntimeCommand);
  }

  Future<void> _handleRuntimeCommand(String raw) async {
    final n = _norm(raw);

    if (_isExitCommand(n)) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    if (_isPauseCommand(n)) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      await _speak('Đã tạm dừng quét.', title: _screenTitle);
      return;
    }

    if (_isResumeCommand(n)) {
      _startScanLoop();
      await _speak('Đã tiếp tục quét.', title: _screenTitle);
      if (!mounted) return;
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
      await _speak('Đã bật đọc tự động.', title: _screenTitle);
      return;
    }

    if (n.contains('tat doc tu dong')) {
      setState(() {
        _autoSpeak = false;
      });
      await _speak('Đã tắt đọc tự động.', title: _screenTitle);
      return;
    }

    if (_looksLikeOcrIntent(n)) {
      setState(() {
        _mode = _LiveVisionMode.ocr;
        final value = _extractFocusHint(raw, removeTextWords: true);
        if (value.isNotEmpty) {
          _focusHint = value;
        }
      });
      await _speak('Đã chuyển sang đọc chữ trực tiếp.', title: _screenTitle);
      _startScanLoop();
      if (!mounted) return;
      unawaited(_analyzeCurrentFrame(forceSpeak: true));
      return;
    }

    if (_looksLikeCaptionIntent(n)) {
      setState(() {
        _mode = _LiveVisionMode.caption;
        final value = _extractFocusHint(raw, removeTextWords: false);
        if (value.isNotEmpty) {
          _focusHint = value;
        }
      });
      await _speak('Đã chuyển sang mô tả trực tiếp.', title: _screenTitle);
      _startScanLoop();
      if (!mounted) return;
      unawaited(_analyzeCurrentFrame(forceSpeak: true));
      return;
    }

    final hint = raw.trim();
    if (hint.isNotEmpty) {
      setState(() {
        _focusHint = hint;
      });
      await _speak(
        'Mình đã cập nhật điều bạn muốn xem.',
        title: _screenTitle,
      );
      _startScanLoop();
      if (!mounted) return;
      unawaited(_analyzeCurrentFrame(forceSpeak: true));
      return;
    }

    await _speak(
      'Mình chưa hiểu. Bạn có thể nói đọc chữ, mô tả cảnh, đọc lại, tạm dừng, tiếp tục hoặc thoát.',
      title: _screenTitle,
    );
  }

  bool _looksLikeOcrIntent(String n) {
    return n.contains('doc chu') ||
        n.contains('quet chu') ||
        n.contains('ocr') ||
        n.contains('van ban') ||
        n.contains('bien bao') ||
        n.contains('bang hieu') ||
        n.contains('gia tien') ||
        n.contains('noi dung tren') ||
        n.contains('chu tren');
  }

  bool _looksLikeCaptionIntent(String n) {
    return n.contains('mo ta') ||
        n.contains('canh') ||
        n.contains('vat') ||
        n.contains('do vat') ||
        n.contains('xung quanh') ||
        n.contains('tim giup') ||
        n.contains('nhin xem') ||
        n.contains('cai gi truoc mat');
  }

  bool _isExitCommand(String n) {
    return n.contains('thoat') ||
        n.contains('dong') ||
        n.contains('quay lai') ||
        n == 've';
  }

  bool _isPauseCommand(String n) {
    return n.contains('tam dung') ||
        n.contains('dung lai') ||
        n == 'dung';
  }

  bool _isResumeCommand(String n) {
    return n.contains('tiep tuc') ||
        n.contains('quet tiep') ||
        n.contains('scan tiep');
  }

  bool _isSpeakAgainCommand(String n) {
    return n.contains('doc lai') ||
        n.contains('noi lai') ||
        n.contains('phat lai');
  }

  Future<void> _setMode(_LiveVisionMode mode) async {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      if (_focusHint.isEmpty) {
        _focusHint = mode == _LiveVisionMode.ocr
            ? 'văn bản trước mặt'
            : 'cảnh trước mặt';
      }
    });

    await _speak(
      mode == _LiveVisionMode.ocr
          ? 'Đã chuyển sang đọc chữ trực tiếp.'
          : 'Đã chuyển sang mô tả trực tiếp.',
      title: _screenTitle,
    );

    _startScanLoop();
    if (!mounted) return;
    unawaited(_analyzeCurrentFrame(forceSpeak: true));
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
    if (value > 3200) return 3200;
    return value;
  }

  String _preview(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  String get _screenTitle =>
      _mode == _LiveVisionMode.ocr ? 'OCR trực tiếp' : 'Mô tả trực tiếp';

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ModeChip(
                              label: 'Mô tả',
                              selected: _mode == _LiveVisionMode.caption,
                              onTap: () => _setMode(_LiveVisionMode.caption),
                            ),
                            _ModeChip(
                              label: 'Quét chữ',
                              selected: _mode == _LiveVisionMode.ocr,
                              onTap: () => _setMode(_LiveVisionMode.ocr),
                            ),
                            _SmallStatusChip(
                              label: _busy ? 'Đang xử lý' : _statusText,
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
                        Text(
                          _screenTitle,
                          style: const TextStyle(
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
                                label: voice.isListening ? 'Đang nghe' : 'Ra lệnh',
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
                                        ? 'Đã bật đọc tự động.'
                                        : 'Đã tắt đọc tự động.',
                                    title: _screenTitle,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Lệnh gợi ý: đọc chữ, mô tả cảnh, đọc lại, tạm dừng, tiếp tục, thoát',
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
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brandBrown
          : Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
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