import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/push_navigation.dart';
import '../../widgets/piligrim_toast.dart';
import 'api_client.dart';

typedef FcmTokenProvider = Future<String?> Function();

/// Ключ в SharedPreferences, под которым кешируется последний известный
/// FCM-токен этого устройства — читается [firebaseMessagingBackgroundHandler]
/// в фоновом изоляте, где недоступен ни FcmService, ни (без лишней
/// переинициализации Firebase) FirebaseMessaging.instance.getToken().
/// RemoteMessage не содержит "свой" токен — это токен ПОЛУЧАТЕЛЯ, а не
/// свойство самого сообщения, поэтому его нужно кешировать заранее.
const _kFcmTokenCacheKey = 'fcm_token_cache';

Future<void> _cacheFcmToken(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFcmTokenCacheKey, token);
  } catch (_) {
    // Не критично — просто не будет fcm_token в фоновых PushReceipt.
  }
}

/// Факт получения push — как наших (через backend), так и пришедших в обход
/// него (Remarked напрямую через Firebase). См. backend/docs/notifications.md.
/// Best-effort: сетевая ошибка/таймаут просто проглатывается — это
/// диагностический лог, а не критичная для пользователя операция, и
/// [firebaseMessagingBackgroundHandler] выполняется в изоляте с очень
/// ограниченным временем на работу.
Future<void> logPushReceipt(
  Dio dio,
  RemoteMessage message, {
  required String context,
  required String? fcmToken,
}) async {
  if (fcmToken == null || fcmToken.isEmpty) return;
  try {
    await dio
        .post<void>(
          '/notifications/push-receipt/',
          data: {
            'fcm_token': fcmToken,
            'title': message.notification?.title ?? '',
            'body': message.notification?.body ?? '',
            'data': message.data.map((k, v) => MapEntry(k, v.toString())),
            'context': context,
          },
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('logPushReceipt($context) failed (ignored): $e');
  }
}

/// Фоновый обработчик FCM — вызывается ОС, когда push пришёл, пока
/// приложение свёрнуто/закрыто, и гость его не тапнул (иначе сработал бы
/// [FirebaseMessaging.onMessageOpenedApp]). Это единственное место, где мы
/// вообще узнаём о таких "тихих" получениях — без него пуши Remarked,
/// пришедшие в фоне и не открытые тапом, были бы совсем не видны.
///
/// ОБЯЗАТЕЛЬНО top-level функция (не метод класса) — плагин вызывает её в
/// отдельном изоляте, где недоступно состояние основного изолята (в т.ч.
/// FcmService.instance). Поэтому здесь не переиспользуется DioClient —
/// собирается собственный минимальный Dio, чтобы не тащить за собой
/// AuthInterceptor/TokenStorage (secure storage в фоновом изоляте на iOS —
/// источник лишних сбоев, а эндпоинт и так публичный, токен ему не нужен).
/// Токен устройства берём из SharedPreferences-кеша, а не через
/// FirebaseMessaging.instance.getToken() — это избавляет от необходимости
/// заново поднимать Firebase.initializeApp() в этом изоляте ради одного поля.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  String? token;
  try {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kFcmTokenCacheKey);
  } catch (_) {
    return;
  }
  final dio = Dio(BaseOptions(baseUrl: DioClient.baseUrlForBackgroundIsolate));
  await logPushReceipt(dio, message, context: 'background', fcmToken: token);
}

/// FCM: permission, foreground snackbar, tap navigation, регистрация на бэке.
class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    FcmTokenProvider? tokenProvider,
    bool useFirebaseMessaging = true,
  })  : _messaging = useFirebaseMessaging
            ? (messaging ?? FirebaseMessaging.instance)
            : messaging,
        _tokenProvider = tokenProvider;

  static final FcmService instance = FcmService();

  /// Для unit-тестов без Firebase.
  factory FcmService.test({FcmTokenProvider? tokenProvider}) {
    return FcmService(
      useFirebaseMessaging: false,
      tokenProvider: tokenProvider,
    );
  }

  final FirebaseMessaging? _messaging;
  final FcmTokenProvider? _tokenProvider;

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Слушатели без системного диалога — можно вызвать до [runApp].
  Future<void> initEarly({GlobalKey<NavigatorState>? navigatorKey}) async {
    final messaging = _messaging;
    if (messaging == null) return;

    _navigatorKey = navigatorKey;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    final initial = await messaging.getInitialMessage().timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    if (initial != null) {
      unawaited(_logReceipt(initial, context: 'opened_app'));
      _handleNavigation(initial.data);
    }

    messaging.onTokenRefresh.listen((_) async {
      await registerTokenWithServer(DioClient.instance.dio);
    });
  }

  /// Диалог разрешений — только после первого кадра UI (не на белом Launch Screen).
  Future<void> requestPermissionIfNeeded() async {
    final messaging = _messaging;
    if (messaging == null) return;
    await messaging.requestPermission();
  }

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    await initEarly(navigatorKey: navigatorKey);
    await requestPermissionIfNeeded();
  }

  Future<String?> getToken() async {
    final provider = _tokenProvider;
    if (provider != null) return provider();
    return _messaging?.getToken();
  }

  Future<void> registerTokenWithServer(Dio dio) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;
    unawaited(_cacheFcmToken(token));
    await dio.post<Map<String, dynamic>>(
      '/notifications/device/register/',
      data: {'fcm_token': token},
    );
  }

  Future<void> _logReceipt(RemoteMessage message, {required String context}) async {
    final token = await getToken();
    await logPushReceipt(DioClient.instance.dio, message, context: context, fcmToken: token);
  }

  void _onForegroundMessage(RemoteMessage message) {
    unawaited(_logReceipt(message, context: 'foreground'));

    final title = message.notification?.title ?? 'PILIGRIM';
    final body = message.notification?.body ?? '';
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;

    PiligrimToast.show(
      ctx,
      body.isEmpty ? title : '$title\n$body',
      duration: const Duration(seconds: 4),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    unawaited(_logReceipt(message, context: 'opened_app'));
    _handleNavigation(message.data);
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;
    PushNavigationHandler.onPushType?.call(type);
  }
}
