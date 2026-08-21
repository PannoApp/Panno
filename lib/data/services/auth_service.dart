import 'package:dio/dio.dart';

import '../models/json_utils.dart';
import '../models/user_profile.dart' show formatDateOnly;

/// Авторизация через [Dio] (Блок 1: DioClient). Основной флоу — вход/
/// регистрация по номеру участника лояльности (loyaltyLogin/loyaltyRegister);
/// requestSms/verifySms оставлены нетронутыми на бэкенде, но из UI больше не
/// вызываются (см. docs/piligrim_improvements_plan.md, Фаза D).
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

  /// Вход по номеру телефона + номеру участника лояльности
  /// (POST /users/auth/loyalty-login/) — только для гостей, уже
  /// существующих в Remarked. Бросает [DioException] с ответом 400/404/503
  /// при ошибке — обрабатывается в AuthProvider.
  Future<({String access, String refresh, bool isNewUser})> loyaltyLogin(
    String phone,
    String memberNumber,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/auth/loyalty-login/',
      data: {'phone': phone, 'member_number': memberNumber},
    );
    final json = response.data ?? {};
    return (
      access: parseString(json['access'], field: 'access'),
      refresh: parseString(json['refresh'], field: 'refresh'),
      isNewUser: parseBool(json['is_new_user'] ?? json['isNewUser']),
    );
  }

  /// Регистрация нового гостя лояльности (POST /users/auth/loyalty-register/).
  /// Remarked присваивает номер участника синхронно при создании — сервер
  /// возвращает его в `member_number`, чтобы показать гостю сразу.
  Future<({String access, String refresh, String? memberNumber})> loyaltyRegister({
    required String phone,
    required String firstName,
    String? lastName,
    DateTime? birthday,
    String gender = 'not_specified',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/auth/loyalty-register/',
      data: {
        'phone': phone,
        'first_name': firstName,
        if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
        if (birthday != null) 'birthday': formatDateOnly(birthday),
        'gender': gender,
      },
    );
    final json = response.data ?? {};
    return (
      access: parseString(json['access'], field: 'access'),
      refresh: parseString(json['refresh'], field: 'refresh'),
      memberNumber: parseStringOrNull(json['member_number']),
    );
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<Map<String, dynamic>>(
      '/users/auth/logout/',
      data: {'refresh': refreshToken},
    );
  }

  /// Безвозвратное удаление аккаунта (DELETE /users/account/).
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/users/account/');
  }
}
