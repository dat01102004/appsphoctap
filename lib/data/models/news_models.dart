class NewsItem {
  final String title;
  final String link;
  final String? source;
  final String? published;

  NewsItem({
    required this.title,
    required this.link,
    this.source,
    this.published,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    title: (json["title"] ?? "").toString(),
    link: (json["link"] ?? "").toString(),
    source: json["source"]?.toString(),
    published: json["published"]?.toString(),
  );
}