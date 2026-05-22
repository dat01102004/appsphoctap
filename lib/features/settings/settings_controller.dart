import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../../core/tts/tts_service.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/settings_api.dart';
import '../../data/services/storage_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsApi api;
  final StorageService storage;
  final TtsService tts;

  SettingsModel current = SettingsModel.defaults;
  bool loading = false;
  bool saving = false;
  String? message;

  SettingsController(this.api, this.storage, this.tts);

  Future<void> init() {
    return loadForCurrentAuth();
  }

  Future<void> resetSettingsToDefault({String? reason}) async {
    current = SettingsModel.defaults;
    message = reason;
    await _apply(current);
    notifyListeners();
  }

  Future<void> loadForCurrentAuth() async {
    loading = true;
    message = null;
    notifyListeners();

    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      loading = false;
      await resetSettingsToDefault(
        reason: 'Chưa đăng nhập: đang dùng cài đặt mặc định trên thiết bị.',
      );
      return;
    }

    try {
      current = SettingsModel.normalized(await api.me());
      await _apply(current);
      message = null;
    } catch (_) {
      current = SettingsModel.defaults;
      await _apply(current);
      message = 'Không tải được cài đặt giọng đọc. Đã dùng mặc định.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setRate(double value) async {
    current = SettingsModel.normalized(current.copyWith(rate: value));
    await tts.setRate(current.rate);
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    current = SettingsModel.normalized(current.copyWith(volume: value));
    await tts.setVolume(current.volume);
    notifyListeners();
  }

  Future<void> setPitch(double value) async {
    current = SettingsModel.normalized(current.copyWith(pitch: value));
    await tts.setPitch(current.pitch);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    current = SettingsModel.normalized(current.copyWith(language: value));
    await tts.setLanguage(current.language);
    notifyListeners();
  }

  Future<void> setVoice(String? value, {String? locale}) async {
    current = SettingsModel.normalized(
      current.copyWith(
        voice: value,
        clearVoice: value == null || value.trim().isEmpty,
        language: locale,
      ),
    );
    await tts.setLanguage(current.language);
    await tts.setVoiceName(current.voice);
    notifyListeners();
  }

  Future<SettingsModel> saveCurrent() async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      message = 'Bạn cần đăng nhập để lưu cài đặt giọng đọc.';
      notifyListeners();
      throw StateError(message!);
    }

    saving = true;
    message = null;
    notifyListeners();

    try {
      current = SettingsModel.normalized(await api.updateMe(current));
      await _apply(current);
      message = 'Đã lưu cài đặt giọng đọc.';
      return current;
    } catch (e) {
      if (_isUnauthorized(e)) {
        current = SettingsModel.defaults;
        await _apply(current);
        message = 'Phiên đăng nhập hết hạn. Đã dùng cài đặt mặc định.';
      } else {
        message = 'Không lưu được cài đặt. Vui lòng thử lại.';
      }
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _apply(SettingsModel settings) {
    return tts.configure(
      voice: settings.voice,
      rate: settings.rate,
      pitch: settings.pitch,
      volume: settings.volume,
      language: settings.language,
    );
  }

  bool _isUnauthorized(Object error) {
    if (error is ApiException) return error.statusCode == 401;
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return inner.statusCode == 401;
      return error.response?.statusCode == 401;
    }
    return false;
  }
}
