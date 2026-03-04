import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text("Giọng đọc", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text("UI settings demo (rate/voice/font/theme) — sẽ nối logic sau."),
          ),
        ),
        SizedBox(height: 14),
        Text("Điều khiển bằng giọng nói", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text("Coming soon: bật/tắt STT, cảm nhận lệch…"),
          ),
        ),
      ],
    );
  }
}