// Заголовок секции PILIGRIM — SVG-иконка + UPPERCASE текст с разрядкой.
// Используется на всех экранах: профиль, меню, бронирование, события.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

class PiligrimSectionHeader extends StatelessWidget {
  const PiligrimSectionHeader({
    super.key,
    required this.label,
    required this.icon,
    this.iconSize = 12,
    this.iconColor,
    this.textColor,
    this.letterSpacing = 2.0,
    this.fontSize = 10,
  });

  /// Текст заголовка (выводится в UPPERCASE автоматически).
  final String label;

  /// Путь к SVG-иконке (assets/images/...).
  final String icon;

  final double iconSize;
  final Color? iconColor;
  final Color? textColor;
  final double letterSpacing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? PiligrimColors.steppe.withValues(alpha: 0.5);
    final tc = textColor ?? PiligrimColors.water.withValues(alpha: 0.5);

    return Row(
      children: [
        SvgPicture.asset(
          icon,
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(ic, BlendMode.srcIn),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: PiligrimTextStyles.sectionLabel.copyWith(
            color: tc,
            letterSpacing: letterSpacing,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
