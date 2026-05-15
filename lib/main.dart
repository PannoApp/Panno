// Точка входа приложения PILIGRIM
// Тема: piligrim_design_spec.md — тёмная тема, цвета Қара жер / Мөлдір су / Сары дала
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/ambient_preset.dart';
import 'core/theme.dart';
// firebase_options.dart генерируется командой: flutterfire configure
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/events_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase — должна быть до runApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

class PiligrimApp extends StatefulWidget {
  const PiligrimApp({super.key});

  @override
  State<PiligrimApp> createState() => _PiligrimAppState();
}

class _PiligrimAppState extends State<PiligrimApp> {
  final AmbientPresetController _ambientCtrl = AmbientPresetController();

  @override
  void initState() {
    super.initState();
    _ambientCtrl.load();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmbientPresetScope(
      controller: _ambientCtrl,
      child: MaterialApp(
        title: 'PILIGRIM',
        debugShowCheckedModeBanner: false,
        theme: piligrimTheme,
        home: const SplashScreen(),
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
      // false: иначе вместе с BackdropFilter на навбаре на части устройств размывался весь body.
      extendBody: false,
      backgroundColor: PiligrimColors.earth,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onNavigate: _navigate),
          const MenuScreen(),
          const EventsScreen(),
          const BookingScreen(),
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
