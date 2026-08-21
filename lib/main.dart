// Точка входа приложения PILIGRIM
// Тема: piligrim_design_spec.md — тёмная тема, цвета Қара жер / Мөлдір су / Сары дала
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/ambient_preset_scope.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'core/piligrim_route.dart';
import 'core/push_navigation.dart';
import 'data/services/fcm_service.dart';
import 'providers/auth_provider.dart';
import 'screens/booking_screen.dart';
import 'providers/booking_provider.dart';
import 'providers/core_info_provider.dart';
import 'providers/events_provider.dart';
import 'data/repositories/menu_repository.dart';
import 'providers/menu_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/interior_screen.dart';
import 'data/services/api_client.dart';
import 'package:dio/dio.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/piligrim_auth_view.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Обязательно ДО runApp(), см. докстринг initializeFirebaseCore() — иначе
  // FcmService.instance (static final, конструируется лениво при первом
  // обращении) может словить необработанное исключение, если что-то (чаще
  // всего AuthProvider.init() при быстром восстановлении сессии/логине)
  // обратится к FirebaseMessaging.instance раньше, чем отработает
  // bootstrapFirebase() в фоне — раньше он запускался только через
  // addPostFrameCallback, без гарантии, что успеет до первого обращения.
  await initializeFirebaseCore();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const PiligrimApp());
}

/// Только Firebase.initializeApp() — быстрый, локальный вызов (без диалогов
/// разрешений и сетевых стримов), поэтому можно позволить себе подождать его
/// перед runApp() без заметной задержки первого кадра. Это тот самый вызов,
/// без которого FirebaseMessaging.instance (внутри FcmService) кидает
/// исключение — гарантируя, что он завершится до runApp(), мы гарантируем,
/// что ЛЮБОЙ код приложения (включая раннюю инициализацию провайдеров)
/// может безопасно трогать FcmService.instance, когда бы он до него ни добрался.
Future<void> initializeFirebaseCore() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'Firebase: заглушка (placeholder). Пуши отключены. '
      'Выполните flutterfire configure для продакшена.',
    );
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (e, st) {
    debugPrint('Firebase.initializeApp() skipped: $e\n$st');
  }
}

/// Остальная часть — подписка на стримы FCM и диалог разрешений. Это уже
/// можно безопасно откладывать в фон (не блокирует первый кадр/splash) —
/// в отличие от initializeFirebaseCore(), сама доступность
/// FirebaseMessaging.instance тут уже ни от чего не зависит по времени.
Future<void> bootstrapFirebase() async {
  if (Firebase.apps.isEmpty) return; // initializeFirebaseCore() не отработал
  try {
    await FcmService.instance
        .initEarly(navigatorKey: rootNavigatorKey)
        .timeout(const Duration(seconds: 5));
    await FcmService.instance.requestPermissionIfNeeded();
  } on TimeoutException {
    debugPrint('Firebase bootstrap timed out — UI continues without FCM');
  } catch (e, st) {
    debugPrint('Firebase bootstrap skipped: $e\n$st');
  }
}

class PiligrimApp extends StatefulWidget {
  const PiligrimApp({super.key});

  @override
  State<PiligrimApp> createState() => _PiligrimAppState();
}

class _PiligrimAppState extends State<PiligrimApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(bootstrapFirebase());
    });
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CoreInfoProvider()..load()),
        ChangeNotifierProvider(
          create: (_) => MenuProvider(repository: MenuRepository())..load(),
        ),
        ChangeNotifierProvider(create: (_) => EventsProvider()..load()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
      ],
      child: AmbientPresetScope(
        controller: _ambientCtrl,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'PILIGRIM',
          debugShowCheckedModeBanner: false,
          theme: piligrimTheme,
          home: const SplashScreen(),
          scrollBehavior: const _PlatformScrollBehavior(),
        ),
      ),
    );
  }
}

class _PlatformScrollBehavior extends ScrollBehavior {
  const _PlatformScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS
          ? const BouncingScrollPhysics()
          : const ClampingScrollPhysics();
}

// ─────────────────────────────────────────────────────────────────────────────
// Root Shell — навигация + Bottom Nav Bar
// ─────────────────────────────────────────────────────────────────────────────
class RootShell extends StatefulWidget {
  const RootShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  late int _currentIndex;
  final _scrollControllers = List.generate(5, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    PushNavigationHandler.onPushType = _onPushType;
    _checkConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (PushNavigationHandler.onPushType == _onPushType) {
      PushNavigationHandler.onPushType = null;
    }
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      await DioClient.instance.dio.get(
        '/core/info/',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      DioClient.isOfflineNotifier.value = false;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.badResponse) {
        DioClient.isOfflineNotifier.value = true;
      }
    } catch (_) {
      DioClient.isOfflineNotifier.value = true;
    }
  }

  void _onPushType(String type) {
    if (!mounted) return;
    switch (type) {
      case 'event':
        setState(() => _currentIndex = 3);
      case 'booking':
        Navigator.of(context).push(
          PiligrimPageRoute(builder: (_) => const BookingScreen()),
        );
      default:
        break;
    }
  }

  void _navigate(int index) {
    if (index == _currentIndex) {
      final ctrl = _scrollControllers[index];
      if (ctrl.hasClients) {
        ctrl.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Глобальный gate (ТЗ по входу: «Все функции приложения доступны только
    // участнику системы лояльности»): неавторизованный гость видит только
    // экран входа/регистрации/восстановления — ни один таб (включая Home/
    // Menu/Interior/Events) не собирается за IndexedStack ниже. Точечные
    // guardAuth() внутри отдельных экранов (бронь, закрытые события) остаются
    // как дополнительная защита, но с этим gate уже избыточны для верхнего
    // уровня. onSuccess пустой намеренно — PiligrimAuthView сам показывает
    // номер участника после регистрации и сбрасывает isNewUser; дальше
    // экран просто перестраивается по notifyListeners() из AuthProvider.
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return Scaffold(
        backgroundColor: PiligrimColors.earth,
        body: PiligrimAuthView(onSuccess: (_) {}),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: DioClient.isOfflineNotifier,
      builder: (context, isOffline, _) {
        return Scaffold(
          extendBody: true,
          backgroundColor: PiligrimColors.earth,
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: [
                  PrimaryScrollController(
                    controller: _scrollControllers[0],
                    child: HomeScreen(onNavigate: _navigate),
                  ),
                  PrimaryScrollController(
                    controller: _scrollControllers[1],
                    child: MenuScreen(isTabActive: _currentIndex == 1),
                  ),
                  PrimaryScrollController(
                    controller: _scrollControllers[2],
                    child: InteriorScreen(isTabActive: _currentIndex == 2),
                  ),
                  PrimaryScrollController(
                    controller: _scrollControllers[3],
                    child: const EventsScreen(),
                  ),
                  PrimaryScrollController(
                    controller: _scrollControllers[4],
                    child: ProfileScreen(onNavigate: _navigate),
                  ),
                ],
              ),
              if (isOffline)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 6,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: PiligrimColors.earthWarm.withValues(alpha: 0.92),
                      border: const Border(
                        bottom: BorderSide(
                          color: PiligrimColors.divider,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: PiligrimColors.steppe,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Офлайн-режим. Данные могут быть неактуальными',
                          style: PiligrimTextStyles.caption.copyWith(
                            color: PiligrimColors.sky,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: PiligrimNavBar(
            currentIndex: _currentIndex,
            onTap: _navigate,
          ),
        );
      },
    );
  }
}
