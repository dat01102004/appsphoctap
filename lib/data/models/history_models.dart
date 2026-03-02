class HistoryItem {
  final int id;
  final int userId;
  final String actionType;
  final String inputData;
  final String resultText;
  final String createdAt;

  HistoryItem({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.inputData,
    required this.resultText,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json["id"],
    userId: json["user_id"],
    actionType: json["action_type"] ?? "",
    inputData: json["input_data"] ?? "",
    resultText: json["result_text"] ?? "",
    createdAt: json["created_at"] ?? "",
  );
}