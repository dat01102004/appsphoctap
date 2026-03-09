class NewsArticlePayload {
  final String title;
  final String url;
  final String summary;
  final String? source;
  final String? published;

  const NewsArticlePayload({
    required this.title,
    required this.url,
    required this.summary,
    this.source,
    this.published,
  });
}