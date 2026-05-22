import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/tts/tts_service.dart';
import 'core/voice/global_voice_command_service.dart';
import 'data/services/api_client.dart';
import 'data/services/auth_api.dart';
import 'data/services/history_api.dart';
import 'data/services/news_api.dart';
import 'data/services/read_api.dart';
import 'data/services/settings_api.dart';
import 'data/services/storage_service.dart';
import 'data/services/vision_api.dart';
import 'features/auth/auth_controller.dart';
import 'features/caption/caption_controller.dart';
import 'features/history/history_controller.dart';
import 'features/news/news_assistant_controller.dart';
import 'features/ocr/ocr_controller.dart';
import 'features/player/player_controller.dart';
import 'features/read_url/read_url_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/splash/splash_screen.dart';
import 'features/voice/voice_controller.dart';

class TalkSightApp extends StatelessWidget {
  const TalkSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final client = ApiClient(storage);

    final authApi = AuthApi(client);
    final visionApi = VisionApi(client);
    final readApi = ReadApi(client);
    final historyApi = HistoryApi(client);
    final newsApi = NewsApi(client);
    final settingsApi = SettingsApi(client);
    final tts = TtsService()..init();

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
        Provider.value(value: settingsApi),
        ChangeNotifierProvider(
          create: (_) => SettingsController(settingsApi, storage, tts)..init(),
        ),
        Provider(
          create: (ctx) => GlobalVoiceCommandService(ctx.read(), ctx.read()),
        ),
        ChangeNotifierProvider(create: (_) => VoiceController()),
        ChangeNotifierProvider(
          create: (ctx) => NewsAssistantController(
            ctx.read(),
            ctx.read(),
            ctx.read(),
            ctx.read(),
            ctx.read(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PlayerController()),
        ChangeNotifierProvider(
          create: (ctx) =>
              AuthController(authApi, storage, tts, ctx.read())..init(),
        ),
        ChangeNotifierProvider(create: (_) => ReadUrlController(readApi, tts)),
        ChangeNotifierProvider(create: (_) => OcrController(visionApi, tts)),
        ChangeNotifierProvider(
          create: (_) => CaptionController(visionApi, tts),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryController(historyApi, tts),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mắt Nói',
        theme: AppTheme.light(),
        home: const SplashScreen(),
      ),
    );
  }
}
