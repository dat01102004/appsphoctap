import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/history_models.dart';

class HistoryDetailScreen extends StatefulWidget {
  final HistoryItem item;

  const HistoryDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool _speaking = false;

  String get _title {
    switch (widget.item.actionType) {
      case "ocr":
        return "Kết quả OCR đã lưu";
      case "caption":
        return "Mô tả ảnh đã lưu";
      case "read_url":
        return "Bài báo đã lưu";
      default:
        return "Chi tiết lịch sử";
    }
  }

  String get _resultText {
    final v = widget.item.resultText.trim();
    if (v.isEmpty) return "Không có nội dung.";
    return v;
  }

  String get _inputText {
    final v = widget.item.inputData.trim();
    if (v.isEmpty) return "";
    return v;
  }

  Future<void> _speak() async {
    final tts = context.read<TtsService>();
    setState(() => _speaking = true);
    try {
      await tts.stop();
      await Future.delayed(const Duration(milliseconds: 120));
      await tts.speak(_resultText);
    } finally {
      if (mounted) {
        setState(() => _speaking = false);
      }
    }
  }

  Future<void> _stop() async {
    await context.read<TtsService>().stop();
    if (mounted) {
      setState(() => _speaking = false);
    }
  }

  @override
  void dispose() {
    context.read<TtsService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Loại: ${widget.item.actionType}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  if (widget.item.createdAt.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.item.createdAt,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_inputText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Đầu vào đã lưu",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _inputText,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Nội dung đã lưu",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _resultText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBrown,
                foregroundColor: Colors.white,
              ),
              onPressed: _speaking ? _stop : _speak,
              icon: Icon(
                _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              ),
              label: Text(_speaking ? "Dừng đọc" : "Đọc lại"),
            ),
          ),
        ],
      ),
    );
  }
}