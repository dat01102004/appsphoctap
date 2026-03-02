import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/tts/tts_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/api_client.dart';
import 'data/services/auth_api.dart';
import 'data/services/vision_api.dart';
import 'data/services/read_api.dart';
import 'data/services/history_api.dart';

import 'features/home/home_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/read_url/read_url_controller.dart';
import 'features/ocr/ocr_controller.dart';
import 'features/caption/caption_controller.dart';
import 'features/history/history_controller.dart';

class TalkSightApp extends StatelessWidget {
  const TalkSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => TtsService()..init()),
        Provider(create: (_) => StorageService()),
        ProxyProvider<StorageService, ApiClient>(
          update: (_, storage, __) => ApiClient(storage),
        ),
        ProxyProvider<ApiClient, AuthApi>(
          update: (_, client, __) => AuthApi(client),
        ),
        ProxyProvider<ApiClient, VisionApi>(
          update: (_, client, __) => VisionApi(client),
        ),
        ProxyProvider<ApiClient, ReadApi>(
          update: (_, client, __) => ReadApi(client),
        ),
        ProxyProvider<ApiClient, HistoryApi>(
          update: (_, client, __) => HistoryApi(client),
        ),

        ChangeNotifierProxyProvider3<AuthApi, StorageService, TtsService, AuthController>(
          create: (_) => AuthController(
            AuthApi(ApiClient(StorageService())),
            StorageService(),
            TtsService(),
          ),
          update: (_, authApi, storage, tts, __) {
            final c = AuthController(authApi, storage, tts);
            c.init(); // auto-check token
            return c;
          },
        ),

        ChangeNotifierProxyProvider2<ReadApi, TtsService, ReadUrlController>(
          create: (_) => ReadUrlController(ReadApi(ApiClient(StorageService())), TtsService()),
          update: (_, api, tts, __) => ReadUrlController(api, tts),
        ),
        ChangeNotifierProxyProvider2<VisionApi, TtsService, OcrController>(
          create: (_) => OcrController(VisionApi(ApiClient(StorageService())), TtsService()),
          update: (_, api, tts, __) => OcrController(api, tts),
        ),
        ChangeNotifierProxyProvider2<VisionApi, TtsService, CaptionController>(
          create: (_) => CaptionController(VisionApi(ApiClient(StorageService())), TtsService()),
          update: (_, api, tts, __) => CaptionController(api, tts),
        ),
        ChangeNotifierProxyProvider2<HistoryApi, TtsService, HistoryController>(
          create: (_) => HistoryController(HistoryApi(ApiClient(StorageService())), TtsService()),
          update: (_, api, tts, __) => HistoryController(api, tts),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "TalkSight",
        theme: ThemeData(
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}