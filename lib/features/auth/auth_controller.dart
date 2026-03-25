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
  String? fullName;
  String? phone;

  AuthController(this.api, this.storage, this.tts);

  String get displayName {
    final name = fullName?.trim() ?? '';
    if (name.isNotEmpty) return name;

    final mail = email?.trim() ?? '';
    if (mail.isNotEmpty) return mail;

    return 'Khách';
  }

  Future<void> init() async {
    final token = await storage.getToken();
    loggedIn = token != null && token.isNotEmpty;

    if (loggedIn) {
      try {
        final me = await api.me();
        email = me.email;
        fullName = me.fullName;
        phone = me.phone;
      } catch (_) {
        await storage.clearToken();
        loggedIn = false;
        email = null;
        fullName = null;
        phone = null;
      }
    }

    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.login(email, password);
    await storage.saveToken(res.accessToken);

    final me = await api.me();
    loggedIn = true;
    this.email = me.email;
    fullName = me.fullName;
    phone = me.phone;

    notifyListeners();
    await tts.speak("Đăng nhập thành công.");
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await api.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );

    await storage.saveToken(res.accessToken);

    final me = await api.me();
    loggedIn = true;
    this.email = me.email;
    this.fullName = me.fullName;
    this.phone = me.phone;

    notifyListeners();
    await tts.speak("Đăng ký thành công.");
  }

  Future<void> logout() async {
    await storage.clearToken();
    loggedIn = false;
    email = null;
    fullName = null;
    phone = null;

    notifyListeners();
    await tts.speak("Đã đăng xuất. Bạn đang ở chế độ khách.");
  }
}