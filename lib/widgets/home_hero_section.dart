// Hero-секция главного экрана — большая фотография интерьера с параллаксом,
// ротирующийся слоган, логотип и декоративная линия «пути героя».
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';
import '../core/home_data.dart';
import '../core/interior_assets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HERO INTERIOR — двойной слой с кроссфейдом
// ─────────────────────────────────────────────────────────────────────────────
class CrossfadingHeroInterior extends StatefulWidget {
  const CrossfadingHeroInterior({
    super.key,
    required this.paths,
    required this.index,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final List<String> paths;
  final int index;
  final int cacheWidth;
  final int cacheHeight;

  @override
  State<CrossfadingHeroInterior> createState() => _CrossfadingHeroInteriorState();
}

class _CrossfadingHeroInteriorState extends State<CrossfadingHeroInterior>
    with SingleTickerProviderStateMixin {
  late int _from;
  late int _to;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final len = widget.paths.length;
    final i = len == 0 ? 0 : widget.index % len;
    _from = i;
    _to = i;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant CrossfadingHeroInterior oldWidget) {
    super.didUpdateWidget(oldWidget);
    final len = widget.paths.length;
    if (len == 0) return;
    final newIdx = widget.index % len;
    final oldIdx = oldWidget.index % len;
    if (newIdx != oldIdx) {
      _from = oldIdx;
      _to = newIdx;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.paths.length;
    if (len == 0) return const SizedBox.expand();

    Widget shot(int i) {
      final path = widget.paths[i % len];
      return Image.asset(
        path,
        fit: BoxFit.cover,
        alignment: const Alignment(0.0, 0.16),
        isAntiAlias: true,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOutCubic.transform(_ctrl.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: 1 - t, child: shot(_from)),
            Opacity(opacity: t, child: shot(_to)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SECTION — cinematic interior + тёплый fade в тень
// ─────────────────────────────────────────────────────────────────────────────
class HomeHeroSection extends StatefulWidget {
  const HomeHeroSection({
    super.key,
    required this.height,
    required this.scrollOffset,
    required this.tiltX,
    required this.tiltY,
  });

  final double height;
  final double scrollOffset;
  final double tiltX;
  final double tiltY;

  @override
  State<HomeHeroSection> createState() => _HomeHeroSectionState();
}

class _HomeHeroSectionState extends State<HomeHeroSection> {
  int _phraseIndex = 0;
  int _heroVisualIndex = 0;
  late Timer _phraseTimer;
  late Timer _heroVisualTimer;
  static const double _heroImageScrollParallax = 0.2;
  static const double _heroImageScale = 1.14;
  static const _heroVisuals = PiligrimInteriorAssets.homeHeroCycle;

  /// Длинный тёплый спуск света в тень — только коричнево-чёрные тона бренда.
  static const _shadowFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      PiligrimColors.clear,
      PiligrimColors.clear,
      Color(0x0C211D1A),
      Color(0x1E211D1A),
      Color(0x33211D1A),
      Color(0x4A2A2521),
      Color(0x662A2826),
      Color(0x853D3A38),
      Color(0xA83D3A38),
      Color(0xD03D3A38),
      PiligrimColors.earth,
    ],
    stops: [0.0, 0.34, 0.48, 0.58, 0.67, 0.75, 0.83, 0.89, 0.94, 0.98, 1.0],
  );

  static const List<Shadow> _heroTextShadows = [
    Shadow(
      color: Color(0x8C000000),
      blurRadius: 20,
      offset: Offset(0, 2),
    ),
    Shadow(
      color: Color(0x55211818),
      blurRadius: 32,
      offset: Offset(0, 6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _phraseTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _phraseIndex = (_phraseIndex + 1) % kHeroPhrases.length);
    });
    _heroVisualTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      setState(() => _heroVisualIndex = (_heroVisualIndex + 1) % _heroVisuals.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cw = PiligrimInteriorAssets.decodeCacheWidth(context);
      final ch = PiligrimInteriorAssets.decodeCacheHeight(context, widget.height);
      for (final p in _heroVisuals) {
        precacheImage(
          ResizeImage(AssetImage(p), width: cw, height: ch),
          context,
        );
      }
    });
  }

  @override
  void dispose() {
    _phraseTimer.cancel();
    _heroVisualTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Интерьер: cover + масштаб + длинный тёплый fade (свет уходит в тень)
          Positioned.fill(
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(
                  widget.tiltX * 8,
                  widget.tiltY * 6 +
                      widget.scrollOffset * _heroImageScrollParallax,
                ),
                child: Transform.scale(
                  scale: _heroImageScale,
                  alignment: const Alignment(0.0, 0.28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CrossfadingHeroInterior(
                        paths: _heroVisuals,
                        index: _heroVisualIndex,
                        cacheWidth:
                            PiligrimInteriorAssets.decodeCacheWidth(context),
                        cacheHeight: PiligrimInteriorAssets.decodeCacheHeight(
                          context,
                          widget.height * 1.08,
                        ),
                      ),
                      const DecoratedBox(decoration: BoxDecoration(gradient: _shadowFade)),
                      // Едва заметное тёплое «дыхание огня» у пола — не серая плашка
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.1, 1.25),
                            radius: 0.85,
                            colors: [
                              PiligrimColors.clear,
                              PiligrimColors.ember.withValues(alpha: 0.04),
                              PiligrimColors.clear,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Логотип, слоган, описание
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/piligrim.svg',
                  height: 36,
                  colorFilter: const ColorFilter.mode(
                    PiligrimColors.sky,
                    BlendMode.srcIn,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 900.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 900.ms),

                const SizedBox(height: 16),

                SizedBox(
                  height: 76,
                  width: double.infinity,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1100),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: Align(
                      key: ValueKey<int>(_phraseIndex),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        kHeroPhrases[_phraseIndex],
                        style: PiligrimTextStyles.display.copyWith(
                          fontSize: 28,
                          height: 1.18,
                          color: PiligrimColors.sky,
                          letterSpacing: 0.2,
                          shadows: _heroTextShadows,
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 900.ms),

                const SizedBox(height: 10),

                Text(
                  kModernNomadConcept,
                  style: PiligrimTextStyles.body.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w300,
                    color: PiligrimColors.sky.withValues(alpha: 0.88),
                    shadows: _heroTextShadows,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 420.ms, duration: 800.ms),

                const SizedBox(height: 12),

                Text(
                  'Ударьте в бубен — начните путь',
                  style: PiligrimTextStyles.caption.copyWith(
                    color: PiligrimColors.sky.withValues(alpha: 0.56),
                    letterSpacing: 1.1,
                    fontSize: 10.5,
                    shadows: _heroTextShadows,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 750.ms, duration: 700.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

