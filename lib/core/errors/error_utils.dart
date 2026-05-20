import 'package:dio/dio.dart';

import 'api_exception.dart';

class FriendlyError implements Exception {
  final String message;

  const FriendlyError(this.message);

  @override
  String toString() => message;
}

class ErrorUtils {
  static String message(Object error, {String feature = 'general'}) {
    return friendlyApiMessage(error, feature: feature);
  }
}

String friendlyApiMessage(Object error, {String feature = 'general'}) {
  if (error is FriendlyError) return error.message;

  if (error is ApiException) {
    return _messageFromStatus(
      error.statusCode,
      feature: feature,
      detail: error.message,
      retryAfterSeconds: error.retryAfterSeconds,
    );
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Kết nối hơi chậm. Bạn thử lại sau nhé.';
      case DioExceptionType.connectionError:
        return 'Không kết nối được máy chủ. Bạn kiểm tra mạng rồi thử lại nhé.';
      case DioExceptionType.badCertificate:
        return 'Kết nối chưa an toàn. Bạn thử lại sau nhé.';
      case DioExceptionType.cancel:
        return 'Yêu cầu đã được hủy.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final apiError = error.error;
    if (apiError is ApiException) {
      return _messageFromStatus(
        apiError.statusCode ?? error.response?.statusCode,
        feature: feature,
        detail: apiError.message,
        retryAfterSeconds: apiError.retryAfterSeconds,
      );
    }

    return _messageFromStatus(
      error.response?.statusCode,
      feature: feature,
      detail: extractApiDetail(error),
    );
  }

  if (error is FormatException) {
    return _defaultFeatureMessage(feature);
  }

  final value = error.toString().trim();
  if (value.isNotEmpty && !looksLikeRawError(value)) {
    return value;
  }

  return _defaultFeatureMessage(feature);
}

String extractApiDetail(DioException e) {
  final data = e.response?.data;
  if (data == null) return '';

  if (data is Map) {
    final detail = data['detail'] ?? data['message'] ?? data['error'];
    return _stringifyDetail(detail);
  }

  if (data is String) return data.trim();

  return data.toString().trim();
}

bool looksLikeRawError(String value) {
  final n = value.toLowerCase().trim();
  if (n.isEmpty || n == 'null') return true;

  return n.contains('exception') ||
      n.contains('traceback') ||
      n.contains('sqlalchemy') ||
      n.contains('sqlite') ||
      n.contains('dioexception') ||
      n.contains('http exception') ||
      n.contains('internal server error') ||
      n.contains('service unavailable') ||
      n.contains('xmlhttprequest') ||
      n.contains('socketexception') ||
      n.contains('connection refused') ||
      n.contains('connection reset') ||
      n.contains('failed host lookup') ||
      (n.startsWith('{') && n.endsWith('}')) ||
      (n.startsWith('[') && n.endsWith(']'));
}

String _messageFromStatus(
  int? statusCode, {
  required String feature,
  String? detail,
  int? retryAfterSeconds,
}) {
  final cleanDetail = (detail ?? '').trim();
  if (cleanDetail.isNotEmpty && !looksLikeRawError(cleanDetail)) {
    final mappedDetail = _messageFromDetail(cleanDetail, feature: feature);
    if (mappedDetail != null) return mappedDetail;

    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return cleanDetail;
    }
  }

  switch (statusCode) {
    case 400:
      return _badRequestMessage(feature);
    case 401:
    case 403:
      if (feature == 'auth_login' || feature == 'auth') {
        return 'Email hoặc mật khẩu chưa đúng. Vui lòng kiểm tra lại.';
      }
      return 'Phiên đăng nhập đã hết hạn. Bạn đăng nhập lại nhé.';
    case 404:
      if (feature == 'read_url') {
        return 'Không tìm thấy bài viết này. Bạn thử đường dẫn khác nhé.';
      }
      if (feature == 'news') {
        return 'Không tìm thấy nội dung cần đọc. Bạn thử bài khác nhé.';
      }
      return 'Không tìm thấy dữ liệu này.';
    case 409:
      return _conflictMessage(feature, cleanDetail);
    case 413:
      return 'Ảnh hoặc dữ liệu quá lớn. Bạn thử ảnh nhỏ hơn nhé.';
    case 422:
      if (feature.startsWith('auth')) {
        return 'Thông tin chưa đúng định dạng. Bạn kiểm tra lại nhé.';
      }
      if (feature == 'read_url') {
        return 'Đường dẫn chưa hợp lệ. Bạn kiểm tra lại URL nhé.';
      }
      return 'Thông tin nhập vào chưa đúng. Bạn kiểm tra lại nhé.';
    case 429:
      if (retryAfterSeconds != null && retryAfterSeconds > 0) {
        return 'Hệ thống đang dùng quá nhiều lượt. Bạn chờ $retryAfterSeconds giây rồi thử lại nhé.';
      }
      return 'Hệ thống đang dùng quá nhiều lượt. Bạn chờ một chút rồi thử lại nhé.';
    case 500:
      if (feature == 'ocr') {
        return 'Mình chưa đọc được ảnh này. Bạn đưa camera gần hơn một chút hoặc chụp lại rõ hơn nhé.';
      }
      if (feature == 'caption') {
        return 'Mình chưa mô tả được ảnh này. Bạn thử chụp lại rõ hơn nhé.';
      }
      return 'Máy chủ đang gặp lỗi. Bạn thử lại sau nhé.';
    case 502:
    case 503:
    case 504:
      return 'Máy chủ đang bận. Bạn thử lại sau nhé.';
  }

  return _defaultFeatureMessage(feature);
}

String? _messageFromDetail(String detail, {required String feature}) {
  final n = _normalize(detail);

  if (feature == 'auth_login' &&
      (n.contains('mat khau') ||
          n.contains('password') ||
          n.contains('credential') ||
          n.contains('unauthorized'))) {
    return 'Email hoặc mật khẩu chưa đúng. Vui lòng kiểm tra lại.';
  }

  if (feature.startsWith('auth') && n.contains('email')) {
    if (n.contains('dang ky') ||
        n.contains('ton tai') ||
        n.contains('exist') ||
        n.contains('registered') ||
        n.contains('duplicate')) {
      return 'Email này đã được đăng ký. Bạn có thể đăng nhập.';
    }
  }

  if (feature.startsWith('auth') &&
      (n.contains('phone') ||
          n.contains('so dien thoai') ||
          n.contains('sdt'))) {
    if (n.contains('dang ky') ||
        n.contains('ton tai') ||
        n.contains('exist') ||
        n.contains('registered') ||
        n.contains('duplicate')) {
      return 'Số điện thoại này đã được đăng ký. Bạn hãy dùng số khác.';
    }
  }

  return null;
}

String _badRequestMessage(String feature) {
  switch (feature) {
    case 'ocr':
    case 'caption':
      return 'Ảnh chưa hợp lệ. Bạn thử chụp lại rõ hơn nhé.';
    case 'read_url':
    case 'news':
      return 'Đường dẫn hoặc yêu cầu chưa hợp lệ. Bạn kiểm tra lại nhé.';
    default:
      return 'Thông tin gửi lên chưa hợp lệ. Bạn kiểm tra lại nhé.';
  }
}

String _conflictMessage(String feature, String detail) {
  final n = _normalize(detail);
  if (feature.startsWith('auth')) {
    if (n.contains('email')) {
      return 'Email này đã được đăng ký. Bạn có thể đăng nhập.';
    }
    if (n.contains('phone') ||
        n.contains('so dien thoai') ||
        n.contains('sdt')) {
      return 'Số điện thoại này đã được đăng ký. Bạn hãy dùng số khác.';
    }
  }
  return 'Thông tin này đã tồn tại.';
}

String _defaultFeatureMessage(String feature) {
  switch (feature) {
    case 'ocr':
      return 'Mình chưa đọc được ảnh này. Bạn đưa camera gần hơn một chút hoặc chụp lại rõ hơn nhé.';
    case 'caption':
      return 'Mình chưa mô tả được ảnh này. Bạn thử chụp lại rõ hơn nhé.';
    case 'read_url':
      return 'Không đọc được bài viết này. Bạn thử đường dẫn khác nhé.';
    case 'news_list':
      return 'Mình chưa tải được tin mới. Bạn thử lại sau nhé.';
    case 'news_search':
      return 'Mình chưa tìm được tin theo chủ đề này. Bạn thử chủ đề khác nhé.';
    case 'news_read':
      return 'Mình chưa đọc được bài này. Bạn thử bài khác nhé.';
    case 'news':
      return 'Mạng đang không ổn định. Bạn kiểm tra kết nối rồi thử lại nhé.';
    case 'auth_login':
      return 'Email hoặc mật khẩu chưa đúng. Vui lòng kiểm tra lại.';
    case 'auth_register':
      return 'Đăng ký thất bại. Bạn kiểm tra lại thông tin rồi thử lại nhé.';
    case 'auth':
      return 'Không xử lý được tài khoản lúc này. Bạn thử lại sau nhé.';
    default:
      return 'Có lỗi xảy ra. Bạn thử lại sau nhé.';
  }
}

String _stringifyDetail(Object? detail) {
  if (detail == null) return '';

  if (detail is String) return detail.trim();

  if (detail is List) {
    return detail
        .map((item) {
          if (item is Map) {
            final msg = item['msg'] ?? item['message'] ?? item['detail'];
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
