import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_icon.dart';

import '../../auth/auth_controller.dart';
import '../../auth/login_screen.dart';
import '../../caption/caption_screen.dart';
import '../../ocr/ocr_screen.dart';
import '../../read_url/read_url_screen.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenCameraSheet;

  const HomeTab({super.key, required this.onOpenCameraSheet});

  Widget _tile({
    required String asset,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(asset, size: 44, color: AppColors.brandBrown),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                Icon(Icons.mic, color: AppColors.muted),
                SizedBox(width: 10),
                Text(
                  "Mic đang nghe",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Guest Mode\nLịch sử: Không lưu trữ",
                    style: TextStyle(fontSize: 16, height: 1.3),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!auth.loggedIn) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    } else {
                      auth.logout();
                    }
                  },
                  icon: Icon(auth.loggedIn ? Icons.logout : Icons.lock),
                  label: Text(auth.loggedIn ? "Đăng xuất" : "Đăng nhập"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBrown,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _tile(
              asset: AppIcons.ocr,
              title: "Quét chữ",
              subtitle: "OCR ảnh",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OcrScreen()),
              ),
            ),
            _tile(
              asset: AppIcons.image,
              title: "Mô tả ảnh",
              subtitle: "Caption ảnh",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CaptionScreen()),
              ),
            ),
            _tile(
              asset: AppIcons.url, // hoặc AppIcons.read nếu bạn thích icon read
              title: "Đọc web",
              subtitle: "URL → TTS",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadUrlScreen()),
              ),
            ),
            _tile(
              asset: AppIcons.camera,
              title: "Chụp nhanh",
              subtitle: "OCR / Caption",
              onTap: onOpenCameraSheet,
            ),
          ],
        ),
      ],
    );
  }
}