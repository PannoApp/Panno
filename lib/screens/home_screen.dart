// Home Screen — «Карта путешествия» PILIGRIM
// Кинематографичный, тихий luxury; без glass / неона (piligrim_design_spec.md)
//
// ТЗ §4.1 (brand/TZ Piligrim App.md): hero и/или видео-визуал, концепция Modern Nomad,
// бронь (Ember CTA), меню и маршрут под блоком «Путь героя», анонс события, часы и статус.
//
// Виджеты: home_hero_section, home_cinematic_ambient,
//   home_action_block, home_event_block, home_status_line
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/theme.dart';
import '../providers/core_info_provider.dart';
import '../widgets/piligrim_background.dart';
import '../widgets/home_cinematic_ambient.dart';
import '../widgets/home_hero_section.dart';
import '../widgets/home_hero_intro_block.dart';
import '../widgets/home_action_block.dart';
import '../widgets/home_event_block.dart';
import '../widgets/home_status_line.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollCtrl = ScrollController();
  late final ValueNotifier<double> _scrollY;
  late final ValueNotifier<double> _tiltXn;
  late final ValueNotifier<double> _tiltYn;
  late final Listenable _parallax;
  StreamSubscription? _gyroSub;
  DateTime _lastTiltEmit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _scrollY = ValueNotifier(0);
    _tiltXn = ValueNotifier(0);
    _tiltYn = ValueNotifier(0);
    _parallax = Listenable.merge([_scrollY, _tiltXn, _tiltYn]);

    _scrollCtrl.addListener(() {
      _scrollY.value = _scrollCtrl.offset;
    });

    try {
      _gyroSub = accelerometerEventStream().listen(_onAccelerometer);
    } catch (_) {}
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastTiltEmit).inMilliseconds < 72) return;
    _lastTiltEmit = now;
    final nx = (event.x / 10).clamp(-1.0, 1.0);
    final ny = (event.y / 10).clamp(-1.0, 1.0);
    if ((nx - _tiltXn.value).abs() < 0.025 &&
        (ny - _tiltYn.value).abs() < 0.025) {
      return;
    }
    _tiltXn.value = nx;
    _tiltYn.value = ny;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _gyroSub?.cancel();
    _scrollY.dispose();
    _tiltXn.dispose();
    _tiltYn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = context.watch<CoreInfoProvider>();
    final size = MediaQuery.sizeOf(context);
    final heroHeight =
        (size.height * 0.58).clamp(310.0, size.height * 0.62).roundToDouble();
    final heroUrls = core.heroImageUrls;
    final hoursLine = core.workingHoursNote?.isNotEmpty == true
        ? '${core.workingHoursDisplay} · ${core.workingHoursNote}'
        : core.workingHoursDisplay;

    return Scaffold(
      backgroundColor: PiligrimColors.earthSurface,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _parallax,
                builder: (context, _) {
                  final y = _scrollY.value;
                  return PiligrimBackground(
                    parallaxOffset: y * 0.016,
                    cinematic: true,
                  );
                },
              ),
            ),
          ),

          Positioned.fill(
            child: AnimatedBuilder(
              animation: _parallax,
              builder: (context, _) {
                return HomeCinematicAmbient(
                  parallaxX: _tiltXn.value * 0.55,
                  parallaxY: _tiltYn.value * 0.45,
                );
              },
            ),
          ),

          CustomScrollView(
            controller: _scrollCtrl,
            clipBehavior: Clip.none,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _parallax,
                    builder: (context, _) {
                      return HomeHeroSection(
                        height: heroHeight,
                        scrollOffset: _scrollY.value,
                        tiltX: _tiltXn.value,
                        tiltY: _tiltYn.value,
                        heroNetworkUrls:
                            heroUrls.isEmpty ? null : heroUrls,
                      );
                    },
                  ),
                ),
              ),
              // Контент на PiligrimBackground — без ColoredBox / серой плашки.
              const SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RepaintBoundary(child: HomeHeroIntroBlock()),
                    RepaintBoundary(child: HomeActionBlock()),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: HomeEventBlock(onNavigate: widget.onNavigate),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: HomeStatusLine(
                    isOpen: core.isOpenNow,
                    hoursLabel: hoursLine,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }
}
