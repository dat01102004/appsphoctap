import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../voice/voice_controller.dart';
import 'player_controller.dart';
import 'player_settings_sheet.dart';

class PlayerSlidingPanel extends StatefulWidget {
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onStop;
  final Future<void> Function() onReplay;
  final Future<void> Function() onMic;

  const PlayerSlidingPanel({
    super.key,
    required this.onPlayPause,
    required this.onStop,
    required this.onReplay,
    required this.onMic,
  });

  @override
  State<PlayerSlidingPanel> createState() => _PlayerSlidingPanelState();
}

class _PlayerSlidingPanelState extends State<PlayerSlidingPanel> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  double _extent = 0.13;
  bool get _expanded => _extent > 0.22;

  void _toggleExpand() {
    final target = _expanded ? 0.13 : 0.52;
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
        ? (voice.lastWords.trim().isEmpty
              ? 'Đang lắng nghe...'
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
        initialChildSize: 0.13,
        minChildSize: 0.13,
        maxChildSize: 0.52,
        snap: true,
        snapSizes: const [0.13, 0.52],
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
                        padding: const EdgeInsets.fromLTRB(18, 4, 12, 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _toggleExpand,
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player.title.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          collapsedText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _MiniTextButton(
                                  icon: Icons.stop_rounded,
                                  label: 'Dừng',
                                  tooltip: 'Dừng đọc',
                                  onPressed: widget.onStop,
                                  filled: true,
                                ),
                                const SizedBox(width: 8),
                                _MiniTextButton(
                                  icon: Icons.replay_rounded,
                                  label: 'Đọc lại',
                                  tooltip: 'Đọc lại nội dung',
                                  onPressed: widget.onReplay,
                                ),
                                _MiniButton(
                                  icon: _expanded
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  tooltip: _expanded
                                      ? 'Thu gọn trình đọc'
                                      : 'Mở rộng trình đọc',
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
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
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
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _WideActionButton(
                                            icon: Icons.stop_rounded,
                                            label: 'Dừng đọc',
                                            tooltip: 'Dừng đọc',
                                            onTap: widget.onStop,
                                            filled: true,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _WideActionButton(
                                            icon: Icons.replay_rounded,
                                            label: 'Đọc lại',
                                            tooltip: 'Đọc lại nội dung',
                                            onTap: widget.onReplay,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _ExpandedBtn(
                                          icon: player.isPlaying
                                              ? Icons.pause_circle_rounded
                                              : Icons.play_circle_rounded,
                                          label: player.isPlaying
                                              ? 'Tạm dừng'
                                              : 'Tiếp tục',
                                          onTap: widget.onPlayPause,
                                          active: player.isPlaying,
                                        ),
                                        _ExpandedBtn(
                                          icon: voice.isListening
                                              ? Icons.mic_rounded
                                              : Icons.mic_none_rounded,
                                          label: 'Ra lệnh',
                                          onTap: widget.onMic,
                                          active: voice.isListening,
                                        ),
                                        _ExpandedBtn(
                                          icon: player.repeat
                                              ? Icons.repeat_one_rounded
                                              : Icons.repeat_rounded,
                                          label: 'Lặp lại',
                                          onTap: () => context
                                              .read<PlayerController>()
                                              .toggleRepeat(),
                                          active: player.repeat,
                                        ),
                                        _ExpandedBtn(
                                          icon: Icons.tune_rounded,
                                          label: 'Cài đặt',
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              showDragHandle: true,
                                              builder: (_) =>
                                                  const PlayerSettingsSheet(),
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
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 28),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 42),
      splashRadius: 24,
    );
  }
}

class _MiniTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  const _MiniTextButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.13);
    final foreground = filled ? AppColors.brandBrown : Colors.white;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          height: 42,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: filled ? 0 : 0.18),
                ),
              ),
            ),
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  const _WideActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.12);
    final foreground = filled ? AppColors.brandBrown : Colors.white;

    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: background,
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 21),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _ExpandedBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ExpandedBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

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
              color: active
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
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
          ),
        ),
      ],
    );
  }
}
