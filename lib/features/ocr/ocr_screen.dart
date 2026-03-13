import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../auth/auth_controller.dart';
import '../caption/caption_screen.dart';
import '../history/history_controller.dart';
import '../news/news_assistant_screen.dart';
import '../player/player_controller.dart';
import '../player/player_sliding_panel.dart';
import '../voice/voice_controller.dart';
import 'ocr_camera_screen.dart';
import 'ocr_controller.dart';

enum _OcrStage {
  idle,
  waitingSource,
  waitingGalleryChoice,
  processing,
  waitingNextAction,
}

class OcrScreen extends StatefulWidget {
  final Future<void> Function()? onGoHome;
  final Future<void> Function()? onGoHistory;
  final Future<void> Function()? onGoTasks;
  final Future<void> Function()? onGoSettings;
  final Future<void> Function()? onOpenNews;
  final Future<void> Function()? onOpenCaption;

  const OcrScreen({
    super.key,
    this.onGoHome,
    this.onGoHistory,
    this.onGoTasks,
    this.onGoSettings,
    this.onOpenNews,
    this.onOpenCaption,
  });

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  static const double _playerBottomOffset = 8;
  static const double _actionsBottomOffset = 106;

  _OcrStage _stage = _OcrStage.idle;
  int _listenEpoch = 0;
  String _lastPromptNorm = '';

  String _lastSpokenText = '';
  String _lastSpokenTitle = 'OCR';
  String _latestImagePath = '';

  late final TtsService _tts;
  late final VoiceController _voice;
  late final PlayerController _player;
  late final OcrController _ocr;

  @override
  void initState() {
    super.initState();

    _tts = context.read<TtsService>();
    _voice = context.read<VoiceController>();
    _player = context.read<PlayerController>();
    _ocr = context.read<OcrController>();

    _tts.isSpeaking.addListener(_syncPlayerSpeaking);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _askSource();
    });
  }

  @override
  void dispose() {
    _listenEpoch++;
    _voice.stop();
    _tts.isSpeaking.removeListener(_syncPlayerSpeaking);
    super.dispose();
  }

  void _syncPlayerSpeaking() {
    _player.setPlaying(_tts.isSpeaking.value);
  }

  Future<void> _askSource() async {
    _stage = _OcrStage.waitingSource;
    if (mounted) setState(() {});

    await _promptAndListen(
      "Bạn muốn chụp ảnh để quét hay chọn ảnh từ thư viện?",
      _handleSourceUtterance,
      settleMs: 1450,
    );
  }

  Future<void> _askGalleryChoice() async {
    _stage = _OcrStage.waitingGalleryChoice;
    if (mounted) setState(() {});

    await _promptAndListen(
      "Bạn muốn quét ảnh mới nhất hay ảnh thứ 2?",
      _handleGalleryChoiceUtterance,
      settleMs: 1400,
    );
  }

  Future<void> _askNextAction() async {
    _stage = _OcrStage.waitingNextAction;
    if (mounted) setState(() {});

    await _promptAndListen(
      "Bạn muốn sử dụng thêm tính năng gì khác? Bạn có thể nói: quét lại, đọc báo, mô tả ảnh, lịch sử, tác vụ, cài đặt, trang chủ hoặc thoát.",
      _handleNextActionUtterance,
      settleMs: 1500,
    );
  }

  Future<void> _promptAndListen(
      String prompt,
      Future<void> Function(String raw) onFinal, {
        int settleMs = 1200,
      }) async {
    final epoch = ++_listenEpoch;

    await _voice.stop();
    await _tts.stop();

    _lastPromptNorm = _norm(prompt);
    await _speakWithPlayer(prompt, title: "OCR");

    await Future.delayed(Duration(milliseconds: settleMs));

    if (!mounted || epoch != _listenEpoch) return;

    await _voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;
        final n = _norm(text);

        if (n.isEmpty || _isEchoFromTts(n)) {
          await Future.delayed(const Duration(milliseconds: 350));
          if (!mounted || epoch != _listenEpoch) return;

          if (_stage == _OcrStage.waitingSource) {
            await _askSource();
          } else if (_stage == _OcrStage.waitingGalleryChoice) {
            await _askGalleryChoice();
          } else if (_stage == _OcrStage.waitingNextAction) {
            await _askNextAction();
          }
          return;
        }

        await onFinal(text);
      },
    );
  }

  bool _isEchoFromTts(String n) {
    if (_lastPromptNorm.isEmpty) return false;

    const fullPrompts = [
      'ban muon chup anh de quet hay chon anh tu thu vien',
      'ban muon quet anh moi nhat hay anh thu 2',
      'ban muon su dung them tinh nang gi khac ban co the noi quet lai doc bao mo ta anh lich su tac vu cai dat trang chu hoac thoat',
    ];

    for (final p in fullPrompts) {
      if (n == p) return true;
    }

    // Chỉ chặn khi STT nghe lại gần như nguyên câu prompt,
    // không chặn các  trả lời ngắn như "chọn ảnh từ thư viện", "ảnh mới nhất", "ảnh thứ 2"
    if (n.length >= 28 && _lastPromptNorm.contains(n)) return true;

    return false;
  }

  Future<void> _handleSourceUtterance(String raw) async {
    final n = _norm(raw);

    if (n.contains('chup anh') || n.contains('camera') || n == 'chup') {
      await _openCameraCaptureFlow();
      return;
    }

    if (n.contains('thu vien') ||
        n.contains('gallery') ||
        n.contains('chon anh') ||
        n.contains('anh tu thu vien') ||
        n.contains('lay anh tu thu vien')) {
      await _askGalleryChoice();
      return;
    }

    await _speakWithPlayer(
      'Mình chưa hiểu. Bạn có thể nói chụp ảnh hoặc chọn ảnh từ thư viện.',
      title: 'OCR',
    );
    await Future.delayed(const Duration(milliseconds: 400));
    await _askSource();
  }

  Future<void> _handleGalleryChoiceUtterance(String raw) async {
    final n = _norm(raw);

    if (n.contains('moi nhat') ||
        n.contains('gan nhat') ||
        n.contains('anh moi') ||
        n == 'mot' ||
        n == 'anh 1') {
      await _pickRecentGalleryImage(0);
      return;
    }

    if (n.contains('thu 2') ||
        n.contains('thu hai') ||
        n.contains('anh 2') ||
        n.contains('so 2') ||
        n == 'hai') {
      await _pickRecentGalleryImage(1);
      return;
    }

    await _speakWithPlayer(
      'Mình chưa hiểu. Bạn có thể nói ảnh mới nhất hoặc ảnh thứ 2.',
      title: 'OCR',
    );
    await Future.delayed(const Duration(milliseconds: 400));
    await _askGalleryChoice();
  }

  Future<void> _handleNextActionUtterance(String raw) async {
    final n = _norm(raw);

    if (n.contains('thoat') || n.contains('dung')) {
      await _voice.stop();
      await _tts.stop();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    if (n.contains('quet lai') || n.contains('quay lai') || n == 'ocr') {
      await _askSource();
      return;
    }

    if (n.contains('doc bao') ||
        n.contains('tin tuc') ||
        n.contains('tin moi')) {
      await _popToRoot();
      if (widget.onOpenNews != null) {
        await widget.onOpenNews!();
      }
      return;
    }

    if (n.contains('mo ta anh') || n.contains('caption')) {
      await _popToRoot();
      if (widget.onOpenCaption != null) {
        await widget.onOpenCaption!();
      }
      return;
    }

    if (n.contains('lich su')) {
      await _popToRoot();
      if (widget.onGoHistory != null) {
        await widget.onGoHistory!();
      }
      return;
    }

    if (n.contains('tac vu')) {
      await _popToRoot();
      if (widget.onGoTasks != null) {
        await widget.onGoTasks!();
      }
      return;
    }

    if (n.contains('cai dat')) {
      await _popToRoot();
      if (widget.onGoSettings != null) {
        await widget.onGoSettings!();
      }
      return;
    }

    if (n.contains('trang chu') || n == 'home') {
      await _popToRoot();
      if (widget.onGoHome != null) {
        await widget.onGoHome!();
      }
      return;
    }

    if (n.contains('camera') || n.contains('chup')) {
      await _openCameraCaptureFlow();
      return;
    }

    await _speakWithPlayer(
      "Mình chưa hiểu. Bạn có thể nói quét lại, đọc báo, mô tả ảnh, lịch sử, tác vụ, cài đặt, trang chủ hoặc thoát.",
      title: "OCR",
    );
    await Future.delayed(const Duration(milliseconds: 450));
    await _askNextAction();
  }

  Future<void> _popToRoot() async {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await Future.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _openCameraCaptureFlow() async {
    await _voice.stop();
    await _tts.stop();

    if (!mounted) return;

    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const OcrCameraScreen(),
      ),
    );

    if (!mounted || path == null || path.trim().isEmpty) {
      await Future.delayed(const Duration(milliseconds: 250));
      await _askSource();
      return;
    }

    await _runOcr(path);
  }

  Future<void> _pickRecentGalleryImage(int index) async {
    _stage = _OcrStage.processing;
    if (mounted) setState(() {});

    await _voice.stop();
    await _tts.stop();

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        await _speakWithPlayer(
          "Bạn cần cấp quyền thư viện ảnh để mình lấy ảnh gần nhất.",
          title: "OCR",
        );
        await Future.delayed(const Duration(milliseconds: 400));
        await _askSource();
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
      );

      if (paths.isEmpty) {
        await _speakWithPlayer(
          "Mình chưa thấy ảnh nào trong thư viện.",
          title: "OCR",
        );
        await Future.delayed(const Duration(milliseconds: 400));
        await _askSource();
        return;
      }

      final recent = await paths.first.getAssetListPaged(page: 0, size: 10);

      if (recent.length <= index) {
        await _speakWithPlayer(
          index == 0
              ? "Mình chưa lấy được ảnh mới nhất."
              : "Mình chưa thấy đủ ảnh để lấy ảnh thứ 2.",
          title: "OCR",
        );
        await Future.delayed(const Duration(milliseconds: 400));
        await _askGalleryChoice();
        return;
      }

      final file = await recent[index].file;
      if (file == null || !file.existsSync()) {
        await _speakWithPlayer(
          "Mình chưa mở được ảnh trong thư viện.",
          title: "OCR",
        );
        await Future.delayed(const Duration(milliseconds: 400));
        await _askGalleryChoice();
        return;
      }

      await _runOcr(file.path);
    } catch (_) {
      await _speakWithPlayer(
        "Có lỗi khi lấy ảnh từ thư viện.",
        title: "OCR",
      );
      await Future.delayed(const Duration(milliseconds: 400));
      await _askGalleryChoice();
    }
  }

  Future<void> _runOcr(String path) async {
    _stage = _OcrStage.processing;
    if (mounted) setState(() {});

    try {
      _latestImagePath = path;

      await _speakWithPlayer(
        "Đang quét chữ, bạn chờ một chút nhé.",
        title: "OCR",
      );

      final res = await _ocr.runOcr(path, speakResult: false);
      final result = _ocr.text.trim().isEmpty
          ? "Mình chưa nhận diện được văn bản rõ ràng."
          : _ocr.text.trim();

      await _reloadHistoryIfNeeded(res.historyId);

      await _speakWithPlayer(result, title: "Kết quả OCR");
      await _askNextAction();
    } catch (_) {
      await _speakWithPlayer(
        "Có lỗi khi quét chữ. Bạn thử lại nhé.",
        title: "OCR",
      );
      await Future.delayed(const Duration(milliseconds: 400));
      await _askSource();
    }
  }

  Future<void> _reloadHistoryIfNeeded(int? historyId) async {
    if (historyId == null) return;

    try {
      final loggedIn = context.read<AuthController>().loggedIn;
      if (!loggedIn) return;

      await context.read<HistoryController>().load(
        type: 'ocr',
        announce: false,
      );
    } catch (_) {}
  }

  Future<void> _speakWithPlayer(
      String text, {
        required String title,
      }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    _lastSpokenTitle = title;
    _lastSpokenText = value;

    final preview = value.length > 88 ? "${value.substring(0, 88)}..." : value;
    _player.setNow(title, preview, newDetails: value);

    await _tts.stop();
    await _tts.speak(value);
  }

  Future<void> _toggleMic() async {
    if (_voice.isListening) {
      await _voice.stop();
      return;
    }

    if (_stage == _OcrStage.waitingSource) {
      await _askSource();
      return;
    }

    if (_stage == _OcrStage.waitingGalleryChoice) {
      await _askGalleryChoice();
      return;
    }

    if (_stage == _OcrStage.waitingNextAction) {
      await _askNextAction();
      return;
    }

    await _askSource();
  }

  Future<void> _onPlayPause() async {
    if (_tts.isSpeaking.value) {
      await _tts.stop();
      _player.setPlaying(false);
      return;
    }

    if (_lastSpokenText.trim().isEmpty) {
      await _speakWithPlayer(
        "Bạn chưa có nội dung để phát lại.",
        title: "OCR",
      );
      return;
    }

    await _speakWithPlayer(
      _lastSpokenText,
      title: _lastSpokenTitle,
    );
  }

  Future<void> _onStopTts() async {
    await _tts.stop();
    _player.setPlaying(false);
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

  String _hintText() {
    switch (_stage) {
      case _OcrStage.waitingSource:
        return "Gợi ý: nói “chụp ảnh” hoặc “chọn ảnh từ thư viện”.";
      case _OcrStage.waitingGalleryChoice:
        return "Gợi ý: nói “ảnh mới nhất” hoặc “ảnh thứ 2”.";
      case _OcrStage.waitingNextAction:
        return "Gợi ý: nói “quét lại”, “đọc báo”, “mô tả ảnh”, “lịch sử”, “tác vụ”, “cài đặt”, “trang chủ” hoặc “thoát”.";
      case _OcrStage.processing:
        return "Đang xử lý OCR...";
      case _OcrStage.idle:
        return "Sẵn sàng.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OcrController>();
    final voice = context.watch<VoiceController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quét chữ (OCR)"),
        actions: [
          IconButton(
            onPressed: _toggleMic,
            icon: Icon(
              voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.cardStroke.withValues(alpha: 0.75),
                  ),
                ),
                child: Text(
                  voice.isListening
                      ? (voice.lastWords.trim().isEmpty
                      ? "Đang nghe lệnh..."
                      : "Đang nghe: ${voice.lastWords}")
                      : _hintText(),
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.cardStroke.withValues(alpha: 0.8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Kết quả OCR",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: c.text.trim().isEmpty
                                ? null
                                : () => _speakWithPlayer(
                              c.text,
                              title: "Kết quả OCR",
                            ),
                            icon: const Icon(Icons.volume_up_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        c.text.trim().isEmpty ? "(Trống)" : c.text,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      if (_latestImagePath.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_latestImagePath),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (c.loading)
            Container(
              color: Colors.black.withValues(alpha: 0.14),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: _actionsBottomOffset,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.camera_alt_rounded,
                      text: "Chụp ảnh để quét",
                      filled: true,
                      onTap: c.loading ? null : _openCameraCaptureFlow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.photo_library_rounded,
                      text: "Chọn ảnh từ thư viện",
                      filled: false,
                      onTap: c.loading ? null : _askGalleryChoice,
                    ),
                  ),
                ],
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
                onMic: _toggleMic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.text,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.brandBrown : Colors.transparent;
    final fg = filled ? Colors.white : AppColors.brandBrown;
    final border = AppColors.brandBrown.withValues(alpha: 0.65);

    return SizedBox(
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}