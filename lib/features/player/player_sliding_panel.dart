import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../voice/voice_controller.dart';
import 'player_controller.dart';
import 'player_settings_sheet.dart';

class PlayerSlidingPanel extends StatefulWidget {
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onStop;
  final Future<void> Function() onMic;

  const PlayerSlidingPanel({
    super.key,
    required this.onPlayPause,
    required this.onStop,
    required this.onMic,
  });

  @override
  State<PlayerSlidingPanel> createState() => _PlayerSlidingPanelState();
}

class _PlayerSlidingPanelState extends State<PlayerSlidingPanel> {
  final DraggableScrollableController _controller =
  DraggableScrollableController();

  double _extent = 0.115;

  bool get _expanded => _extent > 0.20;

  void _toggleExpand() {
    final target = _expanded ? 0.115 : 0.42;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final voice = context.watch<VoiceController>();

    final collapsedText = voice.isListening
        ? (voice.lastWords.trim().isEmpty
        ? 'Đang nghe...'
        : 'Đang nghe: ${voice.lastWords}')
        : player.subtitle;

    final fullText = voice.isListening
        ? (voice.lastWords.trim().isEmpty ? 'Đang nghe...' : voice.lastWords)
        : (player.details.trim().isEmpty ? player.subtitle : player.details);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        setState(() => _extent = notification.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: 0.115,
        minChildSize: 0.115,
        maxChildSize: 0.42,
        snap: true,
        snapSizes: const [0.115, 0.42],
        builder: (context, scrollController) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.brandBrown,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Colors.black26,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    collapsedText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _circleIconButton(
                              tooltip: 'Dừng',
                              icon: Icons.stop_rounded,
                              onPressed: () async => widget.onStop(),
                            ),
                            _circleIconButton(
                              tooltip:
                              player.isPlaying ? 'Tạm dừng' : 'Phát lại',
                              icon: player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onPressed: () async => widget.onPlayPause(),
                            ),
                            _circleIconButton(
                              tooltip:
                              voice.isListening ? 'Dừng mic' : 'Bật mic',
                              icon: voice.isListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              onPressed: () async => widget.onMic(),
                            ),
                            _circleIconButton(
                              tooltip:
                              player.repeat ? 'Tắt lặp' : 'Lặp lại',
                              icon: player.repeat
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              onPressed: () {
                                context.read<PlayerController>().toggleRepeat();
                              },
                            ),
                            _circleIconButton(
                              tooltip: 'Cài đặt giọng đọc',
                              icon: Icons.settings_rounded,
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (_) => const PlayerSettingsSheet(),
                                );
                              },
                            ),
                            _circleIconButton(
                              tooltip: _expanded ? 'Thu nhỏ' : 'Mở rộng',
                              icon: _expanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              onPressed: _toggleExpand,
                            ),
                          ],
                        ),
                        if (_expanded) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 170),
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  fullText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _circleIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}