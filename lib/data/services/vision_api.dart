import 'package:dio/dio.dart';

import '../models/ocr_models.dart';
import 'api_client.dart';

class VisionApi {
  final ApiClient client;

  VisionApi(this.client);

  Future<OcrResponse> ocr(String filePath) async {
    final form = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
    });

    final res = await client.dio.post("/ocr", data: form);
    return OcrResponse.fromJson(res.data);
  }

  Future<CaptionResponse> caption(String filePath) async {
    final form = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
    });

    final res = await client.dio.post("/caption", data: form);
    return CaptionResponse.fromJson(res.data);
  }

  Future<OcrResponse> ocrLive(String filePath) async {
    final form = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
    });

    final res = await client.dio.post(
      "/ocr",
      data: form,
      queryParameters: {
        "save_history": false,
      },
    );

    return OcrResponse.fromJson(res.data);
  }

  Future<CaptionResponse> captionLive(String filePath) async {
    final form = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
    });

    final res = await client.dio.post(
      "/caption",
      data: form,
      queryParameters: {
        "save_history": false,
      },
    );

    return CaptionResponse.fromJson(res.data);
  }
}