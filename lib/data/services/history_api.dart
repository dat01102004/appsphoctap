import '../models/history_models.dart';
import 'api_client.dart';

class HistoryApi {
  final ApiClient client;
  HistoryApi(this.client);

  Future<List<HistoryItem>> list({String? type, int limit = 50}) async {
    final res = await client.dio.get(
      "/history",
      queryParameters: {
        if (type != null) "type": type,
        "limit": limit,
      },
    );

    final items = (res.data["items"] as List)
        .map((e) => HistoryItem.fromJson(e))
        .toList();

    return items;
  }

  Future<void> delete(int id) async {
    await client.dio.delete("/history/$id");
  }
}