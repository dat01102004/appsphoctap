import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../core/widgets/hold_to_listen_layer.dart';
import '../voice/voice_controller.dart';
import 'read_url_controller.dart';

class ReadUrlScreen extends StatefulWidget {
  const ReadUrlScreen({super.key});

  @override
  State<ReadUrlScreen> createState() => _ReadUrlScreenState();
}

class _ReadUrlScreenState extends State<ReadUrlScreen> {
  final _url = TextEditingController();

  int _listenEpoch = 0;
  String _lastPromptNorm = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _speak(
        'Màn hình đọc đường dẫn. '
            'Bạn có thể dán link bài viết rồi bấm đọc và tóm tắt. '
            'Hoặc giữ màn hình 2 giây để ra lệnh bằng giọng nói.',
      );
    });
  }

  @override
  void dispose() {
    _listenEpoch++;

    unawaited(context.read<TtsService>().stop());
    unawaited(context.read<VoiceController>().stop());

    _url.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    _lastPromptNorm = _norm(value);

    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();

    await voice.stop();
    await tts.stop();
    await tts.speak(value);
  }

  Future<bool> _onWillPop() async {
    await context.read<TtsService>().stop();
    await context.read<VoiceController>().stop();
    return true;
  }

  Future<void> _goBack() async {
    await _onWillPop();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    final controller = context.read<ReadUrlController>();

    if (url.isEmpty) {
      await _speak('Bạn hãy nhập hoặc dán URL bài viết trước nhé.');
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      await _speak('Đường dẫn chưa đúng. URL nên bắt đầu bằng hát tê tê pê hoặc hát tê tê pê ét.');
      return;
    }

    try {
      await controller.submit(url);
    } catch (_) {
      await _speak('Có lỗi khi đọc đường dẫn. Bạn kiểm tra lại URL hoặc thử bài viết khác nhé.');
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';

    if (text.isEmpty) {
      await _speak('Trong bộ nhớ tạm chưa có đường dẫn nào.');
      return;
    }

    setState(() {
      _url.text = text;
    });

    await _speak('Đã dán đường dẫn.');
  }

  Future<void> _clearUrl() async {
    setState(() {
      _url.clear();
    });

    await _speak('Đã xoá đường dẫn.');
  }

  Future<void> _speakResultAgain() async {
    final result = context.read<ReadUrlController>().result;

    if (result == null) {
      await _speak('Chưa có nội dung để đọc lại.');
      return;
    }

    final text = _bestSpeakText();

    if (text.trim().isEmpty) {
      await _speak('Chưa có nội dung để đọc lại.');
      return;
    }

    await _speak(text);
  }

  String _bestSpeakText() {
    final result = context.read<ReadUrlController>().result;

    if (result == null) return '';

    if ((result.summaryTts ?? '').trim().isNotEmpty) {
      return result.summaryTts!.trim();
    }

    if ((result.summary ?? '').trim().isNotEmpty) {
      return result.summary!.trim();
    }

    if ((result.ttsText ?? '').trim().isNotEmpty) {
      return result.ttsText!.trim();
    }

    return result.text.trim();
  }

  Future<void> _startVoice() async {
    final voice = context.read<VoiceController>();
    final tts = context.read<TtsService>();
    final epoch = ++_listenEpoch;

    await tts.stop();
    await voice.stop();
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted || epoch != _listenEpoch) return;

    await voice.start(
      onFinal: (text) async {
        if (!mounted || epoch != _listenEpoch) return;

        final n = _norm(text);

        if (n.isEmpty || _isPromptEcho(n)) return;

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
    final n = _norm(raw);

    if (n.contains('tro ve') ||
        n.contains('quay lai') ||
        n.contains('thoat') ||
        n.contains('ve trang chu')) {
      await _goBack();
      return;
    }

    if (n.contains('dan') ||
        n.contains('dan link') ||
        n.contains('paste') ||
        n.contains('lay tu bo nho')) {
      await _pasteFromClipboard();
      return;
    }

    if (n.contains('xoa') ||
        n.contains('xoa link') ||
        n.contains('xoa duong dan') ||
        n.contains('nhap lai')) {
      await _clearUrl();
      return;
    }

    if (n.contains('doc lai') ||
        n.contains('nghe lai') ||
        n.contains('lap lai')) {
      await _speakResultAgain();
      return;
    }

    if (n.contains('dung doc') ||
        n.contains('tat doc') ||
        n.contains('ngung doc') ||
        n == 'stop') {
      await context.read<TtsService>().stop();
      return;
    }

    if (n.contains('doc') ||
        n.contains('tom tat') ||
        n.contains('bat dau') ||
        n.contains('doc url') ||
        n.contains('doc duong dan')) {
      await _submit();
      return;
    }

    await _speak(
      'Mình chưa hiểu lệnh. '
          'Bạn có thể nói: dán link, đọc và tóm tắt, đọc lại, xoá link hoặc quay lại.',
    );
  }

  String _norm(String input) {
    var s = input.toLowerCase().trim();

    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
        'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
        'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';

    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIII'
        'OOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    for (int i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }

    s = s.replaceAll(RegExp(r'[^a-z0-9\s\.,]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReadUrlController>();
    final voice = context.watch<VoiceController>();
    final hasResult = controller.result != null;
    final resultText = _bestSpeakText();

    return HoldToListenLayer(
      holdDuration: const Duration(seconds: 2),
      onTriggered: _startVoice,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _goBack,
            ),
            title: const Text('Đọc URL'),
            actions: [
              IconButton(
                tooltip: voice.isListening ? 'Dừng nghe' : 'Bật mic',
                onPressed: () async {
                  if (voice.isListening) {
                    _listenEpoch++;
                    await voice.stop();
                  } else {
                    await _startVoice();
                  }
                },
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
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(
                        voiceText: voice.isListening
                            ? (voice.lastWords.trim().isEmpty
                            ? 'Đang nghe lệnh...'
                            : 'Đang nghe: ${voice.lastWords}')
                            : 'Dán link bài viết, rồi bấm đọc và tóm tắt.',
                        onMic: _startVoice,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đường dẫn bài viết',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Bạn có thể dán link báo, bài viết hoặc trang web cần đọc.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _url,
                                minLines: 3,
                                maxLines: 5,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: 'https://...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(bottom: 46),
                                    child: Icon(
                                      Icons.link_rounded,
                                      color: AppColors.brandBrown,
                                    ),
                                  ),
                                  suffixIcon: _url.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                    onPressed: _clearUrl,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: AppColors.cardStroke,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: AppColors.brandBrown,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                          AppColors.brandBrown,
                                          side: const BorderSide(
                                            color: AppColors.cardStroke,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(18),
                                          ),
                                        ),
                                        onPressed: controller.loading
                                            ? null
                                            : _pasteFromClipboard,
                                        icon: const Icon(
                                          Icons.content_paste_rounded,
                                        ),
                                        label: const Text(
                                          'Dán link',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          AppColors.brandBrown,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(18),
                                          ),
                                        ),
                                        onPressed: controller.loading
                                            ? null
                                            : _submit,
                                        icon: const Icon(
                                          Icons.volume_up_rounded,
                                        ),
                                        label: const Text(
                                          'Đọc & Tóm tắt',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _VoiceHintCard(
                        listening: voice.isListening,
                        lastWords: voice.lastWords,
                      ),
                      if (hasResult) ...[
                        const SizedBox(height: 16),
                        _ResultCard(
                          title: 'Kết quả tóm tắt',
                          content: resultText,
                          onSpeak: _speakResultAgain,
                          onStop: () => context.read<TtsService>().stop(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (controller.loading) const _LoadingPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String voiceText;
  final Future<void> Function() onMic;

  const _HeroCard({
    required this.voiceText,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFA67A2D),
            Color(0xFF7B551C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B551C).withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -34,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                  ),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đọc báo bằng URL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dán link, Mắt Nói sẽ đọc giúp bạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      voiceText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandBrown,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: onMic,
                        icon: const Icon(Icons.mic_rounded, size: 19),
                        label: const Text(
                          'Ra lệnh bằng giọng nói',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceHintCard extends StatelessWidget {
  final bool listening;
  final String lastWords;

  const _VoiceHintCard({
    required this.listening,
    required this.lastWords,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                listening
                    ? Icons.mic_rounded
                    : Icons.record_voice_over_rounded,
                color: AppColors.brandBrown,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listening ? 'Đang nghe lệnh' : 'Gợi ý giọng nói',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    listening
                        ? (lastWords.trim().isEmpty
                        ? 'Bạn hãy nói lệnh...'
                        : lastWords.trim())
                        : 'Có thể nói: dán link, đọc và tóm tắt, đọc lại, xoá link, dừng đọc hoặc quay lại.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String content;
  final Future<void> Function() onSpeak;
  final Future<void> Function() onStop;

  const _ResultCard({
    required this.title,
    required this.content,
    required this.onSpeak,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final value = content.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.summarize_rounded,
                  color: AppColors.brandBrown,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgBeige,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardStroke),
              ),
              child: Text(
                value.isEmpty ? 'Không có nội dung.' : value,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed: onSpeak,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text(
                        'Đọc lại',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandBrown,
                      side: const BorderSide(color: AppColors.cardStroke),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onStop,
                    child: const Icon(Icons.stop_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.18),
        child: Center(
          child: Container(
            width: 230,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardStroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppColors.brandBrown,
                ),
                SizedBox(height: 16),
                Text(
                  'Đang đọc bài viết...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Vui lòng chờ một chút',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
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