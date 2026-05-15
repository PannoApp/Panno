import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/ambient_preset.dart';
import '../core/theme.dart';
import 'piligrim_triptych_interior_backdrop.dart';
import 'textured_background.dart';

class _PresetTuning {
  const _PresetTuning({
    required this.emberBase,
    required this.emberWave,
    required this.logoOpacity,
    required this.runeOpacityScale,
    required this.motionScale,
    required this.topGlowColor,
    required this.bottomGlowColor,
    required this.runePrimary,
    required this.runeSecondary,
  });

  final double emberBase;
  final double emberWave;
  final double logoOpacity;
  final double runeOpacityScale;
  final double motionScale;
  final Color topGlowColor;
  final Color bottomGlowColor;
  final Color runePrimary;
  final Color runeSecondary;
}

_PresetTuning _tuningForPreset(AppAmbientPreset preset) {
  switch (preset) {
    case AppAmbientPreset.calm:
      return const _PresetTuning(
        emberBase: 0.055,
        emberWave: 0.034,
        logoOpacity: 0.08,
        runeOpacityScale: 0.92,
        motionScale: 0.78,
        topGlowColor: PiligrimColors.water,
        bottomGlowColor: PiligrimColors.sky,
        runePrimary: PiligrimColors.water,
        runeSecondary: PiligrimColors.sky,
      );
    case AppAmbientPreset.ember:
      return const _PresetTuning(
        emberBase: 0.16,
        emberWave: 0.1,
        logoOpacity: 0.12,
        runeOpacityScale: 1.42,
        motionScale: 1.22,
        topGlowColor: PiligrimColors.ember,
        bottomGlowColor: PiligrimColors.steppe,
        runePrimary: PiligrimColors.steppe,
        runeSecondary: PiligrimColors.water,
      );
    case AppAmbientPreset.mystic:
      return const _PresetTuning(
        emberBase: 0.085,
        emberWave: 0.058,
        logoOpacity: 0.17,
        runeOpacityScale: 2.05,
        motionScale: 1.72,
        topGlowColor: PiligrimColors.water,
        bottomGlowColor: PiligrimColors.earthDeep,
        runePrimary: PiligrimColors.water,
        runeSecondary: PiligrimColors.steppe,
      );
  }
}

/// Универсальный атмосферный фон PILIGRIM:
/// - тёмная текстура (камень/кожа),
/// - тёплое огненное свечение (медь/латунь),
/// - медленно "плавающие" тотемы,
/// - призрачный логотип в глубине.
class EthnoAmbientBackground extends StatefulWidget {
  const EthnoAmbientBackground({
    super.key,
    this.parallaxOffset = 0,
    this.tiltX = 0,
    this.tiltY = 0,
    this.showLogo = true,
    this.showRunes = true,
    this.preset = AppAmbientPreset.ember,
    this.intensityMultiplier = 1.0,
    this.showInteriorTriptych = true,
  });

  final double parallaxOffset;
  final double tiltX;
  final double tiltY;
  final bool showLogo;
  final bool showRunes;
  final AppAmbientPreset preset;
  final double intensityMultiplier;

  /// Анимированный триптих 21·12·13 под текстурой (на главной отключите — там свой слой).
  final bool showInteriorTriptych;

  @override
  State<EthnoAmbientBackground> createState() => _EthnoAmbientBackgroundState();
}

class _EthnoAmbientBackgroundState extends State<EthnoAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final tuning = _tuningForPreset(widget.preset);
        final t = _ctrl.value;
        final motion = tuning.motionScale * widget.intensityMultiplier;
        final driftX = math.sin(t * math.pi * 2) * 10 * motion + widget.tiltX * 8;
        final driftY = math.cos(t * math.pi * 2) * 8 * motion + widget.tiltY * 8;
        final emberAlpha =
            (tuning.emberBase + (math.sin(t * math.pi * 4) + 1) * tuning.emberWave) *
                widget.intensityMultiplier;
        final coalPulse = (math.sin(t * math.pi * 13) + 1) * 0.5;
        final emberSpark = (math.sin(t * math.pi * 19) + 1) * 0.5;
        final bedBreath = (math.sin(t * math.pi * 7.3) + 1) * 0.5;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: TexturedBackground(parallaxOffset: widget.parallaxOffset),
            ),
            if (widget.showInteriorTriptych)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (0.42 * widget.intensityMultiplier).clamp(0.22, 0.55),
                    child: PiligrimTriptychInteriorBackdrop(
                      opacityScale: 1.05,
                      parallax: Offset(
                        widget.tiltX * 6 - widget.parallaxOffset * 0.02,
                        widget.tiltY * 5,
                      ),
                      cycleDuration: const Duration(seconds: 56),
                    ),
                  ),
                ),
              ),

            // Общее огненное оранжевое свечение по интерьерной атмосфере.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.15 + driftX / 300, -0.55 + driftY / 300),
                    radius: 1.05,
                    colors: [
                      PiligrimColors.ember.withValues(alpha: emberAlpha),
                      PiligrimColors.emberDeep.withValues(alpha: emberAlpha * 0.45),
                      PiligrimColors.clear,
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),

            // Ярко отличающийся характер пресетов:
            // calm — водный холодный, ember — тёплый янтарный, mystic — глубокий контрастный.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tuning.topGlowColor.withValues(
                        alpha: (widget.preset == AppAmbientPreset.mystic ? 0.2 : 0.15) *
                            widget.intensityMultiplier,
                      ),
                      PiligrimColors.clear,
                      tuning.bottomGlowColor.withValues(
                        alpha: (widget.preset == AppAmbientPreset.calm ? 0.11 : 0.17) *
                            widget.intensityMultiplier,
                      ),
                    ],
                    stops: const [0.0, 0.44, 1.0],
                  ),
                ),
              ),
            ),

            // Дополнительный мягкий "барный" оранжево-латунный отсвет сверху справа.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      tuning.topGlowColor.withValues(
                        alpha: 0.10 * widget.intensityMultiplier,
                      ),
                      tuning.bottomGlowColor.withValues(
                        alpha: 0.08 * widget.intensityMultiplier,
                      ),
                      PiligrimColors.clear,
                    ],
                    stops: const [0.0, 0.35, 0.9],
                  ),
                ),
              ),
            ),

            // «Уголь в золе» — тёмное дно с быстрым мерцанием + вспышки пламени.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.08 + math.sin(t * math.pi * 5.1) * 0.14,
                      0.88 + math.cos(t * math.pi * 4.2) * 0.06,
                    ),
                    radius: 0.38 + coalPulse * 0.14,
                    colors: [
                      PiligrimColors.shadow.withValues(
                        alpha: (0.1 + bedBreath * 0.08) * widget.intensityMultiplier,
                      ),
                      PiligrimColors.emberDeep.withValues(
                        alpha: (0.12 + emberSpark * 0.1) * widget.intensityMultiplier,
                      ),
                      PiligrimColors.clear,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.55 + math.sin(t * math.pi * 6.7) * 0.2,
                      0.72 + math.cos(t * math.pi * 5.9) * 0.1,
                    ),
                    radius: 0.22 + emberSpark * 0.1,
                    colors: [
                      PiligrimColors.ember.withValues(
                        alpha: (0.05 + emberSpark * 0.09) * widget.intensityMultiplier,
                      ),
                      PiligrimColors.steppe.withValues(
                        alpha: (0.03 + coalPulse * 0.05) * widget.intensityMultiplier,
                      ),
                      PiligrimColors.clear,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            if (widget.showLogo)
              Positioned(
                left: -36 + driftX * 0.2,
                top: 92 + driftY * 0.15,
                child: Transform.rotate(
                  angle: t * math.pi * 2 * 0.06,
                  child: SvgPicture.asset(
                    'assets/images/star logo заставка (Traced).svg',
                    width: 190,
                    height: 190,
                    colorFilter: ColorFilter.mode(
                      PiligrimColors.steppe.withValues(alpha: tuning.logoOpacity),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

            if (widget.showRunes) ...[
              _FloatingTotem(
                asset: 'assets/images/spiral.svg',
                baseOffset: const Offset(18, 210),
                size: 76,
                t: t,
                drift: Offset(driftX, driftY),
                opacity: 0.07 * tuning.runeOpacityScale,
                color: tuning.runePrimary,
              ),
              _FloatingTotem(
                asset: widget.preset == AppAmbientPreset.calm
                    ? 'assets/images/moon_totem (1).svg'
                    : 'assets/images/shaman.svg',
                baseOffset: const Offset(280, 140),
                size: 94,
                t: t + 0.27,
                drift: Offset(driftX * 0.6, driftY * 0.6),
                opacity: 0.05 * tuning.runeOpacityScale,
                color: tuning.runeSecondary,
              ),
              _FloatingTotem(
                asset: widget.preset == AppAmbientPreset.mystic
                    ? 'assets/images/wheel_totem (1).svg'
                    : 'assets/images/tree_totem (1).svg',
                baseOffset: const Offset(300, 540),
                size: 74,
                t: t + 0.53,
                drift: Offset(driftX * 0.45, driftY * 0.5),
                opacity: 0.06 * tuning.runeOpacityScale,
                color: tuning.runePrimary,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FloatingTotem extends StatelessWidget {
  const _FloatingTotem({
    required this.asset,
    required this.baseOffset,
    required this.size,
    required this.t,
    required this.drift,
    required this.opacity,
    required this.color,
  });

  final String asset;
  final Offset baseOffset;
  final double size;
  final double t;
  final Offset drift;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dx = math.sin(t * math.pi * 2.2) * 12 + drift.dx;
    final dy = math.cos(t * math.pi * 2.0) * 10 + drift.dy;
    final rot = math.sin(t * math.pi * 2) * 0.06;

    return Positioned(
      left: baseOffset.dx + dx,
      top: baseOffset.dy + dy,
      child: Transform.rotate(
        angle: rot,
        child: SvgPicture.asset(
          asset,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(
            color.withValues(alpha: opacity),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
