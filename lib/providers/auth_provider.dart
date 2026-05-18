import 'package:flutter/foundation.dart';

import '../core/profile_data.dart';
import '../data/api_client.dart';
import '../data/models/user_profile.dart';
import '../data/services/auth_service.dart';
import '../data/token_storage.dart';

/// Авторизация: SMS OTP + профиль пользователя.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? SharedPreferencesTokenStorage() {
    _apiClient = apiClient ??
        ApiClient(baseUrl: ApiConfig.baseUrl, tokenStorage: _tokenStorage);
    _authService = authService ?? AuthService(_apiClient);
  }

  final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthService _authService;

  UserProfile? currentUser;
  bool isLoading = false;
  String? error;

  bool get isLoggedIn => currentUser != null;

  /// Совместимость с экранами на [HeroUser].
  HeroUser get user {
    final profile = currentUser;
    if (profile == null) return kAnonymousHero;
    final name = profile.displayName.isEmpty ? profile.phone : profile.displayName;
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
      final access = await _tokenStorage.getAccessToken();
      if (access == null || access.isEmpty) {
        currentUser = null;
        return;
      }
      await _loadProfile();
    } catch (e) {
      error = e.toString();
      currentUser = null;
      await _tokenStorage.clear();
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
      // TODO(fcm): зарегистрировать FCM token после появления FcmService.
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
      final refresh = await _tokenStorage.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _authService.logout(refresh);
      }
    } catch (_) {
      // Всегда очищаем локальную сессию.
    } finally {
      await _tokenStorage.clear();
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

      final json = await _apiClient.patch('/users/profile/', body: body);
      currentUser = UserProfile.fromJson(json);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    final json = await _apiClient.get('/users/profile/');
    currentUser = UserProfile.fromJson(json);
  }
}
