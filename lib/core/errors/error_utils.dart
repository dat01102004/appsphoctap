import 'package:dio/dio.dart';
import 'api_exception.dart';

class ErrorUtils {
  static String message(Object e) {
    if (e is DioException) {
      final err = e.error;
      if (err is ApiException) return err.friendlyMessage();
      return e.message ?? "Lỗi mạng/Server.";
    }
    if (e is ApiException) return e.friendlyMessage();
    return e.toString();
  }
}