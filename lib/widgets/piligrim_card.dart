// Стандартная карточка PILIGRIM — полупрозрачный earth-фон, тонкая рамка.
// Вынесено из 12+ повторений по всему приложению.
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Возвращает стандартную декорацию карточки PILIGRIM.
BoxDecoration piligrimCardDecoration({
  Color? color,
  double radius = 14,
  bool hasShadow = false,
  double borderOpacity = 1.0,
}) {
  return BoxDecoration(
    color: color ?? PiligrimColors.earth.withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: PiligrimColors.divider.withValues(
        alpha: PiligrimColors.divider.a * borderOpacity,
      ),
    ),
    boxShadow: hasShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );
}
