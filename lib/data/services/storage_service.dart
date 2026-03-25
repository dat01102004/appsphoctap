import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _kToken = "access_token";

  Future<void> saveToken(String token) {
    return _storage.write(key: _kToken, value: token);
  }

  Future<String?> getToken() {
    return _storage.read(key: _kToken);
  }

  Future<void> clearToken() {
    return _storage.delete(key: _kToken);
  }
}