// Фон PILIGRIM — «Камин».
// Тёмный верх, тёплое свечение тлеющих углей снизу,
// искры-частицы медленно поднимаются вверх.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class PiligrimBackground extends StatefulWidget {
  const PiligrimBackground({
    super.key,
    this.parallaxOffset = 0.0,
    this.textureOpacity = 0.4,
    this.vignetteIntensity = 0.22,
    this.showInterior = true,
    this.interiorOpacity = 0.45,
    this.blurSigma = 5.0,
  });

  final double parallaxOffset;
  final double textureOpacity;
  final double vignetteIntensity;
  final bool showInterior;
  final double interiorOpacity;
  final double blurSigma;

  @override
  State<PiligrimBackground> createState() => _PiligrimBackgroundState();
}

class _PiligrimBackgroundState extends State<PiligrimBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _FireplacePainter(
            time: _ctrl.value,
            parallaxOffset: widget.parallaxOffset,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _FireplacePainter extends CustomPainter {
  _FireplacePainter({required this.time, required this.parallaxOffset});

  final double time;
  final double parallaxOffset;

  static const _tau = 2.0 * math.pi;
  static List<_Spark>? _sparks;

  static List<_Spark> _makeSparks(int n) {
    final r = math.Random(0xF12E);
    return List.generate(n, (_) => _Spark(
      x: r.nextDouble(),
      speed: r.nextDouble() * 0.6 + 0.2,
      phase: r.nextDouble(),
      size: r.nextDouble() * 1.5 + 0.5,
      drift: (r.nextDouble() - 0.5) * 0.08,
      bright: r.nextDouble() > 0.6,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _sparks ??= _makeSparks(60);
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // 1. Глубокая тёмная база
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1E1B19));

    // 2. Свечение углей — нижняя треть, яркое и тёплое
    canvas.drawRect(rect, Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.3),
        radius: 0.9,
        colors: [
          PiligrimColors.ember.withValues(alpha: 0.55),
          PiligrimColors.emberDeep.withValues(alpha: 0.30),
          PiligrimColors.clear,
        ],
        stops: const [0.0, 0.35, 0.85],
      ).createShader(rect));

    // 3. Дополнительный жар — правее, пульсирует
    final pulse = math.sin(time * _tau * 2) * 0.5 + 0.5;
    final heatAlpha = 0.20 + pulse * 0.12;
    canvas.drawRect(rect, Paint()
      ..shader = RadialGradient(
        center: Alignment(0.3 + math.sin(time * _tau) * 0.1, 1.1),
        radius: 0.7,
        colors: [
          PiligrimColors.steppe.withValues(alpha: heatAlpha),
          PiligrimColors.clear,
        ],
      ).createShader(rect));

    // 4. Второй жар — левее
    canvas.drawRect(rect, Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.4 + math.cos(time * _tau * 0.7) * 0.08, 1.2),
        radius: 0.6,
        colors: [
          PiligrimColors.ember.withValues(alpha: 0.18 + pulse * 0.08),
          PiligrimColors.clear,
        ],
      ).createShader(rect));

    // 5. Лунный холодный блик сверху — контраст
    canvas.drawRect(rect, Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.9),
        radius: 0.7,
        colors: [
          Color(0x187BA5B8),
          Color(0x00000000),
        ],
      ).createShader(rect));

    // 6. Искры — тёплые точки, поднимаются снизу вверх
    for (final spark in _sparks!) {
      final life = (time + spark.phase) % 1.0;
      final y = 1.0 - life * (0.6 + spark.speed * 0.4);
      if (y < -0.05 || y > 1.05) continue;

      final fadeIn = (life * 5).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - life) * 3).clamp(0.0, 1.0);
      final alpha = fadeIn * fadeOut;
      if (alpha < 0.01) continue;

      final x = spark.x + math.sin((time + spark.phase) * _tau * 2) * spark.drift;
      final color = spark.bright
          ? PiligrimColors.steppe.withValues(alpha: alpha * 0.7)
          : PiligrimColors.ember.withValues(alpha: alpha * 0.5);

      canvas.drawCircle(
        Offset(x * w, y * h + parallaxOffset * 0.2),
        spark.size,
        Paint()..color = color,
      );
    }

    // 7. Виньетка — сверху тёмная, снизу прозрачная
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x601E1B19),
          Color(0x001E1B19),
        ],
        stops: [0.0, 0.4],
      ).createShader(rect));
  }

  @override
  bool shouldRepaint(_FireplacePainter old) =>
      old.time != time || old.parallaxOffset != parallaxOffset;
}

class _Spark {
  const _Spark({
    required this.x,
    required this.speed,
    required this.phase,
    required this.size,
    required this.drift,
    required this.bright,
  });
  final double x, speed, phase, size, drift;
  final bool bright;
}
