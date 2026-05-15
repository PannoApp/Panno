// Premium cinematic atmosphere для home — пыль, grain, тёплое дыхание света.
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
      duration: const Duration(seconds: 90),
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

  static const _tau = math.pi * 2;
  static List<_Mote>? _motes;
  static List<_Grain>? _grain;

  static List<_Mote> _makeMotes(int n) {
    final r = math.Random(0xD0574C);
    return List.generate(
      n,
      (_) => _Mote(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: r.nextDouble() * 0.35 + 0.15,
        drift: r.nextDouble() * 0.08 + 0.02,
        phase: r.nextDouble(),
        warmth: r.nextDouble(),
      ),
    );
  }

  static List<_Grain> _makeGrain(int n) {
    final r = math.Random(0x475241);
    return List.generate(
      n,
      (i) => _Grain(
        x: r.nextDouble(),
        y: r.nextDouble(),
        phase: (i * 0.137) % 1.0,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    _motes ??= _makeMotes(14);
    _grain ??= _makeGrain(96);

    // Медленное amber-дыхание — свечи, тишина.
    final breath = 0.5 + 0.5 * math.sin(t * _tau * 0.55);
    final amber = 0.022 + breath * 0.028;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.12 + parallaxX * 0.03, 0.88 + parallaxY * 0.02),
          radius: 1.15,
          colors: [
            PiligrimColors.nomadCream.withValues(alpha: amber * 0.55),
            PiligrimColors.steppe.withValues(alpha: amber * 0.35),
            PiligrimColors.clear,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    // Мягкий луч света сверху-сбоку (пыль в воздухе).
    final shaft = 0.5 + 0.5 * math.sin(t * _tau * 0.35 + 0.8);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-0.6 + parallaxX * 0.05, -1.0),
          end: Alignment(0.5, 0.4),
          colors: [
            PiligrimColors.sky.withValues(alpha: 0.012 + shaft * 0.016),
            PiligrimColors.clear,
            PiligrimColors.clear,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // Едва заметный холодный контраст бренда — сверху.
    final cool = 0.5 + 0.5 * math.sin(t * _tau * 0.4 + 2.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.5 + parallaxX * 0.02, -0.82),
          radius: 0.9,
          colors: [
            PiligrimColors.water.withValues(alpha: 0.008 + cool * 0.012),
            PiligrimColors.clear,
          ],
        ).createShader(rect),
    );

    // Film grain — статичная сетка, очень тихий дрейф.
    final grainShift = math.sin(t * _tau * 0.25) * 0.4;
    for (final g in _grain!) {
      final flicker =
          0.5 + 0.5 * math.sin(t * _tau * 0.6 + g.phase * _tau);
      final a = (0.012 + flicker * 0.018).clamp(0.008, 0.032);
      final gx = ((g.x * w) + grainShift) % w;
      final gy = ((g.y * h) + grainShift * 0.6) % h;
      canvas.drawCircle(
        Offset(gx, gy),
        0.45,
        Paint()..color = PiligrimColors.sky.withValues(alpha: a),
      );
    }

    // Редкие моты пыли — горизонтальный дрейф, без «падающих искр».
    for (final m in _motes!) {
      final slow = (t * m.drift + m.phase) % 1.0;
      final nx = (m.x + slow * 0.06 +
              math.sin(t * _tau * 0.18 + m.phase) * 0.012 +
              parallaxX * 0.004) %
          1.0;
      final ny = (m.y +
              math.cos(t * _tau * 0.14 + m.phase * 2) * 0.008 +
              parallaxY * 0.003) %
          1.0;
      final glint =
          0.4 + 0.6 * math.sin(t * _tau * 0.45 + m.phase * _tau);
      final a = (0.018 + glint * 0.022).clamp(0.012, 0.045);
      final tone = m.warmth > 0.55
          ? PiligrimColors.nomadCream
          : PiligrimColors.sky;
      canvas.drawCircle(
        Offset(nx * w, ny * h),
        m.size,
        Paint()..color = tone.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HomeAmbientPainter old) =>
      old.t != t ||
      old.parallaxX != parallaxX ||
      old.parallaxY != parallaxY;
}

class _Mote {
  const _Mote({
    required this.x,
    required this.y,
    required this.size,
    required this.drift,
    required this.phase,
    required this.warmth,
  });
  final double x, y, size, drift, phase, warmth;
}

class _Grain {
  const _Grain({required this.x, required this.y, required this.phase});
  final double x, y, phase;
}
