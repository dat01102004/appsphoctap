class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final int? retryAfterSeconds;

  ApiException({
    required this.message,
    this.statusCode,
    this.retryAfterSeconds,
  });

  String friendlyMessage() {
    if (statusCode == 429 || statusCode == 503) {
      if (retryAfterSeconds != null && retryAfterSeconds! > 0) {
        return "Gemini đang quá tải, thử lại sau ${retryAfterSeconds}s.";
      }
      return "Gemini đang quá tải, vui lòng thử lại sau.";
    }
    return message;
  }

  @override
  String toString() => "ApiException($statusCode): $message";
}