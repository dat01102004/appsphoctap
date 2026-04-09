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
  final DraggableScrollableController _controller = DraggableScrollableController();

  double _extent = 0.115;
  bool get _expanded => _extent > 0.20;

  void _toggleExpand() {
    final target = _expanded ? 0.115 : 0.48;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final voice = context.watch<VoiceController>();

    final collapsedText = voice.isListening
        ? (voice.lastWords.trim().isEmpty ? 'Đang lắng nghe...' : 'Đang nghe: ${voice.lastWords}')
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
        maxChildSize: 0.48,
        snap: true,
        snapSizes: const [0.115, 0.48],
        builder: (context, scrollController) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.brandBrown,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      // Thanh kéo trang trí sang trọng
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 2, 12, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _toggleExpand,
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player.title.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          collapsedText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _MiniButton(
                                  icon: player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                  onPressed: widget.onPlayPause,
                                  isMain: true,
                                ),
                                _MiniButton(
                                  icon: _expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                  onPressed: _toggleExpand,
                                ),
                              ],
                            ),
                            if (_expanded) ...[
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      fullText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.6,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _ExpandedBtn(icon: Icons.stop_rounded, label: 'Dừng', onTap: widget.onStop),
                                        _ExpandedBtn(
                                          icon: voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                          label: 'Ra lệnh',
                                          onTap: widget.onMic,
                                          active: voice.isListening,
                                        ),
                                        _ExpandedBtn(
                                          icon: player.repeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                          label: 'Lặp lại',
                                          onTap: () => context.read<PlayerController>().toggleRepeat(),
                                          active: player.repeat,
                                        ),
                                        _ExpandedBtn(
                                          icon: Icons.tune_rounded,
                                          label: 'Cài đặt',
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              showDragHandle: true,
                                              builder: (_) => const PlayerSettingsSheet(),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isMain;

  const _MiniButton({required this.icon, required this.onPressed, this.isMain = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: isMain ? 42 : 28),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 24,
    );
  }
}

class _ExpandedBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ExpandedBtn({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
