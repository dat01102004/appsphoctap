import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiClient {
  final Dio dio;
  final StorageService storage;

  ApiClient(this.storage)
      : dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 90),
  )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        handler.next(options);
      },
    ));
  }
}