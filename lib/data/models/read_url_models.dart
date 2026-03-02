class ReadUrlResponse {
  final String? title;
  final String text;
  final String? ttsText;
  final String? summary;
  final String? summaryTts;
  final int? historyId;

  ReadUrlResponse({
    required this.title,
    required this.text,
    required this.ttsText,
    required this.summary,
    required this.summaryTts,
    required this.historyId,
  });

  factory ReadUrlResponse.fromJson(Map<String, dynamic> json) => ReadUrlResponse(
    title: json["title"],
    text: json["text"] ?? "",
    ttsText: json["tts_text"],
    summary: json["summary"],
    summaryTts: json["summary_tts"],
    historyId: json["history_id"],
  );
}