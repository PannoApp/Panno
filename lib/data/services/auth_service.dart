import '../api_client.dart';
import '../models/json_utils.dart';

/// SMS-авторизация через [ApiClient].
class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<void> requestSms(String phone) async {
    await _client.post(
      '/auth/request-sms/',
      body: {'phone': phone},
      authenticated: false,
    );
  }

  Future<({String access, String refresh, bool isNewUser})> verifySms(
    String phone,
    String code,
  ) async {
    final json = await _client.post(
      '/auth/verify-sms/',
      body: {'phone': phone, 'code': code},
      authenticated: false,
    );
    return (
      access: parseString(json['access'] ?? json['access_token'], field: 'access'),
      refresh: parseString(json['refresh'] ?? json['refresh_token'], field: 'refresh'),
      isNewUser: parseBool(json['is_new_user'] ?? json['isNewUser']),
    );
  }

  Future<void> logout(String refreshToken) async {
    await _client.post(
      '/auth/logout/',
      body: {'refresh': refreshToken},
      authenticated: true,
    );
  }
}
