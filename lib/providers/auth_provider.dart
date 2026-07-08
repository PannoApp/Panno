import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/dio_errors.dart';
import '../core/profile_data.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/event_reservation_repository.dart';
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
    EventReservationRepository? eventReservationRepository,
  })  : _tokenStorage = tokenStorage ?? TokenStorage.instance,
        _dio = dio ?? DioClient.instance.dio,
        _authService = authService ??
            AuthService(dio ?? DioClient.instance.dio),
        _profileRepository = profileRepository ??
            ProfileRepository(dio: dio ?? DioClient.instance.dio),
        _eventReservationRepository = eventReservationRepository ??
            EventReservationRepository(dio: dio ?? DioClient.instance.dio);

  final TokenStorage _tokenStorage;
  final Dio _dio;
  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final EventReservationRepository _eventReservationRepository;

  UserProfile? currentUser;
  bool isLoading = false;
  String? error;
  bool isNewUser = false;
  int eventsCount = 0;

  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  /// Совместимость с экранами на [HeroUser].
  HeroUser get user {
    final profile = currentUser;
    if (profile == null) return kAnonymousHero;
    final name =
        profile.displayName.isEmpty ? profile.phone : profile.displayName;
    final journey = _formatJourneyStart(profile.dateJoined);
    return HeroUser(
      name: name.isEmpty ? 'Герой без имени' : name,
      phone: profile.phone,
      journeyStartValue: journey.$1,
      journeyStartLabel: journey.$2,
      eventsCount: eventsCount,
    );
  }

  void clearNewUserFlag() {
    isNewUser = false;
    notifyListeners();
  }

  Future<void> init() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final access = await _tokenStorage.readAccess();
      if (access == null || access.isEmpty) {
        currentUser = null;
        eventsCount = 0;
        return;
      }
      await _loadProfile();
      await _loadEventsCount();
      await _registerFcmIfPossible();
    } catch (e) {
      error = dioErrorMessage(e);
      currentUser = null;
      eventsCount = 0;
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
      isNewUser = result.isNewUser;
      await _tokenStorage.saveTokens(
        access: result.access,
        refresh: result.refresh,
      );
      await _loadProfile();
      await _loadEventsCount();
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
    // Читаем refresh-токен ДО очистки, чтобы уведомить сервер.
    final refresh = await _tokenStorage.readRefresh();

    // Немедленно очищаем локальную сессию — не ждём сервер.
    await _tokenStorage.clearTokens();
    currentUser = null;
    isNewUser = false;
    eventsCount = 0;
    notifyListeners();

    // Уведомляем сервер в фоне — UI уже обновился.
    if (refresh != null && refresh.isNotEmpty) {
      _authService.logout(refresh).catchError((_) {});
    }
  }

  /// Удаляет аккаунт на сервере, затем очищает локальную сессию.
  Future<void> deleteAccount() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _authService.deleteAccount();
      await _tokenStorage.clearTokens();
      currentUser = null;
      isNewUser = false;
      eventsCount = 0;
    } catch (e) {
      error = dioErrorMessage(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateName(String firstName) async {
    if (currentUser == null) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      currentUser = await _profileRepository.updateProfile({'first_name': firstName});
    } catch (e) {
      error = dioErrorMessage(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Обновляет анкетные данные (имя, фамилия, пол, email, дата рождения)
  /// одним PATCH-запросом. Каждое поле необязательно — передавай только то,
  /// что реально изменилось.
  Future<void> updateDisplayProfile({
    String? firstName,
    String? lastName,
    UserGender? gender,
    String? email,
    DateTime? birthday,
  }) async {
    if (currentUser == null) return;
    final body = <String, dynamic>{};
    if (firstName != null && firstName.isNotEmpty) body['first_name'] = firstName;
    if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;
    if (gender != null) body['gender'] = gender.toJsonValue();
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (birthday != null) body['birthday'] = formatDateOnly(birthday);
    if (body.isEmpty) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      currentUser = await _profileRepository.updateProfile(body);
    } catch (e) {
      error = dioErrorMessage(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateNotificationPreferences({
    bool? events,
    bool? promotions,
    bool? closedEvents,
    bool? notificationsEnabled,
  }) async {
    if (currentUser == null) return;

    final previous = currentUser!;
    error = null;

    // Optimistic update — UI reacts immediately, no network wait
    currentUser = previous.copyWith(
      notifyEvents: events,
      notifyPromotions: promotions,
      notifyClosedEvents: closedEvents,
      notificationsEnabled: notificationsEnabled,
    );
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (events != null) body['notify_events'] = events;
      if (promotions != null) body['notify_promotions'] = promotions;
      if (closedEvents != null) body['notify_closed_events'] = closedEvents;
      if (notificationsEnabled != null) {
        body['notifications_enabled'] = notificationsEnabled;
      }

      currentUser = await _profileRepository.updateProfile(body);
    } catch (e) {
      currentUser = previous;
      error = dioErrorMessage(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    currentUser = await _profileRepository.fetchProfile();
  }

  Future<void> _loadEventsCount() async {
    if (!isLoggedIn) {
      eventsCount = 0;
      return;
    }
    try {
      eventsCount = await _eventReservationRepository.fetchMyReservationsCount();
    } catch (_) {
      eventsCount = 0;
    }
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

(String, String) _formatJourneyStart(DateTime? dt) {
  final date = dt ?? DateTime.now();
  final now = DateTime.now();

  final totalDays = now.difference(date).inDays;

  final years = now.year - date.year - (now.month < date.month || (now.month == date.month && now.day < date.day) ? 1 : 0);
  if (years >= 1) {
    if (years == 1) return ('1', 'Год с нами');
    if (years <= 4) return ('$years', 'Года с нами');
    return ('$years', 'Лет с нами');
  }

  final months = now.month - date.month + (now.year - date.year) * 12 - (now.day < date.day ? 1 : 0);
  if (months >= 1) {
    if (months == 1) return ('1', 'Месяц с нами');
    if (months <= 4) return ('$months', 'Месяца с нами');
    return ('$months', 'Месяцев с нами');
  }

  if (totalDays == 1) return ('1', 'День с нами');
  if (totalDays >= 2 && totalDays <= 4) return ('$totalDays', 'Дня с нами');
  return ('$totalDays', 'Дней с нами');
}
