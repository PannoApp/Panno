// Прозрачный слой свечений и зерна поверх интерьера.
// НЕ рисует базовый цвет — только акценты.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class TexturedBackground extends StatefulWidget {
  const TexturedBackground({super.key, this.parallaxOffset = 0.0});

  final double parallaxOffset;

  @override
  State<TexturedBackground> createState() => _TexturedBackgroundState();
}

class _TexturedBackgroundState extends State<TexturedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathCtrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_breathCtrl.value);
        return CustomPaint(
          painter: _AccentPainter(breathValue: t, dy: widget.parallaxOffset),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AccentPainter extends CustomPainter {
  _AccentPainter({required this.breathValue, required this.dy});

  final double breathValue;
  final double dy;

  static List<_Dot>? _dots;

  static List<_Dot> _makeDots(int n) {
    final r = math.Random(0xBEEF);
    return List.generate(n, (_) => _Dot(
      x: r.nextDouble(),
      y: r.nextDouble(),
      sz: r.nextDouble() * 0.5 + 0.2,
      a: r.nextDouble() * 0.025 + 0.008,
      warm: r.nextDouble() > 0.3,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _dots ??= _makeDots(700);
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Тёплое свечение — нижний правый угол, мягкое дыхание
    final ea = 0.06 + breathValue * 0.03;
    canvas.drawRect(rect, Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.5, 0.8),
        radius: 0.9,
        colors: [
          PiligrimColors.ember.withValues(alpha: ea),
          PiligrimColors.clear,
        ],
      ).createShader(rect));

    // Холодный лунный блик — верхний левый угол
    canvas.drawRect(rect, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.8),
        radius: 0.7,
        colors: [
          PiligrimColors.water.withValues(alpha: 0.05),
          PiligrimColors.clear,
        ],
      ).createShader(rect));

    // Тонкое зерно — кожа / войлок
    for (final d in _dots!) {
      final c = d.warm ? PiligrimColors.steppe : PiligrimColors.skyWarm;
      canvas.drawCircle(
        Offset(d.x * w, d.y * h + dy * 0.25),
        d.sz,
        Paint()..color = c.withValues(alpha: d.a),
      );
    }
  }

  @override
  bool shouldRepaint(_AccentPainter old) =>
      old.breathValue != breathValue || old.dy != dy;
}

class _Dot {
  const _Dot({
    required this.x, required this.y,
    required this.sz, required this.a,
    required this.warm,
  });
  final double x, y, sz, a;
  final bool warm;
}
