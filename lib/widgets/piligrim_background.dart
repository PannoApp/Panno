// Фон PILIGRIM — реальное фото интерьера, размытое до абстракции.
// Фактура камня и свечение свечи проступают сквозь темноту.
// Никаких нарисованных эффектов — только настоящая атмосфера ресторана.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class PiligrimBackground extends StatelessWidget {
  const PiligrimBackground({
    super.key,
    this.parallaxOffset = 0.0,
    // Legacy params — kept for API compatibility, not used visually
    this.textureOpacity = 0.4,
    this.vignetteIntensity = 0.22,
    this.showInterior = true,
    this.interiorOpacity = 0.45,
    this.blurSigma = 5.0,
    /// cinematic=true (профиль, афиша, бронирование): темнее, тише.
    /// cinematic=false (главная, меню): чуть светлее, активнее.
    this.cinematic = false,
  });

  final double parallaxOffset;
  final double textureOpacity;
  final double vignetteIntensity;
  final bool showInterior;
  final double interiorOpacity;
  final double blurSigma;
  final bool cinematic;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Размытое фото интерьера ────────────────────────────────────
        ClipRect(
          child: Transform.translate(
            offset: Offset(0, parallaxOffset * 0.25),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 22,
                sigmaY: 22,
                tileMode: TileMode.mirror,
              ),
              child: Image.asset(
                'assets/images/interior_hero_2.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),

        // ── 2. Тёмный оверлей ─────────────────────────────────────────────
        // cinematic чуть темнее — экран статичный, содержание важнее фона
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: cinematic ? 0.70 : 0.62,
            ),
          ),
        ),

        // ── 3. Grain + виньетка + тёплый низ — рисуется один раз ─────────
        RepaintBoundary(
          child: CustomPaint(
            painter: _StaticOverlayPainter(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

// Статичный оверлей: grain + виньетка + тёплый намёк снизу.
// shouldRepaint = false → рисуется ровно один раз, без постоянного перерисования.
class _StaticOverlayPainter extends CustomPainter {
  static List<_GrainDot>? _grain;

  static List<_GrainDot> _makeGrain(int n) {
    final r = math.Random(0xB7C2);
    return List.generate(
      n,
      (_) => _GrainDot(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: r.nextDouble() * 0.85 + 0.25,
        alpha: r.nextDouble() * 0.018 + 0.003,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Grain — аналоговая зернистость, как у плёнки
    _grain ??= _makeGrain(600);
    final noisePaint = Paint()..style = PaintingStyle.fill;
    for (final dot in _grain!) {
      noisePaint.color = Colors.white.withValues(alpha: dot.alpha);
      canvas.drawCircle(Offset(dot.x * w, dot.y * h), dot.size, noisePaint);
    }

    // Виньетка сверху — глубина, погружение
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x881C1914), Color(0x001C1914)],
          stops: [0.0, 0.45],
        ).createShader(rect),
    );

    // Тёплый намёк снизу — отсвет свечи/углей, едва заметный
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            PiligrimColors.ember.withValues(alpha: 0.10),
            PiligrimColors.clear,
          ],
          stops: const [0.0, 0.38],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_StaticOverlayPainter _) => false;
}

class _GrainDot {
  const _GrainDot({
    required this.x,
    required this.y,
    required this.size,
    required this.alpha,
  });
  final double x, y, size, alpha;
}
