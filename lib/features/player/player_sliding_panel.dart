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

  double _extent = 0.12;
  bool get _expanded => _extent > 0.22;

  void _toggleExpand() {
    final target = _expanded ? 0.12 : 0.40;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PlayerController>();
    final voice = context.watch<VoiceController>();

    // dòng 2: ưu tiên hiển thị mic listening
    final line2 = voice.isListening
        ? (voice.lastWords.trim().isEmpty ? "Đang nghe..." : "Đang nghe: ${voice.lastWords}")
        : pc.subtitle;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        setState(() => _extent = n.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: 0.12,
        minChildSize: 0.10,
        maxChildSize: 0.40,
        snap: true,
        snapSizes: const [0.12, 0.40],
        builder: (context, scrollController) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.brandBrown,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(blurRadius: 14, offset: Offset(0, 8), color: Colors.black26),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== MINI HEADER (luôn hiện) =====
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pc.title,
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
                                  line2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          _iconBtnAsync(
                            tooltip: "Dừng",
                            icon: Icons.stop,
                            onTap: widget.onStop,
                          ),
                          _iconBtnAsync(
                            tooltip: pc.isPlaying ? "Tạm dừng" : "Phát",
                            icon: pc.isPlaying ? Icons.pause : Icons.play_arrow,
                            onTap: widget.onPlayPause,
                          ),
                          _iconBtnAsync(
                            tooltip: voice.isListening ? "Dừng mic" : "Bật mic",
                            icon: voice.isListening ? Icons.mic : Icons.mic_none,
                            onTap: widget.onMic,
                          ),
                          _iconBtnSync(
                            tooltip: pc.repeat ? "Tắt lặp" : "Lặp lại",
                            icon: pc.repeat ? Icons.repeat_one : Icons.repeat,
                            onTap: () => context.read<PlayerController>().toggleRepeat(),
                          ),

                          // ✅ Settings đặt cạnh Repeat (thay cho Danh sách)
                          _iconBtnSync(
                            tooltip: "Cài đặt giọng đọc",
                            icon: Icons.settings,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                builder: (_) => const PlayerSettingsSheet(),
                              );
                            },
                          ),

                          // ✅ mũi tên lên/xuống như app nghe nhạc
                          _iconBtnSync(
                            tooltip: _expanded ? "Thu nhỏ" : "Mở rộng",
                            icon: _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            onTap: _toggleExpand,
                          ),
                        ],
                      ),

                      // ===== EXPANDED CONTENT (bỏ nút danh sách) =====
                      if (_expanded) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pc.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ✅ Hiển thị đầy đủ nội dung đang đọc
                              Text(
                                line2,
                                style: const TextStyle(color: Colors.white70, height: 1.35),
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
          );
        },
      ),
    );
  }

  Widget _iconBtnAsync({
    required String tooltip,
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () async => onTap(),
      icon: Icon(icon, color: Colors.white),
    );
  }

  Widget _iconBtnSync({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
    );
  }
}