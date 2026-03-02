import '../models/read_url_models.dart';
import 'api_client.dart';

class ReadApi {
  final ApiClient client;
  ReadApi(this.client);

  Future<ReadUrlResponse> readUrl(String url, {bool summary = true}) async {
    final res = await client.dio.post("/read/url", data: {"url": url, "summary": summary});
    return ReadUrlResponse.fromJson(res.data);
  }
}