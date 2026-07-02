// Лёгкая editorial-метка вкладки — luxury spacing, не app bar.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

class PiligrimTabEditorialMark extends StatelessWidget {
  const PiligrimTabEditorialMark({
    super.key,
    required this.label,
    this.compact = false,
  });

  /// UPPERCASE-метка: MENU, INTERIOR, EVENTS.
  final String label;

  /// Только текст — для Menu и Afisha (минимальный след).
  final bool compact;

  static const String _glyphAsset = 'assets/images/star_totem (1).svg';

  @override
  Widget build(BuildContext context) {
    final textStyle = PiligrimTextStyles.sectionLabel.copyWith(
      fontSize: 10,
      height: 1.1,
      letterSpacing: compact ? 3.4 : 3.0,
      color: PiligrimColors.steppe.withValues(alpha: compact ? 0.29 : 0.40),
    );

    if (compact) {
      return Text(label.toUpperCase(), style: textStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          _glyphAsset,
          width: 9,
          height: 9,
          colorFilter: ColorFilter.mode(
            PiligrimColors.steppe.withValues(alpha: 0.28),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 7),
        Text(label.toUpperCase(), style: textStyle),
      ],
    );
  }
}
