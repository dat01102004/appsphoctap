import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/auth_controller.dart';
import '../../auth/login_screen.dart';
import '../../history/history_controller.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _type; // null=all, "ocr", "caption", "read_url"
  bool _requestedInitialLoad = false;

  @override
  Widget build(BuildContext context) {
    // dùng select để chỉ rebuild khi loggedIn đổi
    final loggedIn = context.select<AuthController, bool>((a) => a.loggedIn);
    final c = context.watch<HistoryController>();

    // ✅ chỉ gọi load 1 lần khi đã login và chưa load lần đầu
    if (loggedIn && !_requestedInitialLoad) {
      _requestedInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<HistoryController>().load(type: _type);
      });
    }

    // nếu logout thì reset để lần login sau load lại
    if (!loggedIn && _requestedInitialLoad) {
      _requestedInitialLoad = false;
    }

    if (!loggedIn) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Đăng nhập để lưu lịch sử\n(Guest mode)",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text("Bạn cần đăng nhập để xem và lưu lịch sử hoạt động."),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text("Đăng nhập"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip("Tất cả", null),
                  const SizedBox(width: 8),
                  _chip("Quét chữ", "ocr"),
                  const SizedBox(width: 8),
                  _chip("Mô tả ảnh", "caption"),
                  const SizedBox(width: 8),
                  _chip("Đọc báo", "read_url"),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: "Tải lại",
                    onPressed: () => context.read<HistoryController>().load(type: _type),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (c.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          )
        else if (c.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Chưa có lịch sử."),
          )
        else
          ...c.items.map((it) {
            final preview = it.resultText.trim().replaceAll("\n", " ");
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.isEmpty ? "(Trống)" : preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (it.createdAt.isEmpty) ? "" : it.createdAt,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => c.speakItem(it.resultText),
                          child: const Text("Đọc lại"),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => c.remove(it.id),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text("Xoá"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _chip(String label, String? typeValue) {
    final selected = _type == typeValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.cardStroke.withOpacity(0.6),
      onSelected: (_) {
        setState(() => _type = typeValue);
        context.read<HistoryController>().load(type: _type);
      },
    );
  }
}