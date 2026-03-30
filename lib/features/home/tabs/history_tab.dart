import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/tts/tts_service.dart';
import '../../../core/widgets/hold_to_listen_layer.dart';
import '../../../data/models/history_models.dart';
import '../../auth/auth_controller.dart';
import '../../auth/login_screen.dart';
import '../../auth/register_screen.dart';
import '../../history/history_controller.dart';
import '../../history/history_detail_screen.dart';
import '../../voice/voice_controller.dart';

class HistoryTab extends StatefulWidget {
  final bool isActive;

  const HistoryTab({
    super.key,
    required this.isActive,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _type; // null, ocr, caption, read_url
  bool _requestedInitialLoad = false;
  int _listenEpoch = 0;
  String _lastPromptNorm = '';
  String _lastAnnounceMode = '';

  @override
  void didUpdateWidget(covariant HistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive && !widget.isActive) {
      _listenEpoch++;
      context.read<VoiceController>().stop();
      context.read<TtsService>().stop();
    }

    if (!oldWidget.isActive && widget.isActive) {
      _lastAnnounceMode = '';
    }
  }

  @override
  void dispose() {
    _listenEpoch++;
    context.read<VoiceController>().stop();
    context.read<TtsService>().stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (!widget.isActive) return;

    _lastPromptNorm = _norm(text);

    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();

    await voice.stop();
    await tts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await tts.speak(text);
  }

  Future<void> _announceGuest() async {
    await _speak(
      'Đây là màn hình lịch sử. '
          'Bạn đang ở chế độ khách nên chưa thể xem lịch sử đã lưu. '
          'Bạn có thể nói đăng nhập hoặc đăng ký.',
    );
  }

  Future<void> _announceLoggedIn() async {
    await _speak(
      'Màn hình lịch sử. '
          'Bạn có thể nói tất cả, quét chữ, mô tả ảnh, đọc báo, tải lại, '
          'mở mục 1, đọc mục 1 hoặc xóa mục 1. '
          'Bạn cũng có thể giữ màn hình 2 giây để bật mic.',
    );
  }

  Future<void> _startVoice() async {
    if (!widget.isActive) return;

    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();
    final epoch = ++_listenEpoch;

    await tts.stop();
    await voice.stop();
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted || epoch != _listenEpoch || !widget.isActive) return;

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch || !widget.isActive) return;

        final normalized = _norm(text);
        if (normalized.isEmpty || _isPromptEcho(normalized)) return;

        await _handleVoice(text);
      },
    );
  }

  bool _isPromptEcho(String normalized) {
    if (_lastPromptNorm.isEmpty || normalized.isEmpty) return false;
    if (normalized == _lastPromptNorm) return true;
    if (normalized.length >= 24 && _lastPromptNorm.contains(normalized)) {
      return true;
    }
    return false;
  }

  Future<void> _handleVoice(String raw) async {
    if (!widget.isActive) return;

    final n = _norm(raw);
    final loggedIn = context.read<AuthController>().loggedIn;
    final controller = context.read<HistoryController>();

    if (!loggedIn) {
      if (n.contains('dang nhap')) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      if (n.contains('dang ky') || n.contains('tao tai khoan')) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
        return;
      }

      await _announceGuest();
      return;
    }

    if (n.contains('nhac lai') ||
        n.contains('doc lai huong dan') ||
        n.contains('huong dan')) {
      await _announceLoggedIn();
      return;
    }

    if (n.contains('tai lai') ||
        n.contains('lam moi') ||
        n.contains('refresh')) {
      await controller.load(type: _type);
      await _speak('Đã tải lại lịch sử.');
      return;
    }

    if (n == 'tat ca' || n.contains('loc tat ca')) {
      await _changeFilter(null);
      return;
    }

    if (n.contains('quet chu') || n == 'ocr') {
      await _changeFilter('ocr');
      return;
    }

    if (n.contains('mo ta anh') || n.contains('caption')) {
      await _changeFilter('caption');
      return;
    }

    if (n.contains('doc bao') || n.contains('bao') || n.contains('read url')) {
      await _changeFilter('read_url');
      return;
    }

    final index = _extractIndex(n);
    if (index != null) {
      final items = controller.items;
      if (index < 1 || index > items.length) {
        await _speak('Không thấy mục số $index trong danh sách hiện tại.');
        return;
      }

      final item = items[index - 1] as HistoryItem;

      if (n.contains('xoa muc') || n.contains('xoa so') || n.startsWith('xoa ')) {
        await controller.remove(item.id);
        return;
      }

      if (n.contains('doc muc') || n.contains('nghe muc')) {
        await controller.speakItem(item.resultText);
        return;
      }

      if (n.contains('mo muc') || n.contains('xem muc') || n.startsWith('mo ')) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoryDetailScreen(item: item),
          ),
        );
        return;
      }
    }

    await _announceLoggedIn();
  }

  int? _extractIndex(String normalized) {
    final digit = RegExp(r'\b(\d+)\b').firstMatch(normalized);
    if (digit != null) {
      return int.tryParse(digit.group(1)!);
    }

    const map = {
      'mot': 1,
      'muc mot': 1,
      'so mot': 1,
      'hai': 2,
      'muc hai': 2,
      'so hai': 2,
      'ba': 3,
      'muc ba': 3,
      'bon': 4,
      'tu': 4,
      'nam': 5,
      'sau': 6,
      'bay': 7,
      'tam': 8,
      'chin': 9,
      'muoi': 10,
    };

    for (final entry in map.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _norm(String input) {
    var s = input.toLowerCase().trim();

    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
        'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';

    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIII'
        'OOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }

    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Future<void> _changeFilter(String? typeValue) async {
    setState(() => _type = typeValue);
    await context.read<HistoryController>().load(type: _type);
    await _speak('Đã lọc ${_labelOf(typeValue).toLowerCase()}.');
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _maybeLoadInitial(bool loggedIn) {
    if (!widget.isActive) return;

    if (loggedIn && !_requestedInitialLoad) {
      _requestedInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        context.read<HistoryController>().load(type: _type);
      });
    }

    if (!loggedIn && _requestedInitialLoad) {
      _requestedInitialLoad = false;
    }
  }

  void _maybeAnnounce(bool loggedIn) {
    if (!widget.isActive) return;

    final mode = loggedIn ? 'logged_in' : 'guest';
    if (_lastAnnounceMode == mode) return;

    _lastAnnounceMode = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.isActive) return;
      if (loggedIn) {
        await _announceLoggedIn();
      } else {
        await _announceGuest();
      }
    });
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

  String? _normalizeUploadPath(String raw) {
    var value = raw.trim();
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

  String? _imageUrlOf(HistoryItem item) {
    final isImageBased =
        item.actionType == 'ocr' || item.actionType == 'caption';
    if (!isImageBased) return null;

    final path = _normalizeUploadPath(item.inputData);
    if (path == null || path.isEmpty) return null;

    return '${ApiConstants.baseUrl}/${Uri.encodeFull(path)}';
  }

  Widget _historyThumb(HistoryItem item) {
    final imageUrl = _imageUrlOf(item);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          imageUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _historyThumbFallback(item),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          },
        ),
      );
    }

    return _historyThumbFallback(item);
  }

  Widget _historyThumbFallback(HistoryItem item) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.bgBeige,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardStroke.withValues(alpha: 0.75),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        _typeIcon(item.actionType),
        size: 32,
        color: AppColors.brandBrown,
      ),
    );
  }

  Widget _voiceCard() {
    final voice = context.watch<VoiceController>();

    final subtitle = voice.isListening
        ? (voice.lastWords.trim().isEmpty
        ? 'Đang nghe...'
        : voice.lastWords.trim())
        : 'Nhấn mic hoặc giữ màn hình 2 giây để điều khiển lịch sử';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: AppColors.brandBrown,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.isListening
                        ? 'Đang nghe lệnh lịch sử'
                        : 'Điều khiển bằng giọng nói',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: voice.isListening ? 'Dừng nghe' : 'Bắt đầu nghe',
              onPressed: !widget.isActive
                  ? null
                  : () async {
                if (voice.isListening) {
                  _listenEpoch++;
                  await voice.stop();
                } else {
                  await _startVoice();
                }
              },
              icon: Icon(
                voice.isListening
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                color: AppColors.brandBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? typeValue) {
    final selected = _type == typeValue;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.cardStroke.withValues(alpha: 0.55),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: AppColors.textDark,
      ),
      onSelected: (_) async {
        setState(() => _type = typeValue);
        await context.read<HistoryController>().load(type: _type);
      },
    );
  }

  String _labelOf(String? type) {
    switch (type) {
      case 'ocr':
        return 'Quét chữ';
      case 'caption':
        return 'Mô tả ảnh';
      case 'read_url':
        return 'Đọc báo';
      default:
        return 'Tất cả';
    }
  }

  Widget _guestView() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () async {
        if (!widget.isActive) return;
        await _announceGuest();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Đăng nhập để lưu lịch sử\n(Guest mode)',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Bạn cần đăng nhập để xem lại kết quả OCR, mô tả ảnh và các bài báo đã đọc.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _voiceCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _openLogin,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(
                        'Đăng nhập',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandBrown,
                        side: const BorderSide(color: AppColors.cardStroke),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _openRegister,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text(
                        'Đăng ký',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyItemCard(HistoryItem item, int index) {
    final preview = item.resultText.trim().replaceAll('\n', ' ');
    final title = preview.isEmpty ? '(Trống)' : preview;
    final typeLabel = _labelOf(item.actionType);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _historyThumb(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 96,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.bgBeige,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.brandBrown,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgBeige,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandBrown,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (item.createdAt.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.createdAt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.read<HistoryController>().speakItem(item.resultText),
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    label: const Text('Đọc'),
                  ),
                  const SizedBox(width: 2),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryDetailScreen(item: item),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Mở'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: () =>
                        context.read<HistoryController>().remove(item.id),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loggedInView(HistoryController c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () async {
        if (!widget.isActive) return;
        await _announceLoggedIn();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch sử hoạt động',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bộ lọc hiện tại: ${_labelOf(_type)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _voiceCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Tất cả', null),
                        const SizedBox(width: 8),
                        _chip('Quét chữ', 'ocr'),
                        const SizedBox(width: 8),
                        _chip('Mô tả ảnh', 'caption'),
                        const SizedBox(width: 8),
                        _chip('Đọc báo', 'read_url'),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Tải lại',
                          onPressed: () =>
                              context.read<HistoryController>().load(type: _type),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (c.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (c.items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  children: const [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 42,
                      color: AppColors.brandBrown,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Chưa có lịch sử phù hợp với bộ lọc hiện tại.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${c.items.length} mục',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              ...List.generate(
                c.items.length,
                    (index) => _historyItemCard(c.items[index] as HistoryItem, index),
              ),
            ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthController, bool>((a) => a.loggedIn);
    final c = context.watch<HistoryController>();

    if (widget.isActive) {
      _maybeLoadInitial(loggedIn);
      _maybeAnnounce(loggedIn);
    }

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: widget.isActive ? _startVoice : () async {},
      child: loggedIn ? _loggedInView(c) : _guestView(),
    );
  }
}