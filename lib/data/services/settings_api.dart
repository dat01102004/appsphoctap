import '../models/settings_model.dart';
import 'api_client.dart';

class SettingsApi {
  final ApiClient client;

  SettingsApi(this.client);

  Future<SettingsModel> me() async {
    final res = await client.dio.get('/settings/me');
    return SettingsModel.fromJson(res.data);
  }

  Future<SettingsModel> updateMe(SettingsModel settings) async {
    final res = await client.dio.put('/settings/me', data: settings.toJson());
    return SettingsModel.fromJson(res.data);
  }
}
