class AuthTokenResponse {
  final int userId;
  final String accessToken;
  final String tokenType;

  AuthTokenResponse({required this.userId, required this.accessToken, required this.tokenType});

  factory AuthTokenResponse.fromJson(Map<String, dynamic> json) => AuthTokenResponse(
    userId: json["user_id"],
    accessToken: json["access_token"],
    tokenType: json["token_type"] ?? "bearer",
  );
}

class MeResponse {
  final int id;
  final String email;

  MeResponse({required this.id, required this.email});

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
    id: json["id"],
    email: json["email"] ?? "",
  );
}