// Точка входа приложения PILIGRIM
// Тема: piligrim_design_spec.md — тёмная тема, цвета Қара жер / Мөлдір су / Сары дала
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/ambient_preset_scope.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/core_info_provider.dart';
import 'providers/events_provider.dart';
import 'providers/menu_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/interior_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: PiligrimColors.earthDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const PiligrimApp());
  });
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
        ChangeNotifierProvider(create: (_) => MenuProvider()..load()),
        ChangeNotifierProvider(create: (_) => EventsProvider()..load()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
      ],
      child: AmbientPresetScope(
        controller: _ambientCtrl,
        child: MaterialApp(
          title: 'PILIGRIM',
          debugShowCheckedModeBanner: false,
          theme: piligrimTheme,
          home: const SplashScreen(),
        ),
      ),
    );
  }
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
          const MenuScreen(),
          const InteriorScreen(),
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
