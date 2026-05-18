// Точка входа приложения PILIGRIM
// Тема: piligrim_design_spec.md — тёмная тема, цвета Қара жер / Мөлдір су / Сары дала
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/interior_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Прозрачный статус-бар — органично вписывается в тёмный фон Қара жер
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: PiligrimColors.earthDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Только портретная ориентация
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const PiligrimApp());
  });
}

class PiligrimApp extends StatelessWidget {
  const PiligrimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PILIGRIM',
      debugShowCheckedModeBanner: false,
      theme: piligrimTheme,
      home: const SplashScreen(),
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
      // false: иначе вместе с BackdropFilter на навбаре на части устройств размывался весь body.
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
