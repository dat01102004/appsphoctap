import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../auth/auth_controller.dart';
import '../history/history_controller.dart';
import '../player/player_controller.dart';
import '../player/player_sliding_panel.dart';
import '../voice/voice_controller.dart';
import 'caption_camera_screen.dart';
import 'caption_controller.dart';

enum _CaptionStage {
  idle,
  waitingSource,
  waitingGalleryChoice,
  processing,
  waitingNextAction,
}

class CaptionScreen extends StatefulWidget {
  final Future<void> Function()? onGoHome;
  final Future<void> Function()? onGoHistory;
  final Future<void> Function()? onGoTasks;
  final Future<void> Function()? onGoSettings;
  final Future<void> Function()? onOpenNews;
  final Future<void> Function()? onOpenOcr;

  const CaptionScreen({
    super.key,
    this.onGoHome,
    this.onGoHistory,
    this.onGoTasks,
    this.onGoSettings,
    this.onOpenNews,
    this.onOpenOcr,
  });

  @override
  State<CaptionScreen> createState() => _CaptionScreenState();
}

class _CaptionScreenState extends State<CaptionScreen> {
  static const double _playerBottomOffset = 8;
  static const double _actionsBottomOffset = 106;

  final ImagePicker _picker = ImagePicker();

  _CaptionStage _stage = _CaptionStage.idle;
  int _listenEpoch = 0;

  String _lastPromptNorm = '';
  String _lastSpokenText = '';
  String _lastSpokenTitle = 'Mô tả ảnh';
  String _latestImagePath = '';

  late final TtsService _tts;
  late final VoiceController _voice;
  late final PlayerController _player;
  late final CaptionController _caption;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsService>();
    _voice = context.read<VoiceController>();
    _player = context.read<PlayerController>();
    _caption = context.read<CaptionController>();

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
    _stage = _CaptionStage.waitingSource;
    if (mounted) setState(() {});
    await _promptAndListen(
      'Bạn muốn chụp ảnh để mô tả hay chọn ảnh từ thư viện?',
      _handleSourceUtterance,
      settleMs: 1450,
    );
  }

  Future<void> _askGalleryChoice() async {
    _stage = _CaptionStage.waitingGalleryChoice;
    if (mounted) setState(() {});
    await _promptAndListen(
      'Bạn muốn dùng ảnh mới nhất hay ảnh thứ 2?',
      _handleGalleryChoiceUtterance,
      settleMs: 1400,
    );
  }

  Future<void> _askNextAction() async {
    _stage = _CaptionStage.waitingNextAction;
    if (mounted) setState(() {});
    await _promptAndListen(
      'Bạn muốn sử dụng thêm tính năng gì khác? Bạn có thể nói: mô tả lại, quét chữ, đọc báo, lịch sử, tác vụ, cài đặt, trang chủ hoặc thoát.',
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
    await _speakWithPlayer(prompt, title: 'Mô tả ảnh');
    await Future.delayed(Duration(milliseconds: settleMs));

    if (!mounted || epoch != _listenEpoch) return;

    await _voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;

        final n = _norm(text);
        if (n.isEmpty || _isEchoFromTts(n)) {
          await Future.delayed(const Duration(milliseconds: 350));
          if (!mounted || epoch != _listenEpoch) return;

          if (_stage == _CaptionStage.waitingSource) {
            await _askSource();
          } else if (_stage == _CaptionStage.waitingGalleryChoice) {
            await _askGalleryChoice();
          } else if (_stage == _CaptionStage.waitingNextAction) {
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
      'ban muon chup anh de mo ta hay chon anh tu thu vien',
      'ban muon dung anh moi nhat hay anh thu 2',
      'ban muon su dung them tinh nang gi khac ban co the noi mo ta lai quet chu doc bao lich su tac vu cai dat trang chu hoac thoat',
    ];

    for (final p in fullPrompts) {
      if (n == p) return true;
    }

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
      title: 'Mô tả ảnh',
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
      await _pickRecentCameraLikeImage(0);
      return;
    }

    if (n.contains('thu 2') ||
        n.contains('thu hai') ||
        n.contains('anh 2') ||
        n.contains('so 2') ||
        n == 'hai') {
      await _pickRecentCameraLikeImage(1);
      return;
    }

    await _speakWithPlayer(
      'Mình chưa hiểu. Bạn có thể nói ảnh mới nhất hoặc ảnh thứ 2.',
      title: 'Mô tả ảnh',
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

    if (n.contains('mo ta lai') || n.contains('quay lai') || n == 'caption') {
      await _askSource();
      return;
    }

    if (n.contains('quet chu') || n.contains('ocr') || n.contains('doc chu')) {
      await _popToRoot();
      if (widget.onOpenOcr != null) {
        await widget.onOpenOcr!();
      }
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
      'Mình chưa hiểu. Bạn có thể nói mô tả lại, quét chữ, đọc báo, lịch sử, tác vụ, cài đặt, trang chủ hoặc thoát.',
      title: 'Mô tả ảnh',
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
        builder: (_) => const CaptionCameraScreen(),
      ),
    );

    if (!mounted || path == null || path.trim().isEmpty) {
      await Future.delayed(const Duration(milliseconds: 250));
      await _askSource();
      return;
    }

    await _runCaption(path);
  }

  Future<bool> _ensureGalleryPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      await _speakWithPlayer(
        'Bạn chưa cấp quyền thư viện ảnh. Hãy bật quyền ảnh trong cài đặt ứng dụng.',
        title: 'Mô tả ảnh',
      );
      return false;
    }
    return true;
  }

  Future<void> _pickFromGalleryManual() async {
    _stage = _CaptionStage.processing;
    if (mounted) setState(() {});

    await _voice.stop();
    await _tts.stop();

    try {
      final ok = await _ensureGalleryPermission();
      if (!ok) {
        await Future.delayed(const Duration(milliseconds: 350));
        await _askSource();
        return;
      }

      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (file == null || file.path.trim().isEmpty) {
        await Future.delayed(const Duration(milliseconds: 250));
        await _askSource();
        return;
      }

      await _runCaption(file.path);
    } catch (_) {
      await _speakWithPlayer(
        'Có lỗi khi chọn ảnh từ thư viện.',
        title: 'Mô tả ảnh',
      );
      await Future.delayed(const Duration(milliseconds: 350));
      await _askSource();
    }
  }

  int _albumPriority(String name) {
    final n = _norm(name);

    if (n.contains('camera') ||
        n.contains('dcim') ||
        n.contains('camera roll') ||
        n.contains('100media')) {
      return 300;
    }

    if (n.contains('screenshots') ||
        n.contains('screenshot') ||
        n.contains('screen shots') ||
        n.contains('screen_shots') ||
        n.contains('screen shot') ||
        n.contains('anh chup man hinh')) {
      return -300;
    }

    if (n.contains('download') ||
        n.contains('zalo') ||
        n.contains('whatsapp') ||
        n.contains('facebook') ||
        n.contains('messenger') ||
        n.contains('telegram')) {
      return -80;
    }

    return 0;
  }

  int _createdAt(AssetEntity a) => a.createDateSecond ?? 0;

  int _modifiedAt(AssetEntity a) => a.modifiedDateSecond ?? 0;

  bool _isNewerAsset(AssetEntity a, AssetEntity b) {
    final c = _createdAt(a).compareTo(_createdAt(b));
    if (c != 0) return c > 0;
    return _modifiedAt(a) > _modifiedAt(b);
  }

  Future<void> _pickRecentCameraLikeImage(int index) async {
    _stage = _CaptionStage.processing;
    if (mounted) setState(() {});

    await _voice.stop();
    await _tts.stop();

    try {
      final ok = await _ensureGalleryPermission();
      if (!ok) {
        await Future.delayed(const Duration(milliseconds: 350));
        await _askSource();
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );

      if (albums.isEmpty) {
        await _speakWithPlayer(
          'Mình chưa thấy ảnh nào trong thư viện.',
          title: 'Mô tả ảnh',
        );
        await Future.delayed(const Duration(milliseconds: 350));
        await _askSource();
        return;
      }

      final Map<String, _RankedAsset> rankedById = {};

      for (final album in albums) {
        final assets = await album.getAssetListPaged(page: 0, size: 50);
        final priority = _albumPriority(album.name);

        for (final asset in assets) {
          final current = _RankedAsset(asset: asset, priority: priority);
          final existed = rankedById[asset.id];

          if (existed == null) {
            rankedById[asset.id] = current;
            continue;
          }

          if (current.priority > existed.priority) {
            rankedById[asset.id] = current;
            continue;
          }

          if (current.priority == existed.priority &&
              _isNewerAsset(current.asset, existed.asset)) {
            rankedById[asset.id] = current;
          }
        }
      }

      final all = rankedById.values.toList()
        ..sort((a, b) {
          final p = b.priority.compareTo(a.priority);
          if (p != 0) return p;

          final c = _createdAt(b.asset).compareTo(_createdAt(a.asset));
          if (c != 0) return c;

          return _modifiedAt(b.asset).compareTo(_modifiedAt(a.asset));
        });

      final cameraLike = all.where((e) => e.priority >= 300).toList();

      if (cameraLike.length <= index) {
        await _speakWithPlayer(
          index == 0
              ? 'Mình chưa thấy ảnh chụp từ camera đủ mới.'
              : 'Mình chưa thấy đủ ảnh chụp từ camera để lấy ảnh thứ 2.',
          title: 'Mô tả ảnh',
        );
        await Future.delayed(const Duration(milliseconds: 350));
        await _askGalleryChoice();
        return;
      }

      final file = await cameraLike[index].asset.file;
      if (file == null || !file.existsSync()) {
        await _speakWithPlayer(
          'Mình chưa mở được ảnh chụp từ camera.',
          title: 'Mô tả ảnh',
        );
        await Future.delayed(const Duration(milliseconds: 350));
        await _askGalleryChoice();
        return;
      }

      await _runCaption(file.path);
    } catch (_) {
      await _speakWithPlayer(
        'Có lỗi khi lấy ảnh từ thư viện.',
        title: 'Mô tả ảnh',
      );
      await Future.delayed(const Duration(milliseconds: 350));
      await _askGalleryChoice();
    }
  }

  Future<void> _runCaption(String path) async {
    _stage = _CaptionStage.processing;
    if (mounted) setState(() {});

    try {
      _latestImagePath = path;

      await _speakWithPlayer(
        'Đang mô tả ảnh, bạn chờ một chút nhé.',
        title: 'Mô tả ảnh',
      );

      await _caption.runCaption(path, speakResult: false);

      final result = _caption.caption.trim().isEmpty
          ? 'Mình chưa mô tả được nội dung ảnh rõ ràng.'
          : _caption.caption.trim();

      await _reloadHistoryIfNeeded(_caption.historyId);
      await _speakWithPlayer(result, title: 'Kết quả mô tả');
      await _askNextAction();
    } catch (_) {
      await _speakWithPlayer(
        'Có lỗi khi mô tả ảnh. Bạn thử lại nhé.',
        title: 'Mô tả ảnh',
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
        type: 'caption',
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

    final preview = value.length > 88 ? '${value.substring(0, 88)}...' : value;
    _player.setNow(title, preview, newDetails: value);

    await _tts.stop();
    await _tts.speak(value);
  }

  Future<void> _toggleMic() async {
    if (_voice.isListening) {
      await _voice.stop();
      return;
    }

    if (_stage == _CaptionStage.waitingSource) {
      await _askSource();
      return;
    }

    if (_stage == _CaptionStage.waitingGalleryChoice) {
      await _askGalleryChoice();
      return;
    }

    if (_stage == _CaptionStage.waitingNextAction) {
      await _askNextAction();
      return;
    }

    await _askSource();
  }

  Future<void> _onHoldToListen() async {
    if (_voice.isListening) return;
    await _toggleMic();
  }

  Future<void> _onPlayPause() async {
    if (_tts.isSpeaking.value) {
      await _tts.stop();
      _player.setPlaying(false);
      return;
    }

    if (_lastSpokenText.trim().isEmpty) {
      await _speakWithPlayer(
        'Bạn chưa có nội dung để phát lại.',
        title: 'Mô tả ảnh',
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
      case _CaptionStage.waitingSource:
        return 'Gợi ý: nói “chụp ảnh” hoặc “chọn ảnh từ thư viện”. Hoặc giữ màn hình 2 giây để bật mic.';
      case _CaptionStage.waitingGalleryChoice:
        return 'Gợi ý: nói “ảnh mới nhất” hoặc “ảnh thứ 2”. Hoặc giữ màn hình 2 giây để bật mic.';
      case _CaptionStage.waitingNextAction:
        return 'Gợi ý: nói “mô tả lại”, “quét chữ”, “đọc báo”, “lịch sử”, “tác vụ”, “cài đặt”, “trang chủ” hoặc “thoát”. Hoặc giữ màn hình 2 giây để bật mic.';
      case _CaptionStage.processing:
        return 'Đang xử lý mô tả ảnh...';
      case _CaptionStage.idle:
        return 'Sẵn sàng.';
    }
  }

  Future<void> _openImagePreviewDialog() async {
    if (_latestImagePath.trim().isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.72,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(_latestImagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const _VisionImageErrorBox(
                      message: 'Không mở được ảnh vừa chọn.',
                      compact: false,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBanner(VoiceController voice) {
    final text = voice.isListening
        ? (voice.lastWords.trim().isEmpty
        ? 'Đang nghe lệnh...'
        : 'Đang nghe: ${voice.lastWords}')
        : _hintText();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardStroke.withValues(alpha: 0.78),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandBrown.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              voice.isListening
                  ? Icons.mic_rounded
                  : Icons.tips_and_updates_outlined,
              color: AppColors.brandBrown,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewCard() {
    final hasImage = _latestImagePath.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cardStroke.withValues(alpha: 0.80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ảnh vừa mô tả',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasImage)
                  TextButton.icon(
                    onPressed: _openImagePreviewDialog,
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                    label: const Text('Xem lớn'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.brandBrown.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: hasImage
                      ? GestureDetector(
                    onTap: _openImagePreviewDialog,
                    child: Image.file(
                      File(_latestImagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                      const _VisionImageErrorBox(
                        message: 'Không mở được ảnh vừa chọn.',
                      ),
                    ),
                  )
                      : const _VisionPlaceholderBox(
                    icon: Icons.image_outlined,
                    title: 'Chưa có ảnh',
                    subtitle:
                    'Ảnh bạn chụp hoặc chọn sẽ hiện lớn tại đây.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(CaptionController c) {
    final result = c.caption.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cardStroke.withValues(alpha: 0.82),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kết quả mô tả',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: result.isEmpty
                      ? null
                      : () => _speakWithPlayer(
                    result,
                    title: 'Kết quả mô tả',
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Hiển thị trọn vẹn phần mô tả để bạn dễ theo dõi và nghe lại bằng giọng nói.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.cardStroke.withValues(alpha: 0.72),
                ),
              ),
              child: SelectableText(
                result.isEmpty ? '(Trống)' : result,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.65,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaptionController>();
    final voice = context.watch<VoiceController>();

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _onHoldToListen,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mô tả ảnh'),
          actions: [
            IconButton(
              onPressed: _toggleMic,
              icon: Icon(
                voice.isListening
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
              children: [
                _buildVoiceBanner(voice),
                const SizedBox(height: 16),
                _buildImagePreviewCard(),
                const SizedBox(height: 16),
                _buildResultCard(c),
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
                        text: 'Chụp ảnh để mô tả',
                        filled: true,
                        onTap: c.loading ? null : _openCameraCaptureFlow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.photo_library_rounded,
                        text: 'Chọn ảnh từ thư viện',
                        filled: false,
                        onTap: c.loading ? null : _pickFromGalleryManual,
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
      ),
    );
  }
}

class _VisionPlaceholderBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _VisionPlaceholderBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandBrown.withValues(alpha: 0.06),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.brandBrown),
          const SizedBox(height: 12),
          const Text(
            'Chưa có ảnh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisionImageErrorBox extends StatelessWidget {
  final String message;
  final bool compact;

  const _VisionImageErrorBox({
    required this.message,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandBrown.withValues(alpha: 0.06),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: compact ? 36 : 48,
            color: AppColors.brandBrown,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
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

class _RankedAsset {
  final AssetEntity asset;
  final int priority;

  const _RankedAsset({
    required this.asset,
    required this.priority,
  });
}