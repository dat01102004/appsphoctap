import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../player/player_controller.dart';
import '../player/player_sliding_panel.dart';
import 'news_article_payload.dart';

enum NewsArticleExitAction {
  askNextAction,
}

class NewsArticleScreen extends StatefulWidget {
  final NewsArticlePayload article;

  const NewsArticleScreen({
    super.key,
    required this.article,
  });

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  static const double _playerBottomOffset = 8;

  TtsService? _tts;
  PlayerController? _player;

  bool _autoPlayed = false;
  bool _listenerAttached = false;
  bool _wasSpeaking = false;
  bool _returnOnCompletion = false;

  String get _safeTitle {
    final t = widget.article.title.trim();
    if (t.isEmpty) return 'Bài báo';
    return t;
  }

  String get _safeSummary {
    final s = widget.article.summary.trim();
    if (s.isEmpty) return 'Chưa có tóm tắt nội dung.';
    return s;
  }

  @override
  void initState() {
    super.initState();

    _tts = context.read<TtsService>();
    _player = context.read<PlayerController>();

    _tts!.isSpeaking.addListener(_syncSpeakingState);
    _listenerAttached = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _player!.setRepeat(false);
      _primePlayer();

      if (!_autoPlayed) {
        _autoPlayed = true;
        await _play();
      }
    });
  }

  @override
  void dispose() {
    _returnOnCompletion = false;
    _wasSpeaking = false;

    if (_listenerAttached && _tts != null) {
      _tts!.isSpeaking.removeListener(_syncSpeakingState);
    }

    _tts?.stop();
    _player?.setPlaying(false);
    super.dispose();
  }

  void _primePlayer() {
    final preview = _safeSummary.length > 84
        ? '${_safeSummary.substring(0, 84)}...'
        : _safeSummary;

    _player?.setNow(_safeTitle, preview, newDetails: _safeSummary);
  }

  void _syncSpeakingState() {
    if (!mounted || _tts == null) return;

    final speaking = _tts!.isSpeaking.value;
    _player?.setPlaying(speaking);

    if (speaking) {
      _wasSpeaking = true;
      return;
    }

    if (_wasSpeaking && _returnOnCompletion) {
      _wasSpeaking = false;
      _returnOnCompletion = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context, 'askNextAction');
      });
    }
  }

  Future<void> _play() async {
    if (_tts == null) return;

    _primePlayer();
    _returnOnCompletion = true;
    _wasSpeaking = false;

    await _tts!.stop();
    await Future.delayed(const Duration(milliseconds: 120));
    await _tts!.speak(_safeSummary);
  }

  Future<void> _stop() async {
    if (_tts == null) return;

    _returnOnCompletion = false;
    _wasSpeaking = false;
    await _tts!.stop();
    _player?.setPlaying(false);
  }

  Future<void> _togglePlayPause() async {
    if (_tts == null) return;

    if (_tts!.isSpeaking.value) {
      await _stop();
      return;
    }

    await _play();
  }

  Future<void> _onMicPressed() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đọc xong bài, app sẽ hỏi bạn muốn làm gì tiếp theo.'),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    await _stop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sourceLine = [
      if ((widget.article.source ?? '').trim().isNotEmpty) widget.article.source!,
      if ((widget.article.published ?? '').trim().isNotEmpty)
        widget.article.published!,
    ].join(' • ');

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bài báo'),
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _safeTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                        if (sourceLine.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            sourceLine,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tóm tắt nội dung',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<TtsProgress?>(
                          valueListenable: context.read<TtsService>().progress,
                          builder: (_, progress, __) {
                            return _HighlightedText(
                              text: _safeSummary,
                              progress: progress,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBrown,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _play,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Đọc lại tóm tắt'),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              bottom: _playerBottomOffset,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PlayerSlidingPanel(
                  onPlayPause: _togglePlayPause,
                  onStop: _stop,
                  onMic: _onMicPressed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final TtsProgress? progress;

  const _HighlightedText({
    required this.text,
    required this.progress,
  });

  int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;

    if (p == null || p.text.trim() != text.trim()) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: Colors.black87,
        ),
      );
    }

    final start = _clamp(p.start, 0, text.length);
    final end = _clamp(p.end, start, text.length);

    final before = text.substring(0, start);
    final current = text.substring(start, end);
    final after = text.substring(end);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: before,
            style: const TextStyle(
              fontSize: 16,
              height: 1.7,
              color: Colors.black87,
            ),
          ),
          TextSpan(
            text: current,
            style: const TextStyle(
              fontSize: 16,
              height: 1.7,
              color: Colors.black,
              backgroundColor: Color(0xFFFFE08A),
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: after,
            style: const TextStyle(
              fontSize: 16,
              height: 1.7,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
