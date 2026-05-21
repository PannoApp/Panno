// Кнопка управления атмосферным аудио экрана интерьера
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import 'piligrim_tap.dart';

/// Плавающая кнопка включения/выключения атмосферного аудио.
///
/// Stateless — всё состояние хранится в [_InteriorScreenState].
/// Позиционируется снаружи через [Positioned].
class InteriorAudioButton extends StatelessWidget {
  const InteriorAudioButton({
    super.key,
    required this.isMuted,
    required this.onToggle,
  });

  // true — аудио на паузе (пользователь выключил)
  final bool isMuted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PiligrimTap(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isMuted
              ? PiligrimColors.earthDeep.withValues(alpha: 0.85)
              : PiligrimColors.steppe.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMuted
                ? PiligrimColors.divider
                : PiligrimColors.steppe.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка казахского инструмента кобыза — символ атмосферы
            SvgPicture.asset(
              'assets/images/cobyz.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(
                isMuted
                    ? PiligrimColors.sky.withValues(alpha: 0.35)
                    : PiligrimColors.steppe,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isMuted ? 'Выкл' : 'Атмосфера',
              style: PiligrimTextStyles.caption.copyWith(
                fontSize: 11,
                color: isMuted
                    ? PiligrimColors.sky.withValues(alpha: 0.40)
                    : PiligrimColors.steppe,
                fontWeight: isMuted ? FontWeight.w300 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
