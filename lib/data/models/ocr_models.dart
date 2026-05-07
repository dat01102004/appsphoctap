class OcrResponse {
  final String text;
  final int? historyId;
  final bool deduplicated;
  final bool savedToHistory;
  final String? matchType;

  OcrResponse({
    required this.text,
    this.historyId,
    this.deduplicated = false,
    this.savedToHistory = false,
    this.matchType,
  });

  factory OcrResponse.fromJson(Map json) => OcrResponse(
    text: (json["text"] ?? "").toString(),
    historyId: json["history_id"],
    deduplicated: json["deduplicated"] == true,
    savedToHistory: json["saved_to_history"] == true,
    matchType: json["match_type"]?.toString(),
  );
}

class CaptionResponse {
  final String caption;
  final int? historyId;
  final bool deduplicated;
  final bool savedToHistory;
  final String? matchType;

  CaptionResponse({
    required this.caption,
    this.historyId,
    this.deduplicated = false,
    this.savedToHistory = false,
    this.matchType,
  });

  factory CaptionResponse.fromJson(Map json) => CaptionResponse(
    caption: (json["caption"] ?? "").toString(),
    historyId: json["history_id"],
    deduplicated: json["deduplicated"] == true,
    savedToHistory: json["saved_to_history"] == true,
    matchType: json["match_type"]?.toString(),
  );
}