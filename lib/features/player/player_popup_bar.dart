import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_icon.dart';
import '../voice/voice_controller.dart';
import '../../core/tts/tts_service.dart';
import 'player_controller.dart';
import 'player_settings_sheet.dart';

class PlayerPopupBar extends StatelessWidget {
  final VoidCallback onOpenList; // mở danh sách (history/news list)
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onStop;
  final Future<void> Function() onMic;

  const PlayerPopupBar({
    super.key,
    required this.onOpenList,
    required this.onPlayPause,
    required this.onStop,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PlayerController>();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brandBrown,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(blurRadius: 12, offset: Offset(0, 6), color: Colors.black26),
          ],
        ),
        child: Row(
          children: [
            // Left: Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pc.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Controls
            IconButton(
              tooltip: "Dừng",
              onPressed: () => onStop(),
              icon: const Icon(Icons.stop, color: Colors.white),
            ),

            IconButton(
              tooltip: pc.isPlaying ? "Tạm dừng" : "Phát",
              onPressed: () => onPlayPause(),
              icon: Icon(pc.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            ),

            IconButton(
              tooltip: pc.isListening ? "Dừng mic" : "Bật mic",
              onPressed: () => onMic(),
              icon: Icon(pc.isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
            ),

            IconButton(
              tooltip: pc.repeat ? "Tắt lặp" : "Lặp lại",
              onPressed: () => context.read<PlayerController>().toggleRepeat(),
              icon: Icon(pc.repeat ? Icons.repeat_one : Icons.repeat, color: Colors.white),
            ),

            IconButton(
              tooltip: "Danh sách",
              onPressed: onOpenList,
              icon: const Icon(Icons.queue_music, color: Colors.white),
            ),

            IconButton(
              tooltip: "Cài đặt giọng đọc",
              onPressed: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => const PlayerSettingsSheet(),
              ),
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}