import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_icon.dart';

class TalkSightBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TalkSightBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  Widget _item({
    required String asset,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    final color = active ? AppColors.brandBrown : Colors.black54;

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(asset, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BottomAppBar(
        color: const Color(0xFFE7D9C7),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8, // ✅ sát hơn (đừng quá lớn)
        child: SizedBox(
          height: 66, // ✅ về lại 66 cho gọn
          child: Row(
            children: [
              Expanded(
                child: _item(
                  asset: AppIcons.home,
                  label: "Home",
                  active: currentIndex == 0,
                  onPressed: () => onTap(0),
                ),
              ),
              Expanded(
                child: _item(
                  asset: AppIcons.history,
                  label: "Lịch sử",
                  active: currentIndex == 1,
                  onPressed: () => onTap(1),
                ),
              ),

              // ✅ chừa chỗ vừa đủ với FAB 72
              const SizedBox(width: 76),

              Expanded(
                child: _item(
                  asset: AppIcons.tasks,
                  label: "Tác vụ",
                  active: currentIndex == 2,
                  onPressed: () => onTap(2),
                ),
              ),
              Expanded(
                child: _item(
                  asset: AppIcons.settings,
                  label: "Cài đặt",
                  active: currentIndex == 3,
                  onPressed: () => onTap(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}