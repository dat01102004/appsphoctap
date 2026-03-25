class AuthTokenResponse {
  final int userId;
  final String accessToken;
  final String tokenType;

  AuthTokenResponse({
    required this.userId,
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthTokenResponse.fromJson(Map json) => AuthTokenResponse(
    userId: json["user_id"] ?? 0,
    accessToken: json["access_token"] ?? "",
    tokenType: json["token_type"] ?? "bearer",
  );
}

class MeResponse {
  final int id;
  final String email;
  final String? fullName;
  final String? phone;
  final DateTime? createdAt;

  MeResponse({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.createdAt,
  });

  factory MeResponse.fromJson(Map json) => MeResponse(
    id: json["id"] ?? 0,
    email: json["email"] ?? "",
    fullName: json["full_name"],
    phone: json["phone"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.tryParse(json["created_at"].toString()),
  );
}