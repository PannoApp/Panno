import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

/// Брендовый shimmer-плейсхолдер — показывается пока грузится сетевое изображение.
///
/// Использует [flutter_animate] `.shimmer()` поверх [PiligrimColors.earthSurface].
/// Опциональный [borderRadius] обрезает углы (например для карточек).
class PiligrimShimmer extends StatelessWidget {
  const PiligrimShimmer({super.key, this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget box = const ColoredBox(
      color: PiligrimColors.earthSurface,
      child: SizedBox.expand(),
    );
    if (borderRadius != null) {
      box = ClipRRect(borderRadius: borderRadius!, child: box);
    }
    return box
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: PiligrimColors.nomadCream.withValues(alpha: 0.07),
          angle: 0.3,
        );
  }
}
