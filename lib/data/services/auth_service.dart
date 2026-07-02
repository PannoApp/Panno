import 'package:dio/dio.dart';

import '../models/json_utils.dart';

/// SMS-авторизация через [Dio] (Блок 1: DioClient).
class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<void> requestSms(String phone) async {
    await _dio.post<Map<String, dynamic>>(
      '/users/auth/request-sms/',
      data: {'phone': phone},
    );
  }

  Future<({String access, String refresh, bool isNewUser})> verifySms(
    String phone,
    String code,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/auth/verify-sms/',
      data: {'phone': phone, 'otp': code},
    );
    final json = response.data ?? {};
    return (
      access: parseString(json['access'] ?? json['access_token'], field: 'access'),
      refresh: parseString(json['refresh'] ?? json['refresh_token'], field: 'refresh'),
      isNewUser: parseBool(json['is_new_user'] ?? json['isNewUser']),
    );
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<Map<String, dynamic>>(
      '/users/auth/logout/',
      data: {'refresh': refreshToken},
    );
  }
}
