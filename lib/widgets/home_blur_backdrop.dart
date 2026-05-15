// Многослойный фон главной: интерьер как цветовое пятно (ImageFiltered blur 20)
// + атмосферные градиенты бренда. Включается только при kHomeLayeredBlurGlass.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../core/ambient_preset.dart';
import '../core/theme.dart';
import 'piligrim_triptych_interior_backdrop.dart';

/// Нижний слой: размытый интерьер + градиентные слои (Қара жер / Мөлдір су / Жалын).
class HomeLayeredBlurBackdrop extends StatelessWidget {
  const HomeLayeredBlurBackdrop({
    super.key,
    required this.scrollOffset,
    required this.tiltX,
    required this.tiltY,
    required this.preset,
  });

  final double scrollOffset;
  final double tiltX;
  final double tiltY;
  final AppAmbientPreset preset;

  double _emberBoost() {
    return switch (preset) {
      AppAmbientPreset.calm => 0.9,
      AppAmbientPreset.ember => 1.05,
      AppAmbientPreset.mystic => 1.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final em = _emberBoost();
    final px = scrollOffset * 0.06 + tiltX * 12;
    final py = scrollOffset * 0.04 + tiltY * 10;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: PiligrimColors.earth.withValues(alpha: 0.55)),

        // Размытый интерьер — только цвет и масса, без читаемых деталей
        Positioned.fill(
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(-px * 0.4, -py * 0.25),
              child: Transform.scale(
                scale: 1.18,
                alignment: Alignment.center,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: PiligrimTriptychInteriorBackdrop(
                    opacityScale: 1.05,
                    parallax: Offset(-px * 0.4, -py * 0.25),
                    cycleDuration: const Duration(seconds: 52),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Слой 2: глубина Қара жер
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.42, 0.78, 1.0],
              colors: [
                PiligrimColors.skyWarm.withValues(alpha: 0.35),
                PiligrimColors.earth,
                PiligrimColors.steppe.withValues(alpha: 0.18),
                PiligrimColors.earthDeep.withValues(alpha: 0.82),
              ],
            ),
          ),
        ),

        // Слой 3: тёплый виньет + вода (мөлдір)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.15, -0.55),
              radius: 1.1,
              colors: [
                PiligrimColors.water.withValues(alpha: 0.12 * em),
                PiligrimColors.clear,
              ],
              stops: const [0.0, 0.55],
            ),
          ),
        ),

        // Слой 4: низ — земля и лёгкий огонь
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
              colors: [
                PiligrimColors.clear,
                PiligrimColors.earthDeep.withValues(alpha: 0.28),
                PiligrimColors.earthDeep.withValues(alpha: 0.52),
              ],
            ),
          ),
        ),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.85, 0.92),
              radius: 0.95,
              colors: [
                PiligrimColors.ember.withValues(alpha: 0.14 * em),
                PiligrimColors.steppe.withValues(alpha: 0.06 * em),
                PiligrimColors.clear,
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
