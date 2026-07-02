// PiligrimLoader — тотем-пульсация вместо CircularProgressIndicator
// Брендбук §7: «Загрузка — Анимация звезды-тотема, пульсация»
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

/// Брендовый лоадер — пульсирующая звезда-тотем с тихим свечением.
/// Заменяет CircularProgressIndicator во всех экранах.
///
/// [size] — диаметр тотема (по умолчанию 32px).
/// [color] — цвет тотема (по умолчанию water).
/// [glowColor] — цвет свечения (по умолчанию совпадает с color).
class PiligrimLoader extends StatefulWidget {
  const PiligrimLoader({
    super.key,
    this.size = 32.0,
    this.color = PiligrimColors.water,
    this.glowColor,
  });

  final double size;
  final Color color;
  final Color? glowColor;

  @override
  State<PiligrimLoader> createState() => _PiligrimLoaderState();
}

class _PiligrimLoaderState extends State<PiligrimLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? widget.color;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi);
        final opacity = (0.38 + pulse * 0.57).clamp(0.0, 1.0);
        final scale = 0.78 + pulse * 0.22;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: (pulse * 0.22).clamp(0, 0.30)),
                    blurRadius: 16 + pulse * 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: SvgPicture.asset(
        'assets/images/star_totem (1).svg',
        width: widget.size,
        height: widget.size,
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      ),
    );
  }
}
