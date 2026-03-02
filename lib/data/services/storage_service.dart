import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();
  static const _kToken = "access_token";

  Future<void> saveToken(String token) => _storage.write(key: _kToken, value: token);
  Future<String?> getToken() => _storage.read(key: _kToken);
  Future<void> clearToken() => _storage.delete(key: _kToken);
}