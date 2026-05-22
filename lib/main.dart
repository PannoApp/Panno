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
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: PiligrimColors.earthDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const PiligrimApp());
}

/// Firebase/FCM не блокируют первый кадр (splash).
Future<void> bootstrapFirebase() async {
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
          scrollBehavior: const _ClampingScrollBehavior(),
        ),
      ),
    );
  }
}

class _ClampingScrollBehavior extends ScrollBehavior {
  const _ClampingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
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

class _RootShellState extends State<RootShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    PushNavigationHandler.onPushType = _onPushType;
  }

  @override
  void dispose() {
    if (PushNavigationHandler.onPushType == _onPushType) {
      PushNavigationHandler.onPushType = null;
    }
    super.dispose();
  }

  void _onPushType(String type) {
    if (!mounted) return;
    switch (type) {
      case 'event':
        setState(() => _currentIndex = 3);
      case 'booking':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BookingScreen()),
        );
      default:
        break;
    }
  }

  void _navigate(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: PiligrimColors.earth,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onNavigate: _navigate),
          MenuScreen(isTabActive: _currentIndex == 1),
          InteriorScreen(isTabActive: _currentIndex == 2),
          const EventsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: PiligrimNavBar(
        currentIndex: _currentIndex,
        onTap: _navigate,
      ),
    );
  }
}
