import 'package:dio/dio.dart';

import '../models/ocr_models.dart';
import 'api_client.dart';

class VisionApi {
  final ApiClient client;

  VisionApi(this.client);

  Future<OcrResponse> ocr(
      String filePath, {
        CancelToken? cancelToken,
      }) async {
    final form = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
    });

    final res = await client.dio.post(
      "/ocr",
      data: form,
      cancelToken: cancelToken,
    );

    return OcrResponse.fromJson(res.data);
  }

  Future<CaptionResponse> caption(
      String filePath, {
        CancelToken? cancelToken,
      }) async {
    final form = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
    });

    final res = await client.dio.post(
      "/caption",
      data: form,
      cancelToken: cancelToken,
    );

    return CaptionResponse.fromJson(res.data);
  }
}