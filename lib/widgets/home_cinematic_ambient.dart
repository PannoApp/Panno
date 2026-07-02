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
      duration: const Duration(seconds: 120),
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
      (i) => _Mote(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: r.nextDouble() * 0.28 + 0.12,
        drift: i < 5 ? r.nextDouble() * 0.015 + 0.004 : 0,
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

    _motes ??= _makeMotes(8);
    _grain ??= _makeGrain(58);

    final breath = 0.5 + 0.5 * math.sin(t * _tau * 0.38);
    final amber = 0.016 + breath * 0.020;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.12 + parallaxX * 0.02, 0.88 + parallaxY * 0.015),
          radius: 1.15,
          colors: [
            PiligrimColors.nomadCream.withValues(alpha: amber * 0.45),
            PiligrimColors.steppe.withValues(alpha: amber * 0.28),
            PiligrimColors.clear,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    final shaft = 0.5 + 0.5 * math.sin(t * _tau * 0.22 + 0.8);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-0.6 + parallaxX * 0.04, -1.0),
          end: const Alignment(0.5, 0.4),
          colors: [
            PiligrimColors.sky.withValues(alpha: 0.008 + shaft * 0.010),
            PiligrimColors.clear,
            PiligrimColors.clear,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    final cool = 0.5 + 0.5 * math.sin(t * _tau * 0.28 + 2.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.5 + parallaxX * 0.015, -0.82),
          radius: 0.9,
          colors: [
            PiligrimColors.water.withValues(alpha: 0.006 + cool * 0.008),
            PiligrimColors.clear,
          ],
        ).createShader(rect),
    );

    final grainShift = math.sin(t * _tau * 0.14) * 0.25;
    for (final g in _grain!) {
      final flicker =
          0.5 + 0.5 * math.sin(t * _tau * 0.35 + g.phase * _tau);
      final a = (0.008 + flicker * 0.010).clamp(0.006, 0.020);
      final gx = ((g.x * w) + grainShift) % w;
      final gy = ((g.y * h) + grainShift * 0.5) % h;
      canvas.drawCircle(
        Offset(gx, gy),
        0.4,
        Paint()..color = PiligrimColors.sky.withValues(alpha: a),
      );
    }

    for (final m in _motes!) {
      final slow = m.drift > 0 ? (t * m.drift + m.phase) % 1.0 : 0.0;
      final nx = (m.x +
              slow * 0.025 +
              math.sin(t * _tau * 0.10 + m.phase) * 0.006 +
              parallaxX * 0.003) %
          1.0;
      final ny = (m.y +
              math.cos(t * _tau * 0.08 + m.phase * 2) * 0.004 +
              parallaxY * 0.002) %
          1.0;
      final glint =
          0.45 + 0.55 * math.sin(t * _tau * 0.28 + m.phase * _tau);
      final a = (0.010 + glint * 0.014).clamp(0.008, 0.028);
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
