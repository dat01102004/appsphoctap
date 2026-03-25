import '../models/auth_models.dart';
import 'api_client.dart';

class AuthApi {
  final ApiClient client;

  AuthApi(this.client);

  Future<AuthTokenResponse> login(String email, String password) async {
    final res = await client.dio.post(
      "/auth/login",
      data: {
        "email": email,
        "password": password,
      },
    );
    return AuthTokenResponse.fromJson(res.data);
  }

  Future<AuthTokenResponse> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await client.dio.post(
      "/auth/register",
      data: {
        "full_name": fullName,
        "email": email,
        "phone": phone,
        "password": password,
      },
    );
    return AuthTokenResponse.fromJson(res.data);
  }

  Future<MeResponse> me() async {
    final res = await client.dio.get("/me");
    return MeResponse.fromJson(res.data);
  }
}