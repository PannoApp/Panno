// Информационная секция PILIGRIM — SVG-заголовок + текст-содержание.
// Заменяет дублированные _InfoSection (dish_elements) и _Section2 (menu_screen).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

class PiligrimInfoSection extends StatelessWidget {
  const PiligrimInfoSection({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.accent = false,
  });

  /// Заголовок секции (выводится в UPPERCASE).
  final String title;

  /// Путь к SVG-иконке.
  final String icon;

  /// Текстовое содержание секции.
  final String content;

  /// Акцентный режим — курсив и чуть ярче.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              icon,
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(
                PiligrimColors.steppe.withValues(alpha: 0.6),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: PiligrimTextStyles.sectionLabel.copyWith(
                color: PiligrimColors.water.withValues(alpha: 0.65),
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: PiligrimTextStyles.body.copyWith(
            fontSize: 14,
            color: accent
                ? PiligrimColors.sky.withValues(alpha: 0.8)
                : PiligrimColors.sky.withValues(alpha: 0.62),
            height: 1.7,
            fontStyle: accent ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}
