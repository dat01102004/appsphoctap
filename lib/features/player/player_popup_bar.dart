import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../voice/voice_controller.dart';
import 'player_controller.dart';
import 'player_settings_sheet.dart';

class PlayerPopupBar extends StatelessWidget {
  final VoidCallback onOpenList;
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

  String _currentText(PlayerController player) {
    return player.replayText;
  }

  Future<void> _replay(BuildContext context) async {
    final player = context.read<PlayerController>();
    final tts = context.read<TtsService>();
    final voice = context.read<VoiceController>();
    final text = _currentText(player);

    await voice.stop();
    await tts.stop();

    if (text.isEmpty) {
      await tts.speak('Chưa có nội dung để đọc lại.');
      return;
    }

    player.setPlaying(true);
    try {
      await tts.speak(text);
    } finally {
      player.setPlaying(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brandBrownDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 12,
              offset: Offset(0, 6),
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    player.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PopupActionButton(
              icon: Icons.stop_rounded,
              label: 'Dừng',
              tooltip: 'Dừng đọc',
              onPressed: onStop,
              filled: true,
            ),
            const SizedBox(width: 8),
            _PopupActionButton(
              icon: Icons.replay_rounded,
              label: 'Đọc lại',
              tooltip: 'Đọc lại nội dung',
              onPressed: () => _replay(context),
            ),
            IconButton(
              tooltip: player.isPlaying ? 'Tạm dừng' : 'Tiếp tục',
              onPressed: onPlayPause,
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_circle_rounded
                    : Icons.play_circle_rounded,
                color: Colors.white,
              ),
            ),
            IconButton(
              tooltip: 'Mở rộng',
              onPressed: onOpenList,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              color: Colors.white,
            ),
            IconButton(
              tooltip: 'Cài đặt giọng đọc',
              onPressed: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => const PlayerSettingsSheet(),
              ),
              icon: const Icon(Icons.settings_rounded),
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  const _PopupActionButton({
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
        : Colors.white.withValues(alpha: 0.22);
    final foreground = filled ? AppColors.brandBrownDark : Colors.white;

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
                side: filled
                    ? BorderSide.none
                    : BorderSide(color: Colors.white.withValues(alpha: 0.55)),
              ),
            ),
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(
              label,
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
