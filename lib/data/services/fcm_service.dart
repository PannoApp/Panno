import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/push_navigation.dart';
import '../../core/theme.dart';
import 'api_client.dart';

typedef FcmTokenProvider = Future<String?> Function();

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

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    final messaging = _messaging;
    if (messaging == null) return;

    _navigatorKey = navigatorKey;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleNavigation(initial.data);
    }

    messaging.onTokenRefresh.listen((_) async {
      await registerTokenWithServer(DioClient.instance.dio);
    });
  }

  Future<String?> getToken() async {
    final provider = _tokenProvider;
    if (provider != null) return provider();
    return _messaging?.getToken();
  }

  Future<void> registerTokenWithServer(Dio dio) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;
    await dio.post<Map<String, dynamic>>(
      '/notifications/device/register/',
      data: {'fcm_token': token},
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'PILIGRIM';
    final body = message.notification?.body ?? '';
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        backgroundColor: PiligrimColors.earthDeep,
        content: Text(
          body.isEmpty ? title : '$title\n$body',
          style: PiligrimTextStyles.body.copyWith(
            fontSize: 13,
            color: PiligrimColors.sky,
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleNavigation(message.data);
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;
    PushNavigationHandler.onPushType?.call(type);
  }
}
