import '../../core/constants/api_constants.dart';

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

  factory HistoryItem.fromJson(Map json) => HistoryItem(
    id: json["id"] ?? 0,
    userId: json["user_id"] ?? 0,
    actionType: (json["action_type"] ?? "").toString(),
    inputData: (json["input_data"] ?? "").toString(),
    resultText: (json["result_text"] ?? "").toString(),
    createdAt: (json["created_at"] ?? "").toString(),
  );

  bool get isImageBased => actionType == 'ocr' || actionType == 'caption';

  bool get isReadUrl => actionType == 'read_url';

  String get typeLabel {
    switch (actionType) {
      case 'ocr':
        return 'Quét chữ';
      case 'caption':
        return 'Mô tả ảnh';
      case 'read_url':
        return 'Đọc báo';
      default:
        return 'Lịch sử';
    }
  }

  String get detailTitle {
    switch (actionType) {
      case 'ocr':
        return 'Kết quả OCR đã lưu';
      case 'caption':
        return 'Mô tả ảnh đã lưu';
      case 'read_url':
        return 'Bài báo đã lưu';
      default:
        return 'Chi tiết lịch sử';
    }
  }

  String? get normalizedUploadPath => _normalizeUploadPath(inputData);

  String? get imageUrl {
    if (!isImageBased) return null;
    final path = normalizedUploadPath;
    if (path == null || path.isEmpty) return null;
    return '${ApiConstants.baseUrl}/${Uri.encodeFull(path)}';
  }

  String get inputDisplayText {
    if (isImageBased) {
      return normalizedUploadPath ?? inputData.trim();
    }
    return inputData.trim();
  }

  static String? _normalizeUploadPath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll('\\', '/');

    final lower = value.toLowerCase();
    final uploadIndex = lower.indexOf('uploads/');
    if (uploadIndex >= 0) {
      value = value.substring(uploadIndex);
    }

    while (value.startsWith('/')) {
      value = value.substring(1);
    }

    if (!value.toLowerCase().startsWith('uploads/')) {
      return null;
    }

    return value;
  }
}