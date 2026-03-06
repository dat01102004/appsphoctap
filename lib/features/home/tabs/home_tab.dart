import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_icon.dart';

import '../../auth/auth_controller.dart';
import '../../auth/login_screen.dart';
import '../../caption/caption_screen.dart';
import '../../news/news_assistant_screen.dart';
import '../../ocr/ocr_screen.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenCameraSheet;

  // ✅ mic state + action
  final bool isListening;
  final String lastWords;
  final VoidCallback onMicTap;

  const HomeTab({
    super.key,
    required this.onOpenCameraSheet,
    required this.isListening,
    required this.lastWords,
    required this.onMicTap,
  });

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
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final micTitle = isListening ? "Đang nghe..." : "Nhấn mic để nói";
    final micSub = isListening
        ? (lastWords.trim().isEmpty ? "..." : lastWords)
        : "Bạn có thể nói: đọc báo, quét chữ, mô tả ảnh, chụp nhanh";

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ MIC STATUS CARD (tap để bật/tắt)
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onMicTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: AppColors.brandBrown,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          micTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          micSub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isListening ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                    color: Colors.black45,
                  ),
                ],
              ),
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
              asset: AppIcons.url,
              title: "Đọc báo",
              subtitle: "Tin mới",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewsAssistantScreen()),
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