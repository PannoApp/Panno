// Триптих интерьеров 21 · 12 · 13 — мягкий кроссфейд и лёгкий Ken Burns.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/interior_assets.dart';
import '../core/theme.dart';

/// Анимированный фон из трёх кадров: плавная смена, «дыхание» масштаба и параллакс.
class PiligrimTriptychInteriorBackdrop extends StatefulWidget {
  const PiligrimTriptychInteriorBackdrop({
    super.key,
    this.opacityScale = 1,
    this.parallax = Offset.zero,
    this.cycleDuration = const Duration(seconds: 44),
    this.breatheScale = 0.028,
  });

  /// Множитель к непрозрачности слоёв (0…1+).
  final double opacityScale;

  /// Сдвиг от скролла / гироскопа.
  final Offset parallax;

  /// Длительность полного цикла 21→12→13→21.
  final Duration cycleDuration;

  /// Амплитуда «Ken Burns» (доля от 1.0).
  final double breatheScale;

  @override
  State<PiligrimTriptychInteriorBackdrop> createState() =>
      _PiligrimTriptychInteriorBackdropState();
}

class _PiligrimTriptychInteriorBackdropState
    extends State<PiligrimTriptychInteriorBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static List<String> get _paths => PiligrimInteriorAssets.triptychInteriorAmbient;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycleDuration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant PiligrimTriptychInteriorBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleDuration != widget.cycleDuration) {
      _ctrl.duration = widget.cycleDuration;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cw = PiligrimInteriorAssets.decodeCacheWidth(context);
    final ch = PiligrimInteriorAssets.decodeCacheHeight(
      context,
      MediaQuery.sizeOf(context).height,
    );

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final u = _ctrl.value;
        final phase = u * 3.0;
        final i = phase.floor() % 3;
        final t = Curves.easeInOutCubic.transform(phase - phase.floor());
        final wOut = (1.0 - t) * widget.opacityScale;
        final wIn = t * widget.opacityScale;
        final breathe = 1.0 + widget.breatheScale * math.sin(u * math.pi * 2);
        final drift = Offset(
          math.sin(u * math.pi * 2.1) * 5,
          math.cos(u * math.pi * 1.9) * 4,
        );

        Widget layer(String path, double opacity, double phaseShift) {
          if (opacity <= 0.01) return const SizedBox.shrink();
          final ph = u + phaseShift;
          final s = breathe + 0.012 * math.sin(ph * math.pi * 4);
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: widget.parallax + drift * 0.35,
              child: Transform.scale(
                scale: s,
                alignment: Alignment(
                  0.15 * math.sin(ph * math.pi * 2),
                  0.1 * math.cos(ph * math.pi * 2),
                ),
                child: Image.asset(
                  path,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  isAntiAlias: true,
                  cacheWidth: cw,
                  cacheHeight: ch,
                ),
              ),
            ),
          );
        }

        final a = _paths[i];
        final b = _paths[(i + 1) % 3];

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ColoredBox(color: PiligrimColors.earthDeep.withValues(alpha: 0.22)),
            layer(a, wOut * 0.52 + 0.1, 0),
            layer(b, wIn * 0.52 + 0.1, 0.17),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.1, -0.45),
                    radius: 1.05,
                    colors: [
                      PiligrimColors.clear,
                      PiligrimColors.earthDeep.withValues(alpha: 0.35),
                    ],
                    stops: const [0.42, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
