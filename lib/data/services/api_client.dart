import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/api_exception.dart';
import 'storage_service.dart';

class ApiClient {
  final Dio dio;
  final StorageService storage;

  ApiClient(this.storage)
      : dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
    ),
  ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final status = e.response?.statusCode;
          final ra = e.response?.headers.value('Retry-After');
          final retryAfter = int.tryParse(ra ?? "");

          String msg = e.message ?? "Lỗi máy chủ.";
          final data = e.response?.data;
          if (data is Map) {
            msg = (data["detail"] ?? data["message"] ?? msg).toString();
          }

          final apiEx = ApiException(
            message: msg,
            statusCode: status,
            retryAfterSeconds: retryAfter,
          );

          handler.next(e.copyWith(error: apiEx));
        },
      ),
    );
  }
}