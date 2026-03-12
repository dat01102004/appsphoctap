import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_icon.dart';

class TalkSightBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;

  const TalkSightBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.height = 72,
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
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(asset, color: color, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
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
        color: AppColors.card,
        elevation: 16,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 4,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: _item(
                  asset: AppIcons.home,
                  label: 'Home',
                  active: currentIndex == 0,
                  onPressed: () => onTap(0),
                ),
              ),
              Expanded(
                child: _item(
                  asset: AppIcons.history,
                  label: 'Lịch sử',
                  active: currentIndex == 1,
                  onPressed: () => onTap(1),
                ),
              ),
              const SizedBox(width: 74),
              Expanded(
                child: _item(
                  asset: AppIcons.tasks,
                  label: 'Tác vụ',
                  active: currentIndex == 2,
                  onPressed: () => onTap(2),
                ),
              ),
              Expanded(
                child: _item(
                  asset: AppIcons.settings,
                  label: 'Cài đặt',
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