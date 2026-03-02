class OcrResponse {
  final String text;
  final int? historyId;
  OcrResponse({required this.text, this.historyId});

  factory OcrResponse.fromJson(Map<String, dynamic> json) => OcrResponse(
    text: json["text"] ?? "",
    historyId: json["history_id"],
  );
}

class CaptionResponse {
  final String caption;
  final int? historyId;
  CaptionResponse({required this.caption, this.historyId});

  factory CaptionResponse.fromJson(Map<String, dynamic> json) => CaptionResponse(
    caption: json["caption"] ?? "",
    historyId: json["history_id"],
  );
}