import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/profile_data.dart';
import '../data/models/user_profile.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_service.dart';
import '../data/services/token_storage.dart';

/// Авторизация: SMS OTP + профиль пользователя.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    Dio? dio,
    TokenStorage? tokenStorage,
  })  : _tokenStorage = tokenStorage ?? TokenStorage.instance,
        _dio = dio ?? DioClient.instance.dio,
        _authService = authService ??
            AuthService(dio ?? DioClient.instance.dio);

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final AuthService _authService;

  UserProfile? currentUser;
  bool isLoading = false;
  String? error;

  bool get isLoggedIn => currentUser != null;

  /// Совместимость с экранами на [HeroUser].
  HeroUser get user {
    final profile = currentUser;
    if (profile == null) return kAnonymousHero;
    final name =
        profile.displayName.isEmpty ? profile.phone : profile.displayName;
    return HeroUser(
      name: name.isEmpty ? 'Герой без имени' : name,
      phone: profile.phone,
    );
  }

  Future<void> init() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final access = await _tokenStorage.readAccess();
      if (access == null || access.isEmpty) {
        currentUser = null;
        return;
      }
      await _loadProfile();
    } catch (e) {
      error = e.toString();
      currentUser = null;
      await _tokenStorage.clearTokens();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendOtp(String phone) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _authService.requestSms(phone);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmOtp(String phone, String code) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await _authService.verifySms(phone, code);
      await _tokenStorage.saveTokens(
        access: result.access,
        refresh: result.refresh,
      );
      await _loadProfile();
      // TODO(fcm): зарегистрировать FCM token после flutterfire configure.
      return isLoggedIn;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final refresh = await _tokenStorage.readRefresh();
      if (refresh != null && refresh.isNotEmpty) {
        await _authService.logout(refresh);
      }
    } catch (_) {
      // Всегда очищаем локальную сессию.
    } finally {
      await _tokenStorage.clearTokens();
      currentUser = null;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateNotificationPreferences({
    bool? events,
    bool? promotions,
    bool? closedEvents,
  }) async {
    if (currentUser == null) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (events != null) body['notify_events'] = events;
      if (promotions != null) body['notify_promotions'] = promotions;
      if (closedEvents != null) body['notify_closed_events'] = closedEvents;

      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/profile/',
        data: body,
      );
      currentUser = UserProfile.fromJson(response.data ?? {});
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/profile/');
    currentUser = UserProfile.fromJson(response.data ?? {});
  }
}
