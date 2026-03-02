import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/big_button.dart';
import '../../core/tts/tts_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../read_url/read_url_screen.dart';
import '../ocr/ocr_screen.dart';
import '../caption/caption_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("TalkSight. Chọn chức năng: Đọc URL, OCR, Mô tả ảnh.");
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("TalkSight"),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => context.read<TtsService>().speak(
              auth.loggedIn
                  ? "Bạn đang đăng nhập. Có thể xem lịch sử."
                  : "Bạn đang ở chế độ khách. Muốn lưu lịch sử hãy đăng nhập.",
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BigButton(
            title: "Đọc URL",
            subtitle: "Đọc nội dung, tóm tắt, tối ưu cho TTS",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadUrlScreen())),
          ),
          BigButton(
            title: "OCR ảnh",
            subtitle: "Chọn ảnh và trích xuất văn bản",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
          ),
          BigButton(
            title: "Mô tả ảnh",
            subtitle: "Chọn ảnh và nghe mô tả",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen())),
          ),
          BigButton(
            title: "Lịch sử",
            subtitle: auth.loggedIn ? "Xem, nghe lại, xoá" : "Cần đăng nhập để xem lịch sử",
            onTap: () {
              if (!auth.loggedIn) {
                context.read<TtsService>().speak("Bạn cần đăng nhập để xem lịch sử.");
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                if (auth.loggedIn) {
                  await auth.logout();
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
              child: Text(auth.loggedIn ? "Đăng xuất" : "Đăng nhập / Đăng ký"),
            ),
          ),
        ],
      ),
    );
  }
}