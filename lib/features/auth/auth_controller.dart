import 'package:flutter/material.dart';
import '../../core/tts/tts_service.dart';
import '../../data/services/auth_api.dart';
import '../../data/services/storage_service.dart';

class AuthController extends ChangeNotifier {
  final AuthApi api;
  final StorageService storage;
  final TtsService tts;

  bool loggedIn = false;
  String? email;

  AuthController(this.api, this.storage, this.tts);

  Future<void> init() async {
    final token = await storage.getToken();
    loggedIn = token != null && token.isNotEmpty;
    if (loggedIn) {
      try {
        final me = await api.me();
        email = me.email;
      } catch (_) {
        // token hết hạn => logout
        await storage.clearToken();
        loggedIn = false;
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.login(email, password);
    await storage.saveToken(res.accessToken);
    loggedIn = true;
    this.email = email;
    notifyListeners();
    await tts.speak("Đăng nhập thành công.");
  }

  Future<void> register(String email, String password) async {
    final res = await api.register(email, password);
    await storage.saveToken(res.accessToken);
    loggedIn = true;
    this.email = email;
    notifyListeners();
    await tts.speak("Đăng ký thành công.");
  }

  Future<void> logout() async {
    await storage.clearToken();
    loggedIn = false;
    email = null;
    notifyListeners();
    await tts.speak("Đã đăng xuất. Bạn đang ở chế độ khách.");
  }
}