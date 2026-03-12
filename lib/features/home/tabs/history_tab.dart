import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/auth_controller.dart';
import '../../auth/login_screen.dart';
import '../../history/history_controller.dart';
import '../../history/history_detail_screen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _type;
  bool _requestedInitialLoad = false;

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthController, bool>((a) => a.loggedIn);
    final c = context.watch<HistoryController>();

    if (loggedIn && !_requestedInitialLoad) {
      _requestedInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<HistoryController>().load(type: _type);
      });
    }

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
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Bạn cần đăng nhập để xem và lưu lịch sử hoạt động.",
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
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
                    onPressed: () =>
                        context.read<HistoryController>().load(type: _type),
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
            final title = preview.isEmpty ? "(Trống)" : preview;

            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryDetailScreen(item: it),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (it.createdAt.isNotEmpty)
                            Text(
                              it.createdAt,
                              style: const TextStyle(color: Colors.black54),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Loại: ${it.actionType}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      if (it.inputData.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          it.inputData,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => c.speakItem(it.resultText),
                            child: const Text("Đọc lại"),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HistoryDetailScreen(item: it),
                                ),
                              );
                            },
                            child: const Text("Mở lại"),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () => c.remove(it.id),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text("Xoá"),
                          ),
                        ],
                      ),
                    ],
                  ),
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