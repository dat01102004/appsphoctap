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

  Widget _modernTile({
    required String asset,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgBeige.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(asset, size: 32, color: AppColors.brandBrown),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final micTitle = isListening ? 'Đang lắng nghe...' : 'Nhấn mic để ra lệnh';
    final micSub = isListening
        ? (lastWords.trim().isEmpty ? 'Mời bạn nói...' : lastWords)
        : 'Bạn có thể nói: quét chữ, đọc báo, đăng nhập...';

    final primaryText = auth.loggedIn ? auth.displayName : 'Chào bạn, Khách';
    final secondaryText = auth.loggedIn
        ? 'Tài khoản của bạn đã sẵn sàng'
        : 'Đăng nhập để lưu lịch sử quét';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      children: [
        // Mic Card
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onMicTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brandBrown,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            micTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            micSub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Profile Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardStroke),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.cardStroke.withValues(alpha: 0.65),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.brandBrown,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryText,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryText,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!auth.loggedIn)
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBrown,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Grid Menu
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95,
          children: [
            _modernTile(
              asset: AppIcons.ocr,
              title: 'Quét chữ',
              subtitle: 'Nhận diện văn bản',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OcrScreen()),
              ),
            ),
            _modernTile(
              asset: AppIcons.image,
              title: 'Mô tả ảnh',
              subtitle: 'Xem nội dung ảnh',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CaptionScreen()),
              ),
            ),
            _modernTile(
              asset: AppIcons.url,
              title: 'Đọc báo',
              subtitle: 'Tin tức mới nhất',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewsAssistantScreen()),
              ),
            ),
            _modernTile(
              asset: AppIcons.camera,
              title: 'Chụp nhanh',
              subtitle: 'Trực tiếp 24/7',
              onTap: onOpenCameraSheet,
            ),
          ],
        ),
      ],
    );
  }
}
