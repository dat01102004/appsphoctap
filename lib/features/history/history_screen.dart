import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../core/tts/tts_service.dart';
import 'history_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TtsService>().speak("Màn hình lịch sử. Vuốt để chọn mục và nghe lại.");
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<HistoryController>().load());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HistoryController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Lịch sử")),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: c.items.length,
            itemBuilder: (_, i) {
              final it = c.items[i];
              return Card(
                child: ListTile(
                  title: Text("${it.actionType} • #${it.id}"),
                  subtitle: Text(it.resultText, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => context.read<TtsService>().speak(it.resultText),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => c.remove(it.id),
                  ),
                ),
              );
            },
          ),
          LoadingOverlay(show: c.loading),
        ],
      ),
    );
  }
}