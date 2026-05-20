import 'package:flutter/material.dart';

import '../../core/errors/error_utils.dart';
import '../../core/tts/tts_service.dart';
import '../../data/services/auth_api.dart';
import '../../data/services/storage_service.dart';
import '../settings/settings_controller.dart';

class AuthFriendlyException implements Exception {
  final String message;

  AuthFriendlyException(this.message);

  @override
  String toString() => message;
}

class AuthController extends ChangeNotifier {
  final AuthApi api;
  final StorageService storage;
  final TtsService tts;
  final SettingsController settings;

  bool loggedIn = false;
  String? email;
  String? fullName;
  String? phone;

  String? errorMessage;

  AuthController(this.api, this.storage, this.tts, this.settings);

  String get displayName {
    final name = fullName?.trim() ?? '';
    if (name.isNotEmpty) return name;

    final mail = email?.trim() ?? '';
    if (mail.isNotEmpty) return mail;

    return 'Khách';
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
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
        await settings.loadForCurrentAuth();
      } catch (_) {
        await storage.clearToken();
        loggedIn = false;
        email = null;
        fullName = null;
        phone = null;
        await settings.resetSettingsToDefault(
          reason: 'Phiên đăng nhập hết hạn. Đã dùng cài đặt mặc định.',
        );
      }
    } else {
      await settings.resetSettingsToDefault(
        reason: 'Chưa đăng nhập: đang dùng cài đặt mặc định trên thiết bị.',
      );
    }

    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (!loggedIn) return;

    final me = await api.me();

    email = me.email;
    fullName = me.fullName;
    phone = me.phone;

    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      errorMessage = null;
      notifyListeners();

      final res = await api.login(email, password);
      await storage.saveToken(res.accessToken);

      final me = await api.me();

      loggedIn = true;
      this.email = me.email;
      fullName = me.fullName;
      phone = me.phone;

      await settings.loadForCurrentAuth();

      notifyListeners();
      await tts.speak("Đăng nhập thành công.");
    } catch (e) {
      final message = friendlyApiMessage(e, feature: 'auth_login');

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      errorMessage = null;
      notifyListeners();

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

      await settings.loadForCurrentAuth();

      notifyListeners();
      await tts.speak("Đăng ký thành công.");
    } catch (e) {
      final message = friendlyApiMessage(e, feature: 'auth_register');

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      errorMessage = null;
      notifyListeners();

      final me = await api.updateMe(
        fullName: fullName,
        email: email,
        phone: phone,
      );

      loggedIn = true;
      this.email = me.email;
      this.fullName = me.fullName;
      this.phone = me.phone;

      notifyListeners();
      await tts.speak("Đã cập nhật thông tin người dùng.");
    } catch (e) {
      final message = friendlyApiMessage(e, feature: 'auth');

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    }
  }

  Future<void> logout() async {
    await storage.clearToken();
    await settings.resetSettingsToDefault(
      reason: 'Đã đăng xuất. Đang dùng cài đặt mặc định.',
    );

    loggedIn = false;
    email = null;
    fullName = null;
    phone = null;
    errorMessage = null;

    notifyListeners();
    await tts.speak("Đã đăng xuất. Bạn đang ở chế độ khách.");
  }
}
