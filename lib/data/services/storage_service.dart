import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _kToken = "access_token";
  static const _kSeenFirstOpenIntro = "seen_first_open_intro";

  Future<void> saveToken(String token) {
    return _storage.write(key: _kToken, value: token);
  }

  Future<String?> getToken() {
    return _storage.read(key: _kToken);
  }

  Future<void> clearToken() {
    return _storage.delete(key: _kToken);
  }

  Future<bool> hasSeenFirstOpenIntro() async {
    final value = await _storage.read(key: _kSeenFirstOpenIntro);
    return value == 'true';
  }

  Future<void> markSeenFirstOpenIntro() {
    return _storage.write(
      key: _kSeenFirstOpenIntro,
      value: 'true',
    );
  }

  Future<void> resetFirstOpenIntro() {
    return _storage.delete(key: _kSeenFirstOpenIntro);
  }
}