import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../../data/models/history_models.dart';
import '../voice/voice_controller.dart';

class HistoryDetailScreen extends StatefulWidget {
  final HistoryItem item;

  const HistoryDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool _speaking = false;
  bool _listening = false;
  int _listenEpoch = 0;

  String get _title {
    switch (widget.item.actionType) {
      case 'ocr':
        return 'Kết quả OCR đã lưu';
      case 'caption':
        return 'Mô tả ảnh đã lưu';
      case 'read_url':
        return 'Bài báo đã lưu';
      default:
        return 'Chi tiết lịch sử';
    }
  }

  String get _typeLabel {
    switch (widget.item.actionType) {
      case 'ocr':
        return 'Quét chữ';
      case 'caption':
        return 'Mô tả ảnh';
      case 'read_url':
        return 'Đọc báo';
      default:
        return 'Lịch sử';
    }
  }

  bool get _isImageBased =>
      widget.item.actionType == 'ocr' || widget.item.actionType == 'caption';

  bool get _isReadUrl => widget.item.actionType == 'read_url';

  String get _resultTitle {
    switch (widget.item.actionType) {
      case 'ocr':
        return 'Văn bản đã lưu';
      case 'caption':
        return 'Nội dung mô tả đã lưu';
      case 'read_url':
        return 'Nội dung đã lưu';
      default:
        return 'Nội dung đã lưu';
    }
  }

  String get _resultText {
    final value = widget.item.resultText.trim();
    if (value.isEmpty) return 'Không có nội dung.';
    return value;
  }

  String get _inputText {
    final value = widget.item.inputData.trim();
    if (value.isEmpty) return '';
    return value;
  }

  String? get _normalizedUploadPath {
    var value = widget.item.inputData.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll('\\', '/');

    final lower = value.toLowerCase();
    final uploadIndex = lower.indexOf('uploads/');
    if (uploadIndex >= 0) {
      value = value.substring(uploadIndex);
    }

    while (value.startsWith('/')) {
      value = value.substring(1);
    }

    if (!value.toLowerCase().startsWith('uploads/')) {
      return null;
    }

    return value;
  }

  String? get _imageUrl {
    if (!_isImageBased) return null;
    final path = _normalizedUploadPath;
    if (path == null || path.isEmpty) return null;
    return '${ApiConstants.baseUrl}/${Uri.encodeFull(path)}';
  }

  Future<void> _speakText(
      String text, {
        String title = 'Lịch sử',
      }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final tts = context.read<TtsService>();

    if (mounted) {
      setState(() {
        _speaking = true;
      });
    }

    try {
      await context.read<VoiceController>().stop();
      await tts.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await tts.speak(value);
    } finally {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  Future<void> _speakResult() async {
    await _speakText(
      _resultText,
      title: _title,
    );
  }

  Future<void> _stopSpeaking() async {
    await context.read<VoiceController>().stop();
    await context.read<TtsService>().stop();

    if (mounted) {
      setState(() {
        _speaking = false;
      });
    }
  }

  Future<void> _openImagePreview() async {
    final imageUrl = _imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
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
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _ImageErrorBox(
                        compact: false,
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
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
        );
      },
    );
  }

  Future<void> _startListeningImmediate() async {
    final voice = context.read<VoiceController>();
    final epoch = ++_listenEpoch;

    await _stopSpeaking();

    if (mounted) {
      setState(() {
        _listening = true;
      });
    }

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;

        final raw = text.trim();
        if (raw.isEmpty) {
          if (mounted) {
            setState(() {
              _listening = false;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _listening = false;
          });
        }

        await _handleVoiceCommand(raw);
      },
    );
  }

  Future<void> _handleVoiceCommand(String raw) async {
    final n = _norm(raw);

    if (_isBackCommand(n) || n.contains('lich su')) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    if (n.contains('trang chu') || n == 'home') {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (_isStopCommand(n)) {
      await _stopSpeaking();
      return;
    }

    if (_isReplayCommand(n)) {
      await _speakResult();
      return;
    }

    if (_isImageBased && (n.contains('xem anh') || n.contains('xem lon'))) {
      await _openImagePreview();
      return;
    }

    await _speakText(
      'Mình chưa hiểu. Bạn có thể nói đọc lại, tạm dừng, quay lại hoặc trang chủ.',
      title: 'Lịch sử',
    );
  }

  bool _isReplayCommand(String n) {
    return n.contains('doc lai') ||
        n.contains('nghe lai') ||
        n.contains('lap lai');
  }

  bool _isStopCommand(String n) {
    return n.contains('tam dung') ||
        n.contains('dung doc') ||
        n == 'dung';
  }

  bool _isBackCommand(String n) {
    return n.contains('quay lai') ||
        n.contains('tro lai') ||
        n == 'back';
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

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ocr':
        return Icons.text_snippet_outlined;
      case 'caption':
        return Icons.image_search_rounded;
      case 'read_url':
        return Icons.article_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 1.25,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaPill(
                  icon: _typeIcon(widget.item.actionType),
                  label: _typeLabel,
                ),
                if (widget.item.createdAt.trim().isNotEmpty)
                  _MetaPill(
                    icon: Icons.schedule_rounded,
                    label: widget.item.createdAt,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceHintCard(VoiceController voice) {
    final text = _listening || voice.isListening
        ? (voice.lastWords.trim().isEmpty
        ? 'Đang nghe lệnh...'
        : 'Đang nghe: ${voice.lastWords}')
        : 'Giữ 2 giây ở bất kỳ đâu để bật mic. Bạn có thể nói: đọc lại, tạm dừng, quay lại hoặc trang chủ.';

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
              color: AppColors.bgBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              (_listening || voice.isListening)
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

  Widget _buildImageCard() {
    final imageUrl = _imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  color: AppColors.brandBrown.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Hình ảnh đã lưu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openImagePreview,
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  label: const Text('Xem lớn'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openImagePreview,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E9DA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.cardStroke.withValues(alpha: 0.80),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _ImageErrorBox(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Chạm vào ảnh để xem đầy đủ rõ hơn.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    if (_inputText.isEmpty) return const SizedBox.shrink();
    if (_isImageBased && _imageUrl != null) return const SizedBox.shrink();

    final title = _isReadUrl ? 'Liên kết đã lưu' : 'Đầu vào đã lưu';
    final icon = _isReadUrl ? Icons.link_rounded : Icons.description_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.brandBrown.withValues(alpha: 0.92)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              _inputText,
              style: const TextStyle(
                fontSize: 15,
                height: 1.65,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _typeIcon(widget.item.actionType),
                  color: AppColors.brandBrown.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resultTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              _resultText,
              style: const TextStyle(
                fontSize: 16,
                height: 1.72,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _listenEpoch++;
    context.read<VoiceController>().stop();
    context.read<TtsService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    final showInputCard =
        _inputText.isNotEmpty && !(_isImageBased && hasImage);

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _startListeningImmediate,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => _speakText(
          'Giữ 2 giây để bật mic. Bạn có thể nói đọc lại, tạm dừng, quay lại hoặc trang chủ.',
          title: 'Lịch sử',
        ),
        child: Scaffold(
          appBar: AppBar(
            title: Text(_typeLabel),
            actions: [
              IconButton(
                onPressed: _startListeningImmediate,
                icon: Icon(
                  (_listening || voice.isListening)
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 12),
              _buildVoiceHintCard(voice),
              if (hasImage) ...[
                const SizedBox(height: 12),
                _buildImageCard(),
              ],
              if (showInputCard) ...[
                const SizedBox(height: 12),
                _buildInputCard(),
              ],
              const SizedBox(height: 12),
              _buildResultCard(),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _speaking ? _stopSpeaking : _speakResult,
                icon: Icon(
                  _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                ),
                label: Text(_speaking ? 'Dừng đọc' : 'Đọc lại'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.bgBeige,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brandBrown),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.brandBrown,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageErrorBox extends StatelessWidget {
  final bool compact;

  const _ImageErrorBox({
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2E9DA),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: compact ? 34 : 48,
            color: AppColors.brandBrown,
          ),
          const SizedBox(height: 10),
          const Text(
            'Không tải được ảnh đã lưu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}