import '../models/news_models.dart';
import 'api_client.dart';

class NewsApi {
  final ApiClient client;
  NewsApi(this.client);

  Future<List<NewsItem>> top({int limit = 6}) async {
    final res = await client.dio.get("/news/top", queryParameters: {"limit": limit});
    final items = (res.data["items"] as List).map((e) => NewsItem.fromJson(e)).toList();
    return items;
  }

  Future<List<NewsItem>> search(String q, {int limit = 6}) async {
    final res = await client.dio.get("/news/search", queryParameters: {"q": q, "limit": limit});
    final items = (res.data["items"] as List).map((e) => NewsItem.fromJson(e)).toList();
    return items;
  }
}