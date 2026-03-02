import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool show;
  final String text;

  const LoadingOverlay({super.key, required this.show, this.text = "Đang xử lý..."});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 12),
                Text(text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}