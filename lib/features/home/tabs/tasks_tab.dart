import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../ocr/ocr_screen.dart';
import '../../caption/caption_screen.dart';
import '../../read_url/read_url_screen.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  Widget _task({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.cardStroke.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.brandBrown),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text("Tác vụ", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        _task(
          icon: Icons.document_scanner_outlined,
          title: "Quét chữ",
          subtitle: "Quét hình ảnh thành văn bản",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
        ),
        _task(
          icon: Icons.image_outlined,
          title: "Mô tả ảnh",
          subtitle: "Mô tả hình ảnh và đọc TTS",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen())),
        ),
        _task(
          icon: Icons.public_outlined,
          title: "Đọc URL website",
          subtitle: "Tóm tắt + tối ưu cho TTS",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadUrlScreen())),
        ),
        _task(
          icon: Icons.insert_drive_file_outlined,
          title: "Đọc File",
          subtitle: "Coming soon",
          onTap: () {},
        ),
      ],
    );
  }
}