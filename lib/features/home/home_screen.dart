import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tts/tts_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../history/history_screen.dart';
import '../ocr/ocr_screen.dart';
import '../caption/caption_screen.dart';
import '../read_url/read_url_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _brown = Color(0xFF8B6A2B);
  static const _bg = Color(0xFFF4EFE6);

  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("TalkSight. Chọn chức năng hoặc bấm nút camera để chụp và quét.");
  }

  void _openLogin() => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  void _openHistory(AuthController auth) {
    if (!auth.loggedIn) {
      context.read<TtsService>().speak("Bạn cần đăng nhập để xem lịch sử.");
      _openLogin();
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  Future<void> _openCameraActionSheet() async {
    // Bấm nút camera -> hỏi người dùng muốn OCR hay Caption
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text("Chụp để quét chữ (OCR)"),
              onTap: () => Navigator.pop(context, "ocr"),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Chụp để mô tả ảnh"),
              onTap: () => Navigator.pop(context, "caption"),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == "ocr") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen()));
    } else if (choice == "caption") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen()));
    }
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 54, color: _brown),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, textAlign: TextAlign.center),
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

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "TALKSIGHT",
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.mic),
          onPressed: () => context.read<TtsService>().speak("Tính năng giọng nói sẽ tích hợp sau."),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.read<TtsService>().speak("Bạn có thể quét chữ, mô tả ảnh hoặc đọc web."),
          ),
        ],
      ),

      // FAB camera ở giữa
      floatingActionButton: FloatingActionButton(
        backgroundColor: _brown,
        onPressed: _openCameraActionSheet,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        color: const Color(0xFFE6DED1),
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: "Home",
                icon: const Icon(Icons.home),
                onPressed: () => context.read<TtsService>().speak("Trang chủ"),
              ),
              IconButton(
                tooltip: "Lịch sử",
                icon: const Icon(Icons.menu_book),
                onPressed: () => _openHistory(auth),
              ),
              const SizedBox(width: 42), // chừa chỗ cho FAB
              IconButton(
                tooltip: "Tác vụ",
                icon: const Icon(Icons.list_alt),
                onPressed: () => context.read<TtsService>().speak("Tác vụ. Bạn sẽ bổ sung sau."),
              ),
              IconButton(
                tooltip: "Cài đặt",
                icon: const Icon(Icons.settings),
                onPressed: () => context.read<TtsService>().speak("Cài đặt. Bạn sẽ bổ sung sau."),
              ),
            ],
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Khối trạng thái như thiết kế (Guest mode + thông tin)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Icon(Icons.mic, color: _brown),
                    SizedBox(width: 10),
                    Text(
                      "Mic đang nghe",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _brown),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _brown,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          auth.loggedIn ? "Logged In" : "Guest Mode",
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DefaultTextStyle(
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Tốc độ đọc: Vừa"),
                              const Text("Giọng đọc: vi-VN"),
                              Text("Lịch sử: ${auth.loggedIn ? "Có" : "Không"}"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Grid 2x2 như thiết kế
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _tile(
                icon: Icons.document_scanner,
                title: "Quét chữ",
                subtitle: "(ocr)",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
              ),
              _tile(
                icon: Icons.image,
                title: "Mô tả ảnh",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptionScreen())),
              ),
              _tile(
                icon: Icons.radio,
                title: "Đọc web",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadUrlScreen())),
              ),
              _tile(
                icon: Icons.person,
                title: "Đăng nhập",
                subtitle: "(Đăng nhập để lưu lại lịch sử)",
                onTap: () {
                  if (auth.loggedIn) {
                    context.read<TtsService>().speak("Bạn đã đăng nhập. Bấm để đăng xuất.");
                    auth.logout();
                  } else {
                    _openLogin();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 90), // chừa khoảng cho bottom bar
        ],
      ),
    );
  }
}