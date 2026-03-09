import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/tts/tts_service.dart';

import 'data/services/api_client.dart';
import 'data/services/auth_api.dart';
import 'data/services/history_api.dart';
import 'data/services/read_api.dart';
import 'data/services/storage_service.dart';
import 'data/services/vision_api.dart';
import 'data/services/news_api.dart';

import 'features/auth/auth_controller.dart';
import 'features/caption/caption_controller.dart';
import 'features/history/history_controller.dart';
import 'features/home/home_screen.dart';
import 'features/ocr/ocr_controller.dart';
import 'features/read_url/read_url_controller.dart';
import 'features/voice/voice_controller.dart';
import 'features/news/news_assistant_controller.dart';
import 'features/player/player_controller.dart';

class TalkSightApp extends StatelessWidget {
  const TalkSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final client = ApiClient(storage);

    final tts = TtsService()..init();

    final authApi = AuthApi(client);
    final visionApi = VisionApi(client);
    final readApi = ReadApi(client);
    final historyApi = HistoryApi(client);
    final newsApi = NewsApi(client);

    return MultiProvider(
      providers: [
        Provider.value(value: storage),
        Provider.value(value: client),
        Provider.value(value: tts),

        Provider.value(value: authApi),
        Provider.value(value: visionApi),
        Provider.value(value: readApi),
        Provider.value(value: historyApi),
        Provider.value(value: newsApi),

        // ✅ 1) VoiceController PHẢI ở trước
        ChangeNotifierProvider(create: (_) => VoiceController()),

        // ✅ 2) NewsAssistantController tạo sau VoiceController
        ChangeNotifierProvider(
          create: (ctx) => NewsAssistantController(
            ctx.read<NewsApi>(),
            ctx.read<ReadApi>(),
            ctx.read<TtsService>(),
            ctx.read<VoiceController>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PlayerController()),
        ChangeNotifierProvider(
          create: (_) => AuthController(authApi, storage, tts)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReadUrlController(readApi, tts),
        ),
        ChangeNotifierProvider(
          create: (_) => OcrController(visionApi, tts),
        ),
        ChangeNotifierProvider(
          create: (_) => CaptionController(visionApi, tts),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryController(historyApi, tts),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "TalkSight",
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}