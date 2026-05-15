// Многоразовый виджет для отображения SVG тотемов бренда PILIGRIM
// Согласно piligrim_design_spec.md раздел 5: иконки монохромные, цвет акцента #7BA5B8
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

class TotemIcon extends StatelessWidget {
  const TotemIcon({
    super.key,
    required this.assetPath,
    this.size = 24,
    this.color = PiligrimColors.water,
  });

  final String assetPath;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
