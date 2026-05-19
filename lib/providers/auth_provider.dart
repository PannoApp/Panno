import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/dio_errors.dart';
import '../core/profile_data.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/profile_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_service.dart';
import '../data/services/fcm_service.dart';
import '../data/services/token_storage.dart';

/// Авторизация: SMS OTP + профиль пользователя.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    Dio? dio,
    TokenStorage? tokenStorage,
    ProfileRepository? profileRepository,
  })  : _tokenStorage = tokenStorage ?? TokenStorage.instance,
        _dio = dio ?? DioClient.instance.dio,
        _authService = authService ??
            AuthService(dio ?? DioClient.instance.dio),
        _profileRepository = profileRepository ??
            ProfileRepository(dio: dio ?? DioClient.instance.dio);

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final AuthService _authService;
  final ProfileRepository _profileRepository;

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
      await _registerFcmIfPossible();
    } catch (e) {
      error = dioErrorMessage(e);
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
      error = dioErrorMessage(e);
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
      await _registerFcmIfPossible();
      return isLoggedIn;
    } catch (e) {
      error = dioErrorMessage(e);
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

      currentUser = await _profileRepository.updateProfile(body);
    } catch (e) {
      error = dioErrorMessage(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    currentUser = await _profileRepository.fetchProfile();
  }

  Future<void> _registerFcmIfPossible() async {
    if (!isLoggedIn) return;
    try {
      await FcmService.instance.registerTokenWithServer(_dio);
    } catch (_) {
      // FCM опционален до полной настройки Firebase.
    }
  }
}
