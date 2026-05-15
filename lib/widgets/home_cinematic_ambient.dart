// Кинематографичный слой только для главного экрана:
// медленные пылинки + тёплое «дыхание» света (без blur / glass).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Лёгкая атмосфера поверх [PiligrimBackground], под скроллом.
class HomeCinematicAmbient extends StatefulWidget {
  const HomeCinematicAmbient({
    super.key,
    this.parallaxX = 0,
    this.parallaxY = 0,
  });

  final double parallaxX;
  final double parallaxY;

  @override
  State<HomeCinematicAmbient> createState() => _HomeCinematicAmbientState();
}

class _HomeCinematicAmbientState extends State<HomeCinematicAmbient>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 42),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _HomeAmbientPainter(
                t: _ctrl.value,
                parallaxX: widget.parallaxX,
                parallaxY: widget.parallaxY,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _HomeAmbientPainter extends CustomPainter {
  _HomeAmbientPainter({
    required this.t,
    required this.parallaxX,
    required this.parallaxY,
  });

  final double t;
  final double parallaxX;
  final double parallaxY;

  static List<_DustGrain>? _grains;

  static List<_DustGrain> _makeGrains(int n) {
    final r = math.Random(0x50494C49);
    return List.generate(
      n,
      (_) => _DustGrain(
        x: r.nextDouble(),
        y: r.nextDouble(),
        radius: r.nextDouble() * 0.55 + 0.25,
        speed: r.nextDouble() * 0.35 + 0.12,
        phase: r.nextDouble(),
        wobble: r.nextDouble() * 0.9 + 0.2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    _grains ??= _makeGrains(52);

    // Тёплое «дыхание» — низ и центр, очень мягко
    final breath = 0.42 + 0.58 * math.sin(t * math.pi * 2 * 1.85);
    final warmAlpha = 0.04 + breath * 0.055;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.08 * parallaxX, 0.92 + 0.04 * parallaxY),
          radius: 1.05,
          colors: [
            PiligrimColors.steppe.withValues(alpha: warmAlpha),
            PiligrimColors.ember.withValues(alpha: warmAlpha * 0.45),
            PiligrimColors.clear,
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(rect),
    );

    // Второй слой — чуть холоднее, верх (луна бренда), едва заметно
    final coolBreath = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 1.2 + 1.1);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.55 + parallaxX * 0.04, -0.75),
          radius: 0.95,
          colors: [
            PiligrimColors.water.withValues(alpha: 0.018 + coolBreath * 0.022),
            PiligrimColors.clear,
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect),
    );

    // Пылинки — медленный дрейф
    for (final g in _grains!) {
      final drift = (t * g.speed + g.phase) % 1.0;
      final nx = g.x +
          math.sin((t + g.phase) * math.pi * 2 * g.wobble) * 0.018 +
          parallaxX * 0.006;
      final ny = (g.y - drift * 0.42 + 0.15) % 1.08 - 0.04;
      final px = (nx * w).clamp(0.0, w);
      final py = (ny * h).clamp(0.0, h);
      final twinkle =
          0.35 + 0.65 * math.sin((t * 6.2 + g.phase * 11) * math.pi * 2);
      final a = (0.045 + twinkle * 0.07) * (0.55 + g.radius * 0.35);
      canvas.drawCircle(
        Offset(px, py),
        g.radius,
        Paint()..color = PiligrimColors.sky.withValues(alpha: a.clamp(0.02, 0.14)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HomeAmbientPainter old) =>
      old.t != t ||
      old.parallaxX != parallaxX ||
      old.parallaxY != parallaxY;
}

class _DustGrain {
  const _DustGrain({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.wobble,
  });
  final double x, y, radius, speed, phase, wobble;
}
