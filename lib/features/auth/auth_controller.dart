import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/tts/tts_service.dart';
import '../../data/services/auth_api.dart';
import '../../data/services/storage_service.dart';

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

  bool loggedIn = false;
  String? email;
  String? fullName;
  String? phone;

  String? errorMessage;

  AuthController(this.api, this.storage, this.tts);

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

      notifyListeners();
      await tts.speak("Đăng nhập thành công.");
    } on DioException catch (e) {
      final message = _friendlyLoginError(e);

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    } catch (_) {
      const message = 'Đăng nhập thất bại. Vui lòng thử lại.';

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

      notifyListeners();
      await tts.speak("Đăng ký thành công.");
    } on DioException catch (e) {
      final message = _friendlyRegisterError(e);

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    } catch (_) {
      const message = 'Đăng ký thất bại. Vui lòng thử lại.';

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
    } on DioException catch (e) {
      final message = _friendlyUpdateProfileError(e);

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    } catch (_) {
      const message = 'Cập nhật thông tin thất bại. Vui lòng thử lại.';

      errorMessage = message;
      notifyListeners();

      await tts.speak(message);
      throw AuthFriendlyException(message);
    }
  }

  Future<void> logout() async {
    await storage.clearToken();

    loggedIn = false;
    email = null;
    fullName = null;
    phone = null;
    errorMessage = null;

    notifyListeners();
    await tts.speak("Đã đăng xuất. Bạn đang ở chế độ khách.");
  }

  String _friendlyLoginError(DioException e) {
    final statusCode = e.response?.statusCode;
    final detail = _extractDetail(e);

    if (statusCode == 401 || statusCode == 403) {
      return 'Email hoặc mật khẩu chưa đúng. Vui lòng kiểm tra lại.';
    }

    if (statusCode == 404) {
      return 'Không tìm thấy tài khoản này. Bạn có thể đăng ký tài khoản mới.';
    }

    if (statusCode == 422) {
      return 'Thông tin đăng nhập chưa đúng định dạng. Vui lòng kiểm tra lại email và mật khẩu.';
    }

    if (statusCode == 500) {
      return 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.';
    }

    if (detail.isNotEmpty && !_looksLikeRawError(detail)) {
      return detail;
    }

    return 'Đăng nhập thất bại. Vui lòng thử lại.';
  }

  String _friendlyRegisterError(DioException e) {
    final statusCode = e.response?.statusCode;
    final detail = _extractDetail(e);
    final detailNorm = _normalize(detail);

    if (statusCode == 409) {
      if (detailNorm.contains('email')) {
        return 'Email này đã được đăng ký. Bạn hãy đăng nhập hoặc dùng email khác.';
      }

      if (detailNorm.contains('phone') ||
          detailNorm.contains('so dien thoai') ||
          detailNorm.contains('sdt')) {
        return 'Số điện thoại này đã được đăng ký. Bạn hãy dùng số khác.';
      }

      return 'Tài khoản này đã tồn tại. Bạn hãy đăng nhập hoặc dùng thông tin khác.';
    }

    if (statusCode == 422) {
      return 'Thông tin đăng ký chưa đúng. Vui lòng kiểm tra lại họ tên, email, số điện thoại và mật khẩu.';
    }

    if (statusCode == 400) {
      return 'Thông tin đăng ký chưa hợp lệ. Vui lòng kiểm tra lại.';
    }

    if (statusCode == 500) {
      return 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.';
    }

    if (detail.isNotEmpty && !_looksLikeRawError(detail)) {
      return detail;
    }

    return 'Đăng ký thất bại. Vui lòng thử lại.';
  }

  String _friendlyUpdateProfileError(DioException e) {
    final statusCode = e.response?.statusCode;
    final detail = _extractDetail(e);
    final detailNorm = _normalize(detail);

    if (statusCode == 409) {
      if (detailNorm.contains('email')) {
        return 'Email này đã được dùng bởi tài khoản khác.';
      }

      if (detailNorm.contains('phone') ||
          detailNorm.contains('so dien thoai') ||
          detailNorm.contains('sdt')) {
        return 'Số điện thoại này đã được dùng bởi tài khoản khác.';
      }

      return 'Thông tin này đã tồn tại trên hệ thống.';
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }

    if (statusCode == 422) {
      return 'Thông tin cập nhật chưa đúng định dạng. Vui lòng kiểm tra lại.';
    }

    if (statusCode == 500) {
      return 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.';
    }

    if (detail.isNotEmpty && !_looksLikeRawError(detail)) {
      return detail;
    }

    return 'Cập nhật thông tin thất bại. Vui lòng thử lại.';
  }

  String _extractDetail(DioException e) {
    final data = e.response?.data;

    if (data == null) return '';

    if (data is Map) {
      final detail = data['detail'];

      if (detail == null) return '';

      if (detail is String) {
        return detail.trim();
      }

      if (detail is List) {
        return detail
            .map((item) {
          if (item is Map) {
            final msg = item['msg'];
            if (msg != null) return msg.toString();
          }
          return item.toString();
        })
            .where((item) => item.trim().isNotEmpty)
            .join('. ')
            .trim();
      }

      return detail.toString().trim();
    }

    if (data is String) {
      return data.trim();
    }

    return data.toString().trim();
  }

  bool _looksLikeRawError(String value) {
    final n = value.toLowerCase();

    return n.contains('exception') ||
        n.contains('traceback') ||
        n.contains('sqlalchemy') ||
        n.contains('sqlite') ||
        n.contains('dioexception') ||
        n.contains('null') ||
        n.contains('{') ||
        n.contains('}');
  }

  String _normalize(String input) {
    var s = input.toLowerCase().trim();

    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const without =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], without[i]);
    }

    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }
}