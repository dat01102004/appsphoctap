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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(asset, size: 42, color: AppColors.brandBrown),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthController auth) async {
    await auth.logout();
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }



  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final micTitle = isListening ? 'Đang nghe...' : 'Nhấn mic để nói';
    final micSub = isListening
        ? (lastWords.trim().isEmpty ? '...' : lastWords)
        : 'Bạn có thể nói: đăng nhập, đăng ký, đọc báo, quét chữ, mô tả ảnh, xem lịch sử';

    final primaryText = auth.loggedIn ? (auth.email ?? 'Người dùng') : 'Khách';
    final secondaryText =
    auth.loggedIn ? 'Lịch sử: Đang lưu trữ' : 'Lịch sử: Không lưu trữ';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onMicTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: AppColors.brandBrown,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          micTitle,
                          style: const TextStyle(
                            fontSize: 12,
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
                    isListening
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
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
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.brandBrown,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        secondaryText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (auth.loggedIn)
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleLogout(context, auth),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Đăng xuất'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBrown,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => _openLogin(context),
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: const Text('Đăng nhập'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBrown,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
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
          childAspectRatio: 1.10,
          children: [
            _tile(
              asset: AppIcons.ocr,
              title: 'Quét chữ',
              subtitle: 'OCR ảnh',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OcrScreen()),
              ),
            ),
            _tile(
              asset: AppIcons.image,
              title: 'Mô tả ảnh',
              subtitle: 'Caption ảnh',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CaptionScreen()),
              ),
            ),
            _tile(
              asset: AppIcons.url,
              title: 'Đọc báo',
              subtitle: 'Tin mới',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewsAssistantScreen()),
              ),
            ),
            _tile(
              asset: AppIcons.camera,
              title: 'Chụp nhanh',
              subtitle: 'OCR / Caption',
              onTap: onOpenCameraSheet,
            ),
          ],
        ),
      ],
    );
  }
}