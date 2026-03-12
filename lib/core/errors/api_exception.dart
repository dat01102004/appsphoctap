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
    if (statusCode == 429) {
      if (retryAfterSeconds != null && retryAfterSeconds! > 0) {
        return 'Bạn đang gửi quá nhiều yêu cầu, vui lòng thử lại sau ${retryAfterSeconds}s.';
      }
      return 'Bạn đang gửi quá nhiều yêu cầu, vui lòng thử lại sau.';
    }

    if (statusCode == 503) {
      if (retryAfterSeconds != null && retryAfterSeconds! > 0) {
        return 'Dịch vụ AI đang bận, vui lòng thử lại sau ${retryAfterSeconds}s.';
      }
      return 'Dịch vụ AI đang bận, vui lòng thử lại sau.';
    }

    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
