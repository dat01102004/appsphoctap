import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_icon.dart';

class TalkSightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isListening;
  final VoidCallback onMicPressed;

  const TalkSightAppBar({
    super.key,
    required this.isListening,
    required this.onMicPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: AppColors.brandBrown,
      title: const Text(
        "TALKSIGHT",
        style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800),
      ),
      leading: IconButton(
        onPressed: onMicPressed,
        iconSize: 24, // ✅ nhỏ lại
        tooltip: isListening ? "Dừng nghe" : "Bắt đầu nghe",
        icon: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: Colors.white,
        ),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 10),
          child: AppIcon(AppIcons.bell, size: 24, color: Colors.white),
        ),
      ],
    );
  }
}