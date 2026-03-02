import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onSpeak;

  const ResultCard({super.key, required this.title, required this.content, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(onPressed: onSpeak, icon: const Icon(Icons.volume_up)),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(content.isEmpty ? "(Trống)" : content),
          ],
        ),
      ),
    );
  }
}