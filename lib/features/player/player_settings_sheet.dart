import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/tts/tts_service.dart';

class PlayerSettingsSheet extends StatefulWidget {
  const PlayerSettingsSheet({super.key});

  @override
  State<PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends State<PlayerSettingsSheet> {
  List<dynamic> voices = [];
  Map<String, String>? selected;

  double rate = 0.45;
  double pitch = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tts = context.read<TtsService>();
      rate = tts.rate;
      pitch = tts.pitch;
      final v = await tts.getVoices();
      setState(() => voices = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Cài đặt giọng đọc", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),

          Text("Tốc độ: ${rate.toStringAsFixed(2)}"),
          Slider(
            value: rate,
            min: 0.2,
            max: 0.8,
            onChanged: (v) async {
              setState(() => rate = v);
              await tts.setRate(v);
            },
          ),

          Text("Ngữ điệu (pitch): ${pitch.toStringAsFixed(2)}"),
          Slider(
            value: pitch,
            min: 0.7,
            max: 1.4,
            onChanged: (v) async {
              setState(() => pitch = v);
              await tts.setPitch(v);
            },
          ),

          const SizedBox(height: 10),
          const Text("Giọng nói", style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),

          if (voices.isEmpty)
            const Text("Đang tải danh sách giọng...", style: TextStyle(color: Colors.black54))
          else
            DropdownButtonFormField<Map<String, String>>(
              value: selected,
              items: voices
                  .where((e) => (e is Map) && (e["locale"]?.toString().contains("vi") ?? false))
                  .map<Map<String, String>>((e) => {
                "name": e["name"].toString(),
                "locale": e["locale"].toString(),
              })
                  .map((m) => DropdownMenuItem(
                value: m,
                child: Text("${m["name"]} (${m["locale"]})"),
              ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                selected = v;
                await tts.setVoice(v);
                setState(() {});
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBrown, foregroundColor: Colors.white),
              onPressed: () async {
                await tts.speak("Đây là câu thử giọng đọc của TalkSight.");
              },
              child: const Text("Nghe thử"),
            ),
          ),
        ],
      ),
    );
  }
}