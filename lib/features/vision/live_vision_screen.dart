import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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
  static const Duration _scanInterval = Duration(milliseconds: 900);
  static const Duration _sameSceneCooldown = Duration(seconds: 4);
  static const int _localNearDupMaxDistance = 6;

  CameraController? _camera;
  Timer? _scanTimer;
  CancelToken? _activeCancelToken;

  bool _initializing = true;
  bool _captureBusy = false;
  bool _analyzing = false;
  bool _scanEnabled = false;
  bool _autoSpeak = true;
  bool _speaking = false;

  int _listenEpoch = 0;
  int _requestEpoch = 0;
  int _speakEpoch = 0;

  String _lastPromptNorm = '';
  String _lastAutoSpeakNorm = '';

  _LiveVisionMode _mode = _LiveVisionMode.caption;
  _LiveVisionFrameHash? _lastSentFrameHash;
  DateTime? _lastSentFrameAt;

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
    _requestEpoch++;
    _speakEpoch++;
    _scanTimer?.cancel();
    _cancelActiveRequest();
    unawaited(context.read<TtsService>().stop());
    unawaited(context.read<VoiceController>().stop());
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
        await _speakInterruptible(
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
        await _speakInterruptible(
          'Thiết bị này chưa có camera khả dụng.',
          title: 'Chụp nhanh',
        );
        if (!mounted) return;
        Navigator.pop(context, LiveVisionAction.home);
        return;
      }

      final selected = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
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
      await _speakInterruptible(
        'Không mở được camera.',
        title: 'Chụp nhanh',
      );
      if (!mounted) return;
      Navigator.pop(context, LiveVisionAction.home);
    }
  }

  Future<void> _announceAndStart() async {
    _lastSentFrameHash = null;
    _lastSentFrameAt = null;
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

    await _speakInterruptible(prompt, title: 'Chụp nhanh');
    _startScanLoop();
    unawaited(_scanOnce(forceSpeak: false));
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
    final normalized = _norm(raw);

    if (_isExitCommand(normalized)) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.home);
      return true;
    }

    if (normalized.contains('trang chu') ||
        normalized == 'home' ||
        normalized.contains('ve home')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.home);
      return true;
    }

    if (normalized.contains('doc bao') ||
        normalized.contains('tin tuc') ||
        normalized.contains('bao moi') ||
        normalized.contains('tin moi')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.news);
      return true;
    }

    if (normalized.contains('xem lich su') ||
        normalized.contains('mo lich su') ||
        normalized.contains('vao lich su') ||
        normalized == 'lich su') {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.history);
      return true;
    }

    if (normalized.contains('tac vu')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.tasks);
      return true;
    }

    if (normalized.contains('cai dat') || normalized.contains('setting')) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.settings);
      return true;
    }

    if (_looksLikeOcrIntent(normalized) &&
        (normalized.contains('mo ') ||
            normalized.contains('chuyen') ||
            normalized.contains('vao ') ||
            normalized.contains('man hinh'))) {
      if (!mounted) return true;
      Navigator.pop(context, LiveVisionAction.ocr);
      return true;
    }

    return false;
  }

  Future<void> _scanOnce({required bool forceSpeak}) async {
    final camera = _camera;
    if (!_scanEnabled ||
        _initializing ||
        camera == null ||
        !camera.value.isInitialized ||
        _captureBusy) {
      return;
    }

    _captureBusy = true;
    XFile? shot;

    try {
      shot = await camera.takePicture();
      final file = File(shot.path);
      final bytes = await file.readAsBytes();
      final frameHash = _LiveVisionFrameHash.fromBytes(bytes);

      if (!_shouldSendFrame(frameHash)) {
        if (mounted && !_analyzing) {
          setState(() {
            _statusText = 'Khung hình gần giống, bỏ qua';
          });
        }
        await _deleteIfExists(file.path);
        return;
      }

      _lastSentFrameHash = frameHash;
      _lastSentFrameAt = DateTime.now();

      final filePath = shot.path;
      shot = null;
      unawaited(_dispatchFrame(filePath: filePath, forceSpeak: forceSpeak));
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusText = 'Không chụp được khung hình mới';
        });
      }
    } finally {
      if (shot != null) {
        await _deleteIfExists(shot.path);
      }
      _captureBusy = false;
    }
  }

  bool _shouldSendFrame(_LiveVisionFrameHash? candidate) {
    if (candidate == null) return true;

    final lastHash = _lastSentFrameHash;
    if (lastHash == null) return true;

    final distance = candidate.distanceTo(lastHash);
    if (distance > _localNearDupMaxDistance) {
      return true;
    }

    final lastAt = _lastSentFrameAt;
    if (lastAt == null) return false;

    return DateTime.now().difference(lastAt) >= _sameSceneCooldown;
  }

  Future<void> _dispatchFrame({
    required String filePath,
    required bool forceSpeak,
  }) async {
    final requestId = ++_requestEpoch;
    _cancelActiveRequest();

    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    if (mounted) {
      setState(() {
        _analyzing = true;
        _statusText = _mode == _LiveVisionMode.ocr
            ? 'Đang gửi khung chữ mới...'
            : 'Đang gửi khung cảnh mới...';
      });
    }

    try {
      final api = context.read<VisionApi>();

      String resultText = '';
      int? historyId;
      bool deduplicated = false;
      bool savedToHistory = false;

      if (_mode == _LiveVisionMode.ocr) {
        final res = await api.ocr(filePath, cancelToken: cancelToken);
        resultText = _cleanResult(
          res.text,
          fallback: 'Chưa thấy chữ rõ để đọc.',
        );
        historyId = res.historyId;
        deduplicated = res.deduplicated;
        savedToHistory = res.savedToHistory;
      } else {
        final res = await api.caption(filePath, cancelToken: cancelToken);
        resultText = _cleanResult(
          res.caption,
          fallback: 'Mình chưa mô tả rõ được khung hình này.',
        );
        historyId = res.historyId;
        deduplicated = res.deduplicated;
        savedToHistory = res.savedToHistory;
      }

      if (!mounted || cancelToken.isCancelled || requestId != _requestEpoch) {
        return;
      }

      setState(() {
        _overlayText = resultText;
        _statusText = deduplicated
            ? 'Khung hình gần giống, không lưu lặp'
            : 'Đã cập nhật';
      });

      context.read<PlayerController>().setNow(
        _screenTitle,
        _preview(resultText),
        newDetails: resultText,
      );

      final auth = context.read<AuthController>();
      if (historyId != null && auth.loggedIn && savedToHistory) {
        final type = _mode == _LiveVisionMode.ocr ? 'ocr' : 'caption';
        unawaited(
          context.read<HistoryController>().load(
            type: type,
            announce: false,
          ),
        );
      }

      if (forceSpeak || (_autoSpeak && _shouldAutoSpeak(resultText))) {
        await _speakInterruptible(resultText, title: _screenTitle);
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }
      if (mounted && requestId == _requestEpoch) {
        setState(() {
          _statusText = _dioMessage(error);
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestEpoch) {
        setState(() {
          _statusText = 'Có lỗi khi phân tích khung hình';
        });
      }
    } finally {
      await _deleteIfExists(filePath);

      if (_activeCancelToken == cancelToken) {
        _activeCancelToken = null;
      }

      if (mounted && requestId == _requestEpoch) {
        setState(() {
          _analyzing = false;
          if (_scanEnabled && !_speaking) {
            _statusText = 'Đang quét trực tiếp';
          }
        });
      }
    }
  }

  String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!.trim();
    }
    return 'Có lỗi khi gửi ảnh';
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void _cancelActiveRequest() {
    final token = _activeCancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('scene_changed');
    }
    _activeCancelToken = null;
  }

  bool _shouldAutoSpeak(String text) {
    final normalized = _norm(text);
    if (normalized.isEmpty) return false;
    if (normalized == _lastAutoSpeakNorm) return false;

    final now = DateTime.now();
    if (_lastAutoSpeakAt != null &&
        now.difference(_lastAutoSpeakAt!) < const Duration(milliseconds: 1200)) {
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
    _scanTimer = Timer.periodic(
      _scanInterval,
          (_) => unawaited(_scanOnce(forceSpeak: false)),
    );

    if (mounted) {
      setState(() {
        if (!_analyzing && !_speaking) {
          _statusText = 'Đang quét trực tiếp';
        }
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
    await _stopSpeechImmediate(cancelRequest: true);

    if (_scanEnabled) {
      _stopScanLoop(reason: 'Đã tạm dừng');
      return;
    }

    _startScanLoop();
    unawaited(_scanOnce(forceSpeak: false));
  }

  Future<void> _listenCommandImmediately() async {
    if (_initializing) return;

    await _stopSpeechImmediate(cancelRequest: true);
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

    final normalized = _norm(raw);

    if (_isPauseCommand(normalized)) {
      _cancelActiveRequest();
      _stopScanLoop(reason: 'Đã tạm dừng');
      return;
    }

    if (_isResumeCommand(normalized)) {
      _startScanLoop();
      unawaited(_scanOnce(forceSpeak: false));
      return;
    }

    if (_isSpeakAgainCommand(normalized)) {
      await _speakInterruptible(_overlayText, title: _screenTitle);
      return;
    }

    if (normalized.contains('bat doc tu dong')) {
      if (!mounted) return;
      setState(() {
        _autoSpeak = true;
      });
      await _speakInterruptible('Đã bật tự đọc.', title: _screenTitle);
      return;
    }

    if (normalized.contains('tat doc tu dong')) {
      if (!mounted) return;
      setState(() {
        _autoSpeak = false;
      });
      await _speakInterruptible('Đã tắt tự đọc.', title: _screenTitle);
      return;
    }

    if (_looksLikeOcrIntent(normalized)) {
      if (!mounted) return;
      setState(() {
        _mode = _LiveVisionMode.ocr;
        _statusText = 'Đang quét trực tiếp';
        _overlayText = 'Đưa camera gần vùng có chữ';
      });
      _lastSentFrameHash = null;
      _lastSentFrameAt = null;
      _startScanLoop();
      unawaited(_scanOnce(forceSpeak: true));
      return;
    }

    if (_looksLikeCaptionIntent(normalized)) {
      if (!mounted) return;
      setState(() {
        _mode = _LiveVisionMode.caption;
        _statusText = 'Đang quét trực tiếp';
        _overlayText = 'Đưa camera vào vùng bạn muốn mô tả';
      });
      _lastSentFrameHash = null;
      _lastSentFrameAt = null;
      _startScanLoop();
      unawaited(_scanOnce(forceSpeak: true));
      return;
    }

    _startScanLoop();
    unawaited(_scanOnce(forceSpeak: true));
  }

  Future<void> _stopSpeechImmediate({bool cancelRequest = false}) async {
    _speakEpoch++;
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();
    context.read<PlayerController>().setPlaying(false);

    if (cancelRequest) {
      _cancelActiveRequest();
    }

    if (mounted && _speaking) {
      setState(() {
        _speaking = false;
      });
    }
  }

  Future<void> _speakInterruptible(
      String text, {
        required String title,
      }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final speechId = ++_speakEpoch;
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
        _statusText = 'Đang đọc';
      });
    }

    await voice.stop();
    await tts.stop();

    unawaited(() async {
      if (speechId != _speakEpoch) return;
      try {
        await tts.speak(value);
      } finally {
        if (!mounted || speechId != _speakEpoch) return;
        player.setPlaying(false);
        setState(() {
          _speaking = false;
          if (_scanEnabled && !_analyzing) {
            _statusText = 'Đang quét trực tiếp';
          }
        });
      }
    }());
  }

  Future<void> _speakHelp() async {
    await _speakInterruptible(_helpText, title: 'Chụp nhanh');
  }

  Future<void> _onHoldToListen() async {
    await _listenCommandImmediately();
  }

  bool _isExitCommand(String normalized) {
    return normalized.contains('thoat') ||
        normalized.contains('dong') ||
        normalized.contains('tat camera') ||
        normalized.contains('dung chup nhanh');
  }

  bool _isPauseCommand(String normalized) {
    return normalized.contains('tam dung') ||
        normalized.contains('dung lai') ||
        normalized == 'dung';
  }

  bool _isResumeCommand(String normalized) {
    return normalized.contains('tiep tuc') ||
        normalized.contains('quet tiep') ||
        normalized.contains('bat lai');
  }

  bool _isSpeakAgainCommand(String normalized) {
    return normalized.contains('doc lai') ||
        normalized.contains('nghe lai') ||
        normalized.contains('lap lai');
  }

  bool _looksLikeOcrIntent(String normalized) {
    return normalized.contains('quet chu') ||
        normalized.contains('doc chu') ||
        normalized.contains('o c r') ||
        normalized.contains('ocr') ||
        normalized.contains('van ban') ||
        normalized.contains('doc bien') ||
        normalized.contains('doc bang');
  }

  bool _looksLikeCaptionIntent(String normalized) {
    return normalized.contains('mo ta') ||
        normalized.contains('canh vat') ||
        normalized.contains('do vat') ||
        normalized.contains('xem giup') ||
        normalized.contains('nhin giup') ||
        normalized.contains('tim do');
  }

  String _preview(String text) {
    final value = text.trim();
    if (value.isEmpty) return '(Trống)';
    if (value.length <= 80) return value;
    return '${value.substring(0, 80)}...';
  }

  String _norm(String input) {
    var value = input.toLowerCase().trim();

    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const without =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < withDia.length; i++) {
      value = value.replaceAll(withDia[i], without[i]);
    }

    value = value.replaceAll(RegExp(r'\s+'), ' ');
    return value;
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
        onDoubleTap: () => unawaited(_speakHelp()),
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
                                    onTap: () => _speakInterruptible(
                                      _overlayText,
                                      title: _screenTitle,
                                    ),
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
              if (_analyzing || _captureBusy)
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

class _LiveVisionFrameHash {
  final BigInt bits;

  const _LiveVisionFrameHash(this.bits);

  static _LiveVisionFrameHash? fromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: 9,
      height: 8,
    );
    final grayscale = img.grayscale(resized);

    var bits = BigInt.zero;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final left = grayscale.getPixel(x, y).r.toInt();
        final right = grayscale.getPixel(x + 1, y).r.toInt();
        bits = (bits << 1) | BigInt.from(left > right ? 1 : 0);
      }
    }

    return _LiveVisionFrameHash(bits);
  }

  int distanceTo(_LiveVisionFrameHash other) {
    var value = bits ^ other.bits;
    var count = 0;
    while (value > BigInt.zero) {
      if ((value & BigInt.one) == BigInt.one) {
        count++;
      }
      value = value >> 1;
    }
    return count;
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
        color: active ? AppColors.brandBrown : Colors.white.withOpacity(0.16),
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